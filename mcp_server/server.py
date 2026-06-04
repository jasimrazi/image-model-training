import base64
import os
from pathlib import Path
from typing import Any

import jwt
import requests
from dotenv import load_dotenv
from jwt import PyJWKClient
from jwt.exceptions import PyJWTError
from mcp.server.auth.provider import AccessToken
from mcp.server.auth.settings import AuthSettings
from mcp.server.fastmcp import FastMCP


load_dotenv()


def _env(name: str, default: str = "") -> str:
    return os.environ.get(name, default).strip()


def _env_int(name: str, default: int) -> int:
    value = _env(name)
    return int(value) if value else default


def _env_list(name: str) -> list[str]:
    value = _env(name)
    if not value:
        return []
    return [item.strip() for item in value.replace(",", " ").split() if item.strip()]


def _mcp_transport() -> str:
    return _env("MCP_TRANSPORT", "stdio")


def _public_mcp_url() -> str:
    explicit_url = _env("PUBLIC_MCP_URL")
    if explicit_url:
        return explicit_url

    render_url = _env("RENDER_EXTERNAL_URL")
    if render_url:
        return f"{render_url.rstrip('/')}/mcp"

    return ""


class Auth0TokenVerifier:
    def __init__(self, issuer_url: str, audience: str, jwks_url: str, required_scopes: list[str]) -> None:
        self.issuer_url = issuer_url
        self.audience = audience
        self.required_scopes = required_scopes
        self.jwks_client = PyJWKClient(jwks_url)

    async def verify_token(self, token: str) -> AccessToken | None:
        try:
            signing_key = self.jwks_client.get_signing_key_from_jwt(token)
            claims = jwt.decode(
                token,
                signing_key.key,
                algorithms=["RS256"],
                audience=self.audience,
                issuer=self.issuer_url,
            )
        except PyJWTError:
            print(f"JWT decode failed: {e}")
            return None

        scopes = _token_scopes(claims)
        print(f"Token scopes: {scopes}, Required: {self.required_scopes}")
        if any(scope not in scopes for scope in self.required_scopes):
            return None

        return AccessToken(
            token=token,
            client_id=str(claims.get("azp") or claims.get("client_id") or claims.get("sub") or "auth0"),
            scopes=scopes,
            expires_at=claims.get("exp"),
            resource=self.audience,
            subject=claims.get("sub"),
            claims=claims,
        )


def _token_scopes(claims: dict[str, Any]) -> list[str]:
    scope = claims.get("scope")
    if isinstance(scope, str):
        return [item for item in scope.split() if item]
    permissions = claims.get("permissions")
    if isinstance(permissions, list):
        return [str(item) for item in permissions]
    return []


def _auth_settings() -> tuple[AuthSettings | None, Auth0TokenVerifier | None]:
    if _mcp_transport() == "stdio":
        return None, None

    issuer_url = _env("AUTH0_ISSUER_URL")
    audience = _env("AUTH0_AUDIENCE")
    jwks_url = _env("AUTH0_JWKS_URL") or (f"{issuer_url.rstrip('/')}/.well-known/jwks.json" if issuer_url else "")
    public_url = _public_mcp_url()
    if not issuer_url or not audience or not jwks_url or not public_url:
        raise RuntimeError(
            "Set AUTH0_ISSUER_URL, AUTH0_AUDIENCE, and PUBLIC_MCP_URL before running remote MCP auth."
        )

    required_scopes = _env_list("AUTH0_REQUIRED_SCOPES")
    auth_settings = AuthSettings(
        issuer_url=issuer_url,
        resource_server_url=public_url,
        required_scopes=required_scopes,
    )
    return auth_settings, Auth0TokenVerifier(issuer_url, audience, jwks_url, required_scopes)


auth_settings, token_verifier = _auth_settings()


mcp = FastMCP(
    "vision",
    host=_env("FASTMCP_HOST", "0.0.0.0"),
    port=_env_int("PORT", _env_int("FASTMCP_PORT", 8000)),
    auth=auth_settings,
    token_verifier=token_verifier,
)


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
    mcp.run(transport=_mcp_transport())
