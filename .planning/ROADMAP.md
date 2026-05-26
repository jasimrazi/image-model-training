# Roadmap: v0.1 Roboflow Automated Training Pipeline

**Milestone:** v0.1  
**Goal:** Users can select multiple images in Flutter, upload them to a Roboflow class, and trigger a Django backend to generate a new dataset version and start YOLOv8 training asynchronously.  
**Granularity:** Standard  
**Requirements coverage:** 20/20 v0.1 requirements mapped

## Phases

- [x] **Phase 1: Flutter Upload UI & Processing State** - Users can open a dedicated training upload flow, select images, enter a class/tag, and see safe processing state.
- [x] **Phase 2: Roboflow Upload Client & Trigger Handoff** - Selected images upload directly to Roboflow and backend training is triggered only after all uploads succeed.
- [x] **Phase 3: Django Trigger API & Async Scheduling** - Backend accepts training trigger requests, validates them, keeps secrets server-side, and returns immediately after scheduling work.
- [x] **Phase 4: Roboflow Versioning, Training & Configuration Verification** - Backend generates a Roboflow dataset version, starts YOLOv8 training, and documents required runtime configuration.

## Phase Details

### Phase 1: Flutter Upload UI & Processing State
**Goal**: Users can prepare a labeled training-image batch in Flutter and understand when upload/training trigger work is processing.  
**Depends on**: Nothing  
**Requirements**: FLUT-01, FLUT-02, FLUT-03, FLUT-04, FLUT-05, CONF-01  
**Success Criteria** (what must be TRUE):
  1. User can open a dedicated training upload screen from the app.
  2. User can select multiple training images from the device and see that selections are ready for submission.
  3. User can enter a class name/tag that will be used for the selected image batch.
  4. User can start the upload-and-train flow from one clear action.
  5. While processing is active, the UI shows loading state and prevents duplicate actions through Provider-backed `ChangeNotifier` state.
**Plans**: TBD  
**UI hint**: yes

### Phase 2: Roboflow Upload Client & Trigger Handoff
**Goal**: The app reliably uploads all selected images to Roboflow and only requests backend training after successful uploads.  
**Depends on**: Phase 1  
**Requirements**: ROBO-01, ROBO-02, ROBO-03, BACK-01  
**Success Criteria** (what must be TRUE):
  1. For a selected `List<File>`, the app uploads each image as multipart form data to the configured Roboflow dataset upload endpoint.
  2. Each upload includes the required dataset, API key, generated image name, `split=train`, and `tag={class_name}` parameters.
  3. If any image upload fails, the user receives a clear failure message and backend training is not triggered.
  4. After every image uploads successfully, Flutter sends a POST request to `/api/trigger-training/`.
**Plans**: TBD  
**UI hint**: yes

### Phase 3: Django Trigger API & Async Scheduling
**Goal**: Backend can safely accept training trigger requests, validate inputs, schedule background work, and acknowledge immediately without exposing the Roboflow API key to Flutter.  
**Depends on**: Phase 2  
**Requirements**: BACK-02, BACK-03, BACK-04, PIPE-01, PIPE-05, CONF-02  
**Success Criteria** (what must be TRUE):
  1. Flutter or an API client can POST JSON with `workspace_id` and `project_id` to a CSRF-exempt `/api/trigger-training/` endpoint.
  2. Valid trigger requests receive an immediate `200 OK` JSON response after background work is scheduled.
  3. Malformed JSON or missing required fields receive clear non-2xx JSON responses.
  4. Roboflow API key access happens only from server environment configuration, never from the Flutter trigger payload.
  5. Versioning and training work is launched in a Python background thread using installed backend dependencies.
**Plans**: TBD

### Phase 4: Roboflow Versioning, Training & Configuration Verification
**Goal**: Scheduled backend work generates a trainable Roboflow dataset version, starts YOLOv8 training with the requested settings, and leaves configuration reproducible without committed secrets.  
**Depends on**: Phase 3  
**Requirements**: PIPE-02, PIPE-03, PIPE-04, CONF-03  
**Success Criteria** (what must be TRUE):
  1. Backend background work uses the Roboflow Python SDK to access the requested workspace and project.
  2. Backend generates a new dataset version with auto-orient preprocessing and resize to 640x640.
  3. Backend starts YOLOv8 training on the generated version with `epochs=50`.
  4. Required Flutter and Django environment variables are documented with placeholders/examples and no committed secret values.
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Flutter Upload UI & Processing State | 1/1 | Complete | 2026-05-25 |
| 2. Roboflow Upload Client & Trigger Handoff | 1/1 | Complete | 2026-05-26 |
| 3. Django Trigger API & Async Scheduling | 1/1 | Complete | 2026-05-26 |
| 4. Roboflow Versioning, Training & Configuration Verification | 1/1 | Complete | 2026-05-26 |

## Coverage Map

| Requirement | Phase |
|-------------|-------|
| FLUT-01 | Phase 1 |
| FLUT-02 | Phase 1 |
| FLUT-03 | Phase 1 |
| FLUT-04 | Phase 1 |
| FLUT-05 | Phase 1 |
| CONF-01 | Phase 1 |
| ROBO-01 | Phase 2 |
| ROBO-02 | Phase 2 |
| ROBO-03 | Phase 2 |
| BACK-01 | Phase 2 |
| BACK-02 | Phase 3 |
| BACK-03 | Phase 3 |
| BACK-04 | Phase 3 |
| PIPE-01 | Phase 3 |
| PIPE-05 | Phase 3 |
| CONF-02 | Phase 3 |
| PIPE-02 | Phase 4 |
| PIPE-03 | Phase 4 |
| PIPE-04 | Phase 4 |
| CONF-03 | Phase 4 |

**Coverage:** 20/20 v0.1 requirements mapped; no orphaned requirements; no duplicate mappings.

---
*Created: 2026-05-25 for milestone v0.1*
