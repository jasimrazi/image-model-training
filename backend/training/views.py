import json
import logging
import os
import shutil
import tempfile
import threading
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt

logger = logging.getLogger(__name__)

@csrf_exempt
def trigger_training(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST required"}, status=405)

    try:
        # 1. Extract metadata and files from the Flutter multipart request
        workspace_id = request.POST.get("workspace_id", "").strip()
        project_id = request.POST.get("project_id", "").strip()
        class_name = request.POST.get("class_name", "").strip()
        files = request.FILES.getlist("images")

        if not workspace_id or not project_id or not class_name or not files:
            return JsonResponse(
                {"error": "workspace_id, project_id, class_name, and images are required"},
                status=400,
            )

        api_key = os.environ.get("ROBOFLOW_API_KEY", "").strip()
        if not api_key:
            return JsonResponse({"error": "Server is missing ROBOFLOW_API_KEY"}, status=500)

        # 2. Create a temporary directory structure: /tmp/random_id/class_name/
        # The Roboflow SDK will read 'class_name' as the label for these images.
        temp_dir = tempfile.mkdtemp()
        class_dir = os.path.join(temp_dir, class_name)
        os.makedirs(class_dir)

        # 3. Save the uploaded files from memory to disk
        for f in files:
            file_path = os.path.join(class_dir, f.name)
            with open(file_path, "wb+") as destination:
                for chunk in f.chunks():
                    destination.write(chunk)

        # 4. Spin up the background thread to handle the SDK operations
        thread = threading.Thread(
            target=_upload_generate_and_train,
            kwargs={
                "api_key": api_key,
                "workspace_id": workspace_id,
                "project_id": project_id,
                "temp_dir": temp_dir, 
            },
            daemon=True,
        )
        thread.start()

        # 5. Return immediately so the Flutter app isn't waiting
        return JsonResponse(
            {
                "status": "scheduled",
                "message": f"Processing {len(files)} images for class '{class_name}'.",
                "workspace_id": workspace_id,
                "project_id": project_id,
            },
            status=200,
        )

    except Exception as e:
        logger.exception("Failed to process request")
        return JsonResponse({"error": str(e)}, status=500)


def _upload_generate_and_train(api_key, workspace_id, project_id, temp_dir):
    try:
        from roboflow import Roboflow

        logger.info(f"Loading Roboflow workspace {workspace_id}")
        roboflow = Roboflow(api_key=api_key)
        workspace = roboflow.workspace(workspace_id)
        
        logger.info(f"Loading Roboflow project {project_id}")
        project = workspace.project(project_id)

        # 1. Upload the directory (SDK handles the auto-labeling based on folder name)
        logger.info(f"Uploading folder structure from {temp_dir}")
        
        # --- THE FIX: Use workspace.upload_dataset instead of project.upload ---
        workspace.upload_dataset(
            dataset_path=temp_dir,
            project_name=project_id,
            num_workers=10,
            project_license="MIT",
            project_type="classification", 
            batch_name="flutter-mobile-upload" # Optional: groups them nicely in the UI
        )

        # 2. Clean up the temporary files on the Django server
        shutil.rmtree(temp_dir)

        # 3. Generate the new version
        settings = {
            "preprocessing": {
                "auto-orient": True,
                "resize": {"width": 640, "height": 640, "format": "Stretch to"},
            },
            "augmentation": {},
        }

        logger.info(f"Generating Roboflow dataset version for {workspace_id}/{project_id}")
        version_number = project.generate_version(settings=settings)
        logger.info(f"Generated Roboflow dataset version {version_number}")

        # 4. Determine configuration and start training
        version = project.version(version_number)
        model_type, export_format = _training_config_for_version(version)
        
        logger.info(f"Starting {model_type} training for version {version_number}")
        version.export(export_format)
        
        _start_training_without_polling(
            api_key=api_key,
            workspace_id=workspace_id,
            project_id=project_id,
            version_number=version_number,
            model_type=model_type,
            epochs=50,
        )
        logger.info(f"Roboflow training successfully started.")

    except ImportError:
        logger.exception("Roboflow SDK is not installed.")
    except Exception:
        logger.exception(f"Roboflow training pipeline failed for {workspace_id}/{project_id}")
        # Ensure cleanup happens even if the upload fails
        if os.path.exists(temp_dir):
            shutil.rmtree(temp_dir)


def _training_config_for_version(version):
    version_type = getattr(version, "type", "")
    if version_type == "classification":
        return "vit-base-patch16-224-in21k", "folder"
    return "yolov8", "yolov5pytorch"


def _start_training_without_polling(api_key, workspace_id, project_id, version_number, model_type, epochs):
    from roboflow.adapters import rfapi

    rfapi.start_version_training(
        api_key=api_key,
        workspace_url=workspace_id,
        project_url=project_id,
        version=str(version_number),
        model_type=model_type,
        epochs=epochs,
    )