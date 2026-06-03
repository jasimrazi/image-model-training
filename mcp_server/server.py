import base64
import os
from pathlib import Path
from typing import Any

import requests
from dotenv import load_dotenv
from mcp.server.fastmcp import FastMCP


load_dotenv()

mcp = FastMCP("vision")


def _env(name: str, default: str = "") -> str:
    return os.environ.get(name, default).strip()


def _backend_inference_url() -> str:
    explicit_url = _env("BACKEND_INFERENCE_URL")
    if explicit_url:
        return explicit_url

    trigger_url = _env("BACKEND_TRIGGER_URL")
    if trigger_url:
        return trigger_url.rstrip("/").removesuffix("trigger-training") + "infer/"

    base_url = _env("BACKEND_BASE_URL", "https://image-model-training.onrender.com")
    return f"{base_url.rstrip('/')}/api/infer/"


def _backend_training_url() -> str:
    explicit_url = _env("BACKEND_TRIGGER_URL")
    if explicit_url:
        return explicit_url


    base_url = _env("BACKEND_BASE_URL", "https://image-model-training.onrender.com")
    return f"{base_url.rstrip('/')}/api/trigger-training/"


def _read_image(image_path: str | None, image_base64: str | None) -> bytes:
    if image_base64:
        return base64.b64decode(image_base64)
    if image_path:
        return Path(image_path).read_bytes()
    raise ValueError("Provide either image_path or image_base64.")


def _response_payload(response: requests.Response) -> dict[str, Any]:
    try:
        body: Any = response.json()
    except ValueError:
        body = response.text

    return {
        "ok": 200 <= response.status_code < 300,
        "status_code": response.status_code,
        "body": body,
    }


def _auth_headers() -> dict[str, str]:
    token = _env("MCP_CLIENT_TOKEN")
    if not token:
        raise ValueError("Set MCP_CLIENT_TOKEN before using private backend tools.")
    return {"X-MCP-Client-Token": token}


@mcp.tool()
def scan_image(
    image_path: str | None = None,
    image_base64: str | None = None,
) -> dict[str, Any]:
    """Classify an image through the Vision Render backend."""
    image_bytes = _read_image(image_path, image_base64)
    filename = Path(image_path).name if image_path else "image.jpg"

    response = requests.post(
        _backend_inference_url(),
        headers=_auth_headers(),
        files={"image": (filename, image_bytes)},
        timeout=45,
    )
    return _response_payload(response)


@mcp.tool()
def upload_training_images(
    class_name: str,
    image_paths: list[str] | None = None,
    images_base64: list[str] | None = None,
    workspace_id: str | None = None,
    project_id: str | None = None,
) -> dict[str, Any]:
    """Upload labeled training images and trigger the backend training pipeline."""
    workspace = (workspace_id or _env("ROBOFLOW_WORKSPACE") or _env("WORKSPACE")).strip()
    project = (project_id or _env("ROBOFLOW_PROJECT") or _env("PROJECT")).strip()
    if not workspace:
        raise ValueError("workspace_id is required, or set ROBOFLOW_WORKSPACE.")
    if not project:
        raise ValueError("project_id is required, or set ROBOFLOW_PROJECT.")

    files: list[tuple[str, tuple[str, bytes]]] = []
    for path in image_paths or []:
        files.append(("images", (Path(path).name, Path(path).read_bytes())))
    for index, encoded in enumerate(images_base64 or []):
        files.append(("images", (f"image-{index + 1}.jpg", base64.b64decode(encoded))))
    if not files:
        raise ValueError("Provide image_paths or images_base64.")

    response = requests.post(
        _backend_training_url(),
        headers=_auth_headers(),
        data={
            "workspace_id": workspace,
            "project_id": project,
            "class_name": class_name,
        },
        files=files,
        timeout=90,
    )
    return _response_payload(response)


@mcp.tool()
def backend_health() -> dict[str, Any]:
    """Report the configured backend URLs used by this MCP server."""
    return {
        "backend_inference_url": _backend_inference_url(),
        "backend_training_url": _backend_training_url(),
    }


if __name__ == "__main__":
    mcp.run()
