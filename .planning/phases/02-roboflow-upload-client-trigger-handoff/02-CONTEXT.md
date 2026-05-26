# Phase 2: Roboflow Upload Client & Trigger Handoff - Context

**Gathered:** 2026-05-26
**Status:** Ready for planning
**Mode:** Autonomous smart discuss

<domain>
## Phase Boundary

Wire the Phase 1 upload UI to real network behavior: selected images upload directly to Roboflow, and the Django backend trigger is called only after every upload succeeds.

</domain>

<decisions>
## Implementation Decisions

### Upload Contract

- Use the existing `http` package and a dedicated service boundary rather than embedding network calls in widgets.
- Use Roboflow's `/dataset/{dataset}/upload` endpoint with `api_key`, `name`, `split=train`, and `tag={class_name}` query parameters.
- Keep the upload API key in Flutter for this direct-upload phase because Roboflow requires authentication for direct client upload; Phase 3 keeps training/versioning secrets server-side.

### Backend Trigger Contract

- Add a configurable backend trigger URL in Flutter.
- POST JSON after successful uploads only.
- Send `workspace_id` and `project_id`; class name and image count may be included as non-required context for logging/debugging.

### Failure Behavior

- Fail fast on the first upload failure and do not call the backend trigger.
- Surface clear user-visible status text through `RoboflowProvider`.
- Keep duplicate submissions blocked with `isProcessing`.

</decisions>

<code_context>
## Existing Code Insights

- `lib/roboflow_provider.dart` owns Phase 1 selected images, class name, and processing state.
- `lib/upload_screen.dart` binds UI to provider state.
- `lib/roboflow_service.dart` already has direct Roboflow upload code, but it posts base64 form data and does not trigger a backend endpoint.
- `.env.example` currently has Roboflow variables but no backend URL.

</code_context>

<specifics>
## Specific Ideas

- Replace the Phase 1 placeholder delay in `RoboflowProvider.uploadAndTrain()` with a service call.
- Return a typed result from the service so UI can show success/failure messages without parsing exceptions.
- Add `BACKEND_TRIGGER_URL` to `.env.example`.

</specifics>

<deferred>
## Deferred Ideas

- Training status polling remains deferred.
- Server-side version generation and YOLOv8 training are Phase 3/4.

</deferred>
