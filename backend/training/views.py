import base64
import json
import logging
import os
import shutil
import tempfile
import threading
from urllib.parse import urlparse

import requests
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt

logger = logging.getLogger(__name__)

MAX_IMAGE_URL_BYTES = 10 * 1024 * 1024


class ImageUrlError(ValueError):
    pass


def _authorized(request):
    expected_token = os.environ.get("MCP_CLIENT_TOKEN", "").strip()
    if not expected_token:
        return True
    provided_token = request.headers.get("X-MCP-Client-Token", "").strip()
    return provided_token == expected_token


def _request_data(request):
    if request.content_type and request.content_type.startswith("application/json"):
        try:
            payload = json.loads(request.body.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            return None
        if isinstance(payload, dict):
            return payload
        return None
    return request.POST


def _download_image_url(image_url):
    parsed = urlparse(image_url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ImageUrlError("image_url must be an absolute http(s) URL")

    response = requests.get(image_url, stream=True, timeout=20)
    response.raise_for_status()

    content = bytearray()
    for chunk in response.iter_content(chunk_size=8192):
        if not chunk:
            continue
        content.extend(chunk)
        if len(content) > MAX_IMAGE_URL_BYTES:
            raise ImageUrlError("image_url response is too large")
    return bytes(content)


@csrf_exempt
def infer_image(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST required"}, status=405)
    if not _authorized(request):
        return JsonResponse({"error": "Unauthorized"}, status=401)

    try:
        data = _request_data(request)
        if data is None:
            return JsonResponse({"error": "Invalid JSON request body"}, status=400)

        image = request.FILES.get("image")
        image_url = str(data.get("image_url", "")).strip()
        if image is None and not image_url:
            return JsonResponse({"error": "image or image_url is required"}, status=400)

        image_bytes = image.read() if image is not None else _download_image_url(image_url)

        api_key = os.environ.get("ROBOFLOW_API_KEY", "").strip()
        project_id = (
            str(data.get("project_id", "")).strip()
            or os.environ.get("ROBOFLOW_PROJECT", "").strip()
            or os.environ.get("PROJECT", "").strip()
        )
        workspace_id = (
            str(data.get("workspace_id", "")).strip()
            or os.environ.get("ROBOFLOW_WORKSPACE", "").strip()
            or os.environ.get("WORKSPACE", "").strip()
        )
        version = (
            str(data.get("version", "")).strip()
            or os.environ.get("ROBOFLOW_INFER_VERSION", "").strip()
            or "latest"
        )

        if not api_key:
            return JsonResponse({"error": "Server is missing ROBOFLOW_API_KEY"}, status=500)
        if not project_id:
            return JsonResponse({"error": "ROBOFLOW_PROJECT is required"}, status=400)
        if version.lower() == "latest":
            if not workspace_id:
                return JsonResponse(
                    {"error": "ROBOFLOW_WORKSPACE is required when ROBOFLOW_INFER_VERSION is latest"},
                    status=400,
                )
            version = _latest_trained_version(api_key, workspace_id, project_id)

        response = requests.post(
            f"https://classify.roboflow.com/{project_id}/{version}",
            params={"api_key": api_key},
            data=base64.b64encode(image_bytes).decode("utf-8"),
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=30,
        )

        try:
            payload = response.json()
        except ValueError:
            payload = {"raw": response.text}

        return JsonResponse(payload, status=response.status_code, safe=False)
    except ImageUrlError as e:
        return JsonResponse({"error": str(e)}, status=400)
    except requests.RequestException as e:
        logger.exception("Roboflow inference request failed")
        return JsonResponse({"error": str(e)}, status=502)
    except Exception as e:
        logger.exception("Failed to process inference request")
        return JsonResponse({"error": str(e)}, status=500)


def _latest_trained_version(api_key, workspace_id, project_id):
    response = requests.get(
        f"https://api.roboflow.com/{workspace_id}/{project_id}",
        params={"api_key": api_key},
        timeout=20,
    )
    response.raise_for_status()
    payload = response.json()

    versions = payload.get("versions") or payload.get("project", {}).get("versions") or []
    trained_versions = []
    fallback_versions = []
    for item in versions:
        version_number = _version_number(item)
        if version_number is None:
            continue
        fallback_versions.append(version_number)
        if isinstance(item, dict) and item.get("model"):
            trained_versions.append(version_number)

    candidates = trained_versions or fallback_versions
    if not candidates:
        raise ValueError("Roboflow project response did not include versions")
    return str(max(candidates))


def _version_number(value):
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        try:
            return int(value.rsplit("/", 1)[-1])
        except ValueError:
            return None
    if isinstance(value, dict):
        for key in ("version", "id", "name", "number"):
            number = _version_number(value.get(key))
            if number is not None:
                return number
    return None

@csrf_exempt
def trigger_training(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST required"}, status=405)
    if not _authorized(request):
        return JsonResponse({"error": "Unauthorized"}, status=401)

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
