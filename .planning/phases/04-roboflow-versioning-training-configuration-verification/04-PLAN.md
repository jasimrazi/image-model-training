# Phase 4 Plan: Roboflow Versioning, Training & Configuration Verification

## Goal

Scheduled backend work generates a Roboflow dataset version, starts YOLOv8 training, and leaves configuration reproducible without committed secrets.

## Requirements

- PIPE-02
- PIPE-03
- PIPE-04
- CONF-03

## Tasks

1. Implement background SDK worker using `Roboflow(api_key=...)`.
2. Access workspace/project from `workspace_id` and `project_id`.
3. Generate a new version with auto-orient and resize to 640x640 preprocessing.
4. Start YOLOv8 training with `epochs=50`.
5. Add backend requirements and README setup instructions.
6. Update `.env.example` with Flutter and backend placeholders.

## Verification

- Python files compile.
- `requirements.txt` contains Django, Roboflow, and python-dotenv.
- Config docs contain placeholders only and no committed secret values.
