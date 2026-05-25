# Requirements: Vision

**Defined:** 2026-05-25
**Core Value:** Users can improve recognition quality by contributing labeled images and triggering a reliable training pipeline without exposing service secrets in the mobile app.

## v0.1 Requirements

Requirements for the Roboflow automated training pipeline milestone. Each maps to roadmap phases.

### Flutter Upload

- [ ] **FLUT-01**: User can open a dedicated upload screen for training images.
- [ ] **FLUT-02**: User can select multiple images from the device using `image_picker`.
- [ ] **FLUT-03**: User can enter a class name/tag that is applied to uploaded images.
- [ ] **FLUT-04**: User can start an upload-and-train flow from one button.
- [ ] **FLUT-05**: User sees a loading indicator and disabled actions while upload/training trigger work is processing.

### Roboflow Upload

- [ ] **ROBO-01**: App iterates through `List<File>` and uploads each image as multipart form data to Roboflow.
- [ ] **ROBO-02**: Each Roboflow upload includes `dataset`, `api_key`, `name`, `split=train`, and `tag={class_name}` parameters.
- [ ] **ROBO-03**: App reports upload failure clearly and does not trigger backend training when any image upload fails.

### Backend Trigger

- [ ] **BACK-01**: Flutter sends a POST request to `/api/trigger-training/` after successful image uploads.
- [ ] **BACK-02**: Django exposes a CSRF-exempt API view that accepts JSON containing `workspace_id` and `project_id`.
- [ ] **BACK-03**: Django returns a `200 OK` JSON response immediately after scheduling background training work.
- [ ] **BACK-04**: Django reports malformed JSON or missing required fields with a clear non-2xx JSON response.

### Training Pipeline

- [ ] **PIPE-01**: Backend reads the Roboflow API key from server environment configuration only.
- [ ] **PIPE-02**: Backend uses the `roboflow` Python SDK to access the requested workspace and project.
- [ ] **PIPE-03**: Backend generates a new dataset version with auto-orient preprocessing and resize to 640x640.
- [ ] **PIPE-04**: Backend starts YOLOv8 training with `epochs=50` on the generated version.
- [ ] **PIPE-05**: Backend runs Roboflow versioning and training calls in a background thread.

### Dependencies And Configuration

- [ ] **CONF-01**: Flutter dependencies include Provider for `ChangeNotifier` state management.
- [ ] **CONF-02**: Backend dependencies include Django, Roboflow SDK, and environment variable loading.
- [ ] **CONF-03**: Required Flutter and Django environment variables are documented without committing secret values.

## Future Requirements

Deferred to future releases. Tracked but not in current roadmap.

### Training Operations

- **OPS-01**: User can poll and view Roboflow training job status from the mobile app.
- **OPS-02**: User can download or activate the trained model after training completes.
- **OPS-03**: Backend persists training jobs and errors across server restarts.
- **OPS-04**: Backend uses a durable queue such as Celery instead of raw threads.

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| User authentication | No auth system exists and it is not needed for the requested upload/trigger code. |
| Per-image annotation UI | This milestone uses Roboflow upload tags/classes, not bounding-box annotation in Flutter. |
| Training progress UI | Requested response returns immediately; polling/status can be added later. |
| Automatic model replacement | Existing model updater is separate; this milestone stops after training trigger. |
| Production queue infrastructure | Requested implementation explicitly uses Python threading. |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FLUT-01 | Phase 1 | Pending |
| FLUT-02 | Phase 1 | Pending |
| FLUT-03 | Phase 1 | Pending |
| FLUT-04 | Phase 1 | Pending |
| FLUT-05 | Phase 1 | Pending |
| ROBO-01 | Phase 2 | Pending |
| ROBO-02 | Phase 2 | Pending |
| ROBO-03 | Phase 2 | Pending |
| BACK-01 | Phase 2 | Pending |
| BACK-02 | Phase 3 | Pending |
| BACK-03 | Phase 3 | Pending |
| BACK-04 | Phase 3 | Pending |
| PIPE-01 | Phase 3 | Pending |
| PIPE-02 | Phase 4 | Pending |
| PIPE-03 | Phase 4 | Pending |
| PIPE-04 | Phase 4 | Pending |
| PIPE-05 | Phase 3 | Pending |
| CONF-01 | Phase 1 | Pending |
| CONF-02 | Phase 3 | Pending |
| CONF-03 | Phase 4 | Pending |

**Coverage:**
- v0.1 requirements: 20 total
- Mapped to phases: 20
- Unmapped: 0

---
*Requirements defined: 2026-05-25*
*Last updated: 2026-05-25 after roadmap creation*
