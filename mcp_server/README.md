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
MCP_CLIENT_TOKEN=generate-a-long-random-secret
ROBOFLOW_WORKSPACE=your-workspace
ROBOFLOW_PROJECT=your-project
```

Set the same `MCP_CLIENT_TOKEN` value in the Render backend environment. Requests without this token are rejected by the backend.

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
        "MCP_CLIENT_TOKEN": "generate-a-long-random-secret",
        "ROBOFLOW_WORKSPACE": "your-workspace",
        "ROBOFLOW_PROJECT": "your-project"
      }
    }
  }
}
```
