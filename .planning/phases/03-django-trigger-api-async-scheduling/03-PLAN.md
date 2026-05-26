# Phase 3 Plan: Django Trigger API & Async Scheduling

## Goal

Backend accepts training trigger requests, validates them, keeps secrets server-side, and returns immediately after scheduling work.

## Requirements

- BACK-02
- BACK-03
- BACK-04
- PIPE-01
- PIPE-05
- CONF-02

## Tasks

1. Add minimal Django project and training app under `backend/`.
2. Add a CSRF-exempt view at `/api/trigger-training/`.
3. Parse JSON and validate `workspace_id` and `project_id`.
4. Read `ROBOFLOW_API_KEY` from backend environment.
5. Schedule work in a daemon background thread and return `200 OK` immediately.
6. Return clear JSON errors for malformed JSON, wrong methods, missing fields, and missing backend API key.

## Verification

- Static Python compile succeeds.
- Django URL routing exposes `/api/trigger-training/`.
- View code does not require the Flutter payload to include the Roboflow API key.
