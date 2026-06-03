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
ROBOFLOW_WORKSPACE=your-workspace
ROBOFLOW_PROJECT=your-project
```

After deploy, use the remote MCP URL:

```text
https://your-render-service.onrender.com/mcp
```
