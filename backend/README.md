# Vision Training Backend

Minimal Django backend for triggering Roboflow dataset version generation and YOLOv8 training.

## Setup

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python backend/manage.py runserver
```

## Environment

Create a backend `.env` file or set environment variables before starting Django:

```text
DJANGO_SECRET_KEY=replace-me
DJANGO_DEBUG=true
ROBOFLOW_API_KEY=replace-me
```

Do not commit real API keys.

## Endpoint

`POST /api/trigger-training/`

```json
{
  "workspace_id": "your-workspace",
  "project_id": "your-project"
}
```

The endpoint returns immediately after scheduling a background thread. The thread generates a Roboflow dataset version with auto-orient and 640x640 resize preprocessing, then starts YOLOv8 training for 50 epochs.
