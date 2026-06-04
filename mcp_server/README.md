# Vision MCP Server

Python MCP server exposing this app's core image workflows as MCP tools.

## Tools

- `scan_image` - classify one image through the Render/Django inference endpoint.
- `upload_training_images` - upload labeled images and trigger the backend training flow.
- `backend_health` - show the backend URLs the MCP server will call.

## Setup

```bash
cd mcp_server
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

## Environment

Set these in your shell or in `mcp_server/.env`:

```text
BACKEND_BASE_URL=https://image-model-training.onrender.com
ROBOFLOW_WORKSPACE=your-workspace
ROBOFLOW_PROJECT=your-project
```

Remote HTTP deployments also require Auth0 bearer-token auth:

```text
PUBLIC_MCP_URL=https://your-render-service.onrender.com/mcp
AUTH0_ISSUER_URL=https://your-tenant.us.auth0.com/
AUTH0_AUDIENCE=your-auth0-api-identifier
AUTH0_CLIENT_ID=your-auth0-application-client-id
AUTH0_JWKS_URL=https://your-tenant.us.auth0.com/.well-known/jwks.json
AUTH0_REQUIRED_SCOPES=mcp:use
```

`AUTH0_JWKS_URL` is optional if `AUTH0_ISSUER_URL` is set. The server derives it from the issuer URL.
`AUTH0_CLIENT_ID` is included for deployment documentation and client setup; token validation uses the Auth0 audience and issuer.
For OpenCode/Auth0 OAuth, the Auth0 API identifier must match `PUBLIC_MCP_URL` because OpenCode sends the MCP resource URL as the OAuth `resource` value.

Optional direct endpoint overrides:

```text
BACKEND_INFERENCE_URL=https://image-model-training.onrender.com/api/infer/
BACKEND_TRIGGER_URL=https://image-model-training.onrender.com/api/trigger-training/
```

## MCP Client Config

Example stdio configuration:

```json
{
  "mcpServers": {
    "vision": {
      "command": "python",
      "args": ["C:/Users/Elara/Desktop/vision/mcp_server/server.py"],
      "env": {
        "BACKEND_BASE_URL": "https://image-model-training.onrender.com",
        "ROBOFLOW_WORKSPACE": "your-workspace",
        "ROBOFLOW_PROJECT": "your-project"
      }
    }
  }
}
```

## Render Hosting

Deploy `mcp_server/render.yaml` as a Render Blueprint, or create a Python web service with:

```text
Root Directory: mcp_server
Build Command: pip install -r requirements.txt
Start Command: python server.py
```

Set these Render environment variables:

```text
MCP_TRANSPORT=streamable-http
BACKEND_BASE_URL=https://image-model-training.onrender.com
PUBLIC_MCP_URL=https://your-render-service.onrender.com/mcp
AUTH0_ISSUER_URL=https://your-tenant.us.auth0.com/
AUTH0_AUDIENCE=https://your-render-service.onrender.com/mcp
AUTH0_CLIENT_ID=your-auth0-application-client-id
AUTH0_JWKS_URL=https://your-tenant.us.auth0.com/.well-known/jwks.json
AUTH0_REQUIRED_SCOPES=mcp:use
ROBOFLOW_WORKSPACE=your-workspace
ROBOFLOW_PROJECT=your-project
```

After deploy, use the remote MCP URL:

```text
https://your-render-service.onrender.com/mcp
```

Remote MCP clients must send an Auth0 access token for the configured API audience:

```http
Authorization: Bearer <auth0-access-token>
```

The token must include the `mcp:use` scope when `AUTH0_REQUIRED_SCOPES=mcp:use` is configured.

## Auth0 Application

In the Auth0 application used by OpenCode, add this callback URL:

```text
http://127.0.0.1:19876/mcp/oauth/callback
```

If Auth0 prompts for them, also add:

```text
Allowed Logout URLs: http://127.0.0.1:19876
Allowed Web Origins: http://127.0.0.1:19876
```

When OpenCode adds the remote MCP server at `https://your-render-service.onrender.com/mcp`, it should discover the protected-resource metadata, open Auth0/Google login on first use, then call the MCP endpoint with a bearer token.
