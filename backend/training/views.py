import json
import logging
import os
import threading

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt


logger = logging.getLogger(__name__)


@csrf_exempt
def trigger_training(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST required"}, status=405)

    try:
        payload = json.loads(request.body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return JsonResponse({"error": "Invalid JSON payload"}, status=400)

    workspace_id = str(payload.get("workspace_id", "")).strip()
    project_id = str(payload.get("project_id", "")).strip()

    if not workspace_id or not project_id:
        return JsonResponse(
            {"error": "workspace_id and project_id are required"},
            status=400,
        )

    api_key = os.environ.get("ROBOFLOW_API_KEY", "").strip()
    if not api_key:
        return JsonResponse(
            {"error": "Server is missing ROBOFLOW_API_KEY"},
            status=500,
        )

    thread = threading.Thread(
        target=_generate_version_and_train,
        kwargs={
            "api_key": api_key,
            "workspace_id": workspace_id,
            "project_id": project_id,
        },
        daemon=True,
    )
    thread.start()

    return JsonResponse(
        {
            "status": "scheduled",
            "workspace_id": workspace_id,
            "project_id": project_id,
        },
        status=200,
    )


def _generate_version_and_train(api_key, workspace_id, project_id):
    try:
        from roboflow import Roboflow

        roboflow = Roboflow(api_key=api_key)
        workspace = roboflow.workspace(workspace_id)
        project = workspace.project(project_id)

        version = project.generate_version(
            preprocessing={
                "auto-orient": True,
                "resize": {"width": 640, "height": 640, "format": "Stretch to"},
            }
        )
        version.train(model_type="yolov8", epochs=50)
        logger.info("Roboflow training started for %s/%s", workspace_id, project_id)
    except Exception:
        logger.exception(
            "Roboflow training pipeline failed for %s/%s",
            workspace_id,
            project_id,
        )
