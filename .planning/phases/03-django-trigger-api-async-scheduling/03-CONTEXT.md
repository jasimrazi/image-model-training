# Phase 3: Django Trigger API & Async Scheduling - Context

**Gathered:** 2026-05-26
**Status:** Ready for planning
**Mode:** Autonomous smart discuss

<domain>
## Phase Boundary

Create an in-repo Django backend under `backend/` with a CSRF-exempt `/api/trigger-training/` endpoint. The endpoint validates JSON, starts background work, and returns immediately.

</domain>

<decisions>
## Implementation Decisions

- Backend lives in `backend/` in this repository.
- Use plain Django views and URL routing, not Django REST Framework, to keep dependencies minimal.
- Use Python `threading.Thread(..., daemon=True)` as requested.
- Keep Roboflow API key access in backend environment variables only.

</decisions>

<code_context>
## Existing Code Insights

- No Python/Django files exist yet.
- Flutter Phase 2 posts `workspace_id` and `project_id` to the configured backend trigger URL.

</code_context>

<specifics>
## Specific Ideas

- Add `backend/manage.py`, `backend/training_backend/settings.py`, `backend/training_backend/urls.py`, `backend/training/views.py`, and `backend/training/urls.py`.
- Add root `requirements.txt` for backend dependencies.

</specifics>

<deferred>
## Deferred Ideas

- Persistent jobs and status polling remain future work.

</deferred>
