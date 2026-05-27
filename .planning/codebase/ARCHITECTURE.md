<!-- refreshed: 2026-05-27 -->
# Architecture

**Analysis Date:** 2026-05-27

## System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Mobile App                        │
│                    `lib/main.dart`                           │
├──────────────────┬──────────────────┬───────────────────────┤
│   Scan Tab       │   Upload Tab     │   Local Vision        │
│ `ScanPage`       │ `UploadScreen`   │ `CloudVisionService`  │
│ `lib/main.dart`  │ `lib/upload_screen.dart` │ `lib/cloud_vision_service.dart` │
└────────┬─────────┴────────┬─────────┴──────────┬────────────┘
         │                  │                     │
         ▼                  ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│                 App Services and State                       │
│ `lib/roboflow_inference_service.dart`                        │
│ `lib/roboflow_provider.dart`                                 │
│ `lib/roboflow_service.dart`                                  │
│ `lib/model_updater.dart`                                     │
│ `lib/api_logger.dart`                                        │
└────────┬──────────────────────────────┬──────────────────────┘
         │                              │
         ▼                              ▼
┌─────────────────────────────┐  ┌─────────────────────────────┐
│ Roboflow Hosted APIs         │  │ Django Training Backend      │
│ `classify.roboflow.com`      │  │ `backend/training/views.py`  │
│ `api.roboflow.com`           │  │ `backend/training_backend/`  │
└─────────────────────────────┘  └──────────────┬──────────────┘
                                                ▼
┌─────────────────────────────────────────────────────────────┐
│  Roboflow SDK + Local Storage                                │
│  `backend/db.sqlite3`, temp upload directories, Roboflow      │
└─────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| App bootstrap | Initializes Flutter bindings, configures system UI, loads `.env`, and installs `RoboflowProvider` above the app shell. | `lib/main.dart` |
| App shell | Owns two-tab navigation between scanning and training upload with `IndexedStack`. | `lib/main.dart` |
| Scan flow | Picks camera/gallery images, calls hosted Roboflow inference, renders image cards, and submits low-confidence/unknown items for training. | `lib/main.dart` |
| Upload flow | Collects a batch of gallery images and a class name, then delegates upload/training trigger state to `RoboflowProvider`. | `lib/upload_screen.dart` |
| Upload state | Stores selected files, class name, processing flag, status message, and invokes the upload service. | `lib/roboflow_provider.dart` |
| Hosted inference client | Resolves Roboflow project/version, posts base64 image payloads, parses prediction responses, and returns `HostedInferenceResult`. | `lib/roboflow_inference_service.dart` |
| Training upload client | Posts multipart images and metadata to the configured backend trigger endpoint. | `lib/roboflow_service.dart` |
| API logging | Redacts `api_key` query parameters and prints request/response details in debug builds. | `lib/api_logger.dart` |
| Local vision pipeline | Loads bundled TFLite assets and ML Kit recognizers, preprocesses images, and returns labels/text in `VisionResult`. | `lib/cloud_vision_service.dart` |
| Lightweight classifier | Loads bundled or downloaded TFLite model and returns top label/confidence maps. | `lib/classifier.dart` |
| Model update client | Checks version metadata, downloads custom TFLite model files, and persists model version in shared preferences. | `lib/model_updater.dart` |
| Django settings | Loads `backend/.env`, configures minimal Django apps, SQLite, middleware, and URL root. | `backend/training_backend/settings.py` |
| Backend API routing | Mounts the training app under `/api/` and exposes `/api/trigger-training/`. | `backend/training_backend/urls.py`, `backend/training/urls.py` |
| Training trigger endpoint | Accepts multipart upload metadata/files, writes temporary class-folder dataset structure, and schedules a background Roboflow SDK job. | `backend/training/views.py` |

## Pattern Overview

**Overall:** Flutter feature-first UI with static service clients, Provider-managed upload state, and a minimal Django trigger backend.

**Key Characteristics:**
- Keep Flutter screen orchestration in widgets (`lib/main.dart`, `lib/upload_screen.dart`) and network/platform work in service classes (`lib/roboflow_service.dart`, `lib/roboflow_inference_service.dart`).
- Use `ChangeNotifierProvider` for mutable upload-batch state; use local `StatefulWidget` state for scan results and tab selection.
- Use static service APIs for side effects; callers receive small result models such as `HostedInferenceResult` and `UploadTrainingResult`.
- Keep backend routing thin: project-level URL include in `backend/training_backend/urls.py`, app-level route in `backend/training/urls.py`, endpoint logic in `backend/training/views.py`.
- Treat `.env` files as configuration-only inputs; never hard-code secret values in code or documents.

## Layers

**Flutter Presentation Layer:**
- Purpose: Render the app shell, tab navigation, forms, scan cards, upload grids, and status messages.
- Location: `lib/main.dart`, `lib/upload_screen.dart`
- Contains: `MyApp`, `_AppShell`, `ScanPage`, private UI widgets, `UploadScreen`, and upload screen private widgets.
- Depends on: `image_picker`, `provider`, `RoboflowInferenceService`, `RoboflowService`, `RoboflowProvider`.
- Used by: Flutter engine entry point in `lib/main.dart`.

**Flutter State Layer:**
- Purpose: Centralize mutable training-upload state that is shared across upload form widgets.
- Location: `lib/roboflow_provider.dart`
- Contains: `RoboflowProvider` with selected image list, normalized class name, processing flag, status message, and upload action.
- Depends on: `ChangeNotifier` from Flutter foundation and `RoboflowService` in `lib/roboflow_service.dart`.
- Used by: `ChangeNotifierProvider` in `lib/main.dart` and `Consumer<RoboflowProvider>` in `lib/upload_screen.dart`.

**Flutter Service Layer:**
- Purpose: Encapsulate HTTP, ML model loading, image preprocessing, logging, and persistent model update operations.
- Location: `lib/roboflow_inference_service.dart`, `lib/roboflow_service.dart`, `lib/cloud_vision_service.dart`, `lib/classifier.dart`, `lib/model_updater.dart`, `lib/api_logger.dart`
- Contains: Static Roboflow API clients, TFLite/ML Kit services, API redaction logging, model download logic.
- Depends on: `http`, `flutter_dotenv`, `tflite_flutter`, `google_mlkit_*`, `image`, `shared_preferences`, `path_provider`.
- Used by: UI widgets and provider classes in `lib/main.dart`, `lib/upload_screen.dart`, and `lib/roboflow_provider.dart`.

**Backend HTTP Layer:**
- Purpose: Expose a single Django endpoint that accepts app uploads and starts training work asynchronously.
- Location: `backend/training_backend/urls.py`, `backend/training/urls.py`, `backend/training/views.py`
- Contains: URL routing and `trigger_training` view.
- Depends on: Django request/response APIs, environment variables from `backend/training_backend/settings.py`.
- Used by: `RoboflowService.uploadBatchForTraining()` in `lib/roboflow_service.dart` through `BACKEND_TRIGGER_URL`.

**Backend Training Worker Layer:**
- Purpose: Perform Roboflow SDK upload, dataset version generation, export, and training start outside the request thread.
- Location: `backend/training/views.py`
- Contains: `_upload_generate_and_train()`, `_training_config_for_version()`, `_start_training_without_polling()`.
- Depends on: Roboflow SDK, temporary filesystem storage, Python `threading`, `shutil`, `tempfile`.
- Used by: `trigger_training()` in `backend/training/views.py`.

**Platform and Asset Layer:**
- Purpose: Configure Flutter platform runners, Android permissions, ML Kit preloading, and bundled model assets.
- Location: `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`, `ios/Runner/Info.plist`, `pubspec.yaml`, `assets/model.tflite`, `assets/labels.txt`
- Contains: Platform permissions, Android `noCompress` for TFLite, Flutter asset declarations, launcher/platform boilerplate.
- Depends on: Flutter build system and platform-specific Gradle/Xcode projects.
- Used by: Flutter runtime and service classes that load assets.

## Data Flow

### Primary Request Path

1. App startup loads Flutter bindings, system UI, and `.env` before rendering `MyApp` (`lib/main.dart:18`).
2. `MyApp` creates a `RoboflowProvider` and renders `_AppShell` with scan/upload tabs (`lib/main.dart:55`).
3. `ScanPage` picks camera or gallery images through `ImagePicker` (`lib/main.dart:206`, `lib/main.dart:215`).
4. `_process()` converts each picked `XFile` to `File` and calls `RoboflowInferenceService.scan()` (`lib/main.dart:223`, `lib/main.dart:233`).
5. `RoboflowInferenceService.scan()` reads Roboflow env var names, resolves version, posts image bytes to hosted inference, and parses the response (`lib/roboflow_inference_service.dart:35`, `lib/roboflow_inference_service.dart:48`, `lib/roboflow_inference_service.dart:80`).
6. `ScanPage` stores `ScanItem` results in local widget state and renders `_ScanCard` with label, confidence, and raw response (`lib/main.dart:237`, `lib/main.dart:324`).

### Training Upload Flow

1. `UploadScreen` gathers multiple gallery images through `ImagePicker.pickMultiImage()` (`lib/upload_screen.dart:34`).
2. `UploadScreen` sends files and class-name edits to `RoboflowProvider` (`lib/upload_screen.dart:37`, `lib/upload_screen.dart:78`).
3. `_uploadAndTrain()` calls `provider.uploadAndTrain()` (`lib/upload_screen.dart:42`).
4. `RoboflowProvider.uploadAndTrain()` guards `canSubmit`, sets processing state, and calls `RoboflowService.uploadBatchForTraining()` (`lib/roboflow_provider.dart:38`, `lib/roboflow_provider.dart:42`).
5. `RoboflowService.uploadBatchForTraining()` builds a multipart request with `workspace_id`, `project_id`, `class_name`, and `images` fields, then posts to `BACKEND_TRIGGER_URL` (`lib/roboflow_service.dart:53`, `lib/roboflow_service.dart:105`).
6. Django `trigger_training()` validates metadata/files and writes each uploaded file under a temporary class-name folder (`backend/training/views.py:13`, `backend/training/views.py:24`, `backend/training/views.py:36`).
7. Django starts a daemon thread and immediately returns a scheduled response (`backend/training/views.py:48`, `backend/training/views.py:61`).
8. `_upload_generate_and_train()` uploads the dataset folder to Roboflow, generates a version, exports the format, and starts training without polling (`backend/training/views.py:76`, `backend/training/views.py:91`, `backend/training/views.py:113`, `backend/training/views.py:123`).

### Local Inference Flow

1. `CloudVisionService.initialize()` verifies and loads `assets/model.tflite` and `assets/labels.txt`, initializes ML Kit image labeler, and marks the service initialized (`lib/cloud_vision_service.dart:54`).
2. `CloudVisionService.scanFile()` decodes and resizes the image to 224x224, converts pixels to the model input tensor shape/type, and runs the TFLite interpreter (`lib/cloud_vision_service.dart:84`, `lib/cloud_vision_service.dart:104`, `lib/cloud_vision_service.dart:112`, `lib/cloud_vision_service.dart:130`).
3. The same scan extracts text with ML Kit and returns `VisionResult` containing labels, text, and raw metadata (`lib/cloud_vision_service.dart:182`, `lib/cloud_vision_service.dart:188`).
4. `Classifier.loadModel()` can load a downloaded file path or the bundled model, then `Classifier.classify()` returns a compact map with label/confidence and all scores (`lib/classifier.dart:12`, `lib/classifier.dart:23`).

**State Management:**
- Use local `State` for tab index, scan results, loading flags, dialogs, and legacy training wizard state in `lib/main.dart`.
- Use `RoboflowProvider` for the active upload screen state in `lib/roboflow_provider.dart`; expose immutable image lists with `List.unmodifiable()`.
- Use `SharedPreferences` only for downloaded model version bookkeeping in `lib/model_updater.dart`.
- Use temporary backend directories only inside `backend/training/views.py`; clean them after upload or on failure.

## Key Abstractions

**Result Models:**
- Purpose: Keep service outcomes explicit and easy for widgets/providers to render.
- Examples: `HostedInferenceResult` in `lib/roboflow_inference_service.dart`, `UploadTrainingResult` in `lib/roboflow_service.dart`, `VisionResult` and `VisionLabel` in `lib/cloud_vision_service.dart`, `ScanItem` in `lib/main.dart`.
- Pattern: Immutable classes with `final` fields and factory constructors for failures/success where useful.

**Static Service Clients:**
- Purpose: Provide side-effect operations without constructing service objects in widgets.
- Examples: `RoboflowInferenceService.scan()` in `lib/roboflow_inference_service.dart`, `RoboflowService.uploadBatchForTraining()` in `lib/roboflow_service.dart`, `ModelUpdater.checkAndUpdate()` in `lib/model_updater.dart`, `ApiLogger.request()` in `lib/api_logger.dart`.
- Pattern: Static methods read configuration from `flutter_dotenv` or environment variables, execute I/O, and return result models instead of throwing for expected failures.

**State Notifier:**
- Purpose: Coordinate upload form controls, selected images, button enablement, processing state, and status message.
- Examples: `RoboflowProvider` in `lib/roboflow_provider.dart`.
- Pattern: Private mutable fields, public getters, mutation methods that call `notifyListeners()`.

**Django Endpoint Function:**
- Purpose: Keep the backend API small and directly mapped to one URL.
- Examples: `trigger_training()` in `backend/training/views.py`.
- Pattern: Function-based view with `@csrf_exempt`, request method validation, request parsing, JSON responses, and helper functions for background work.

## Entry Points

**Flutter app:**
- Location: `lib/main.dart`
- Triggers: Flutter runtime invokes `main()`.
- Responsibilities: Initialize bindings, load `.env`, create providers, and render `MaterialApp`.

**Android host:**
- Location: `android/app/src/main/kotlin/com/example/vision/MainActivity.kt`
- Triggers: Android launcher activity declared in `android/app/src/main/AndroidManifest.xml`.
- Responsibilities: Host Flutter activity and expose camera/internet/storage permissions plus ML Kit dependency metadata.

**iOS host:**
- Location: `ios/Runner/AppDelegate.swift`, `ios/Runner/Info.plist`
- Triggers: iOS app launch through Runner target.
- Responsibilities: Register Flutter plugins and configure platform bundle metadata.

**Django management:**
- Location: `backend/manage.py`
- Triggers: `python backend/manage.py runserver` or other Django management commands.
- Responsibilities: Set `DJANGO_SETTINGS_MODULE` to `training_backend.settings` and execute Django command-line handling.

**Django URL root:**
- Location: `backend/training_backend/urls.py`
- Triggers: Incoming HTTP requests to the Django WSGI app.
- Responsibilities: Mount `training.urls` at `/api/`.

**Training endpoint:**
- Location: `backend/training/views.py`
- Triggers: `POST /api/trigger-training/`.
- Responsibilities: Validate metadata/files, save uploads to a class-folder dataset, schedule Roboflow upload/version/training work, and return JSON status.

## Architectural Constraints

- **Threading:** Flutter UI uses the Dart event loop with async I/O; the backend uses Python daemon threads in `backend/training/views.py` for long-running Roboflow operations after the HTTP response.
- **Global state:** `dotenv.env` is global configuration used by `lib/main.dart`, `lib/roboflow_service.dart`, `lib/roboflow_inference_service.dart`, and `lib/model_updater.dart`; `ApiLogger` is a static utility in `lib/api_logger.dart`.
- **Model resources:** `CloudVisionService` owns and must dispose the TFLite interpreter, `TextRecognizer`, and `ImageLabeler` in `lib/cloud_vision_service.dart`; `Classifier` owns its interpreter in `lib/classifier.dart`.
- **Asset paths:** `assets/model.tflite` and `assets/labels.txt` are declared in `pubspec.yaml` and loaded by `lib/cloud_vision_service.dart` and `lib/classifier.dart`; keep these paths stable unless all loaders change together.
- **Android packaging:** `android/app/build.gradle.kts` uses `androidResources.noCompress += "tflite"`; preserve this so TFLite assets remain loadable.
- **Backend secrets:** `backend/training_backend/settings.py` reads `backend/.env`; generated docs and logs must mention env var names only, never values.
- **Circular imports:** Not detected in the source read; Flutter service files import utilities/providers one directionally, and Django URL modules import views only.

## Anti-Patterns

### Duplicating Training UI State

**What happens:** `TrainPage` and its private step widgets remain in `lib/main.dart`, while the active app shell uses `UploadScreen` from `lib/upload_screen.dart` for the train tab.
**Why it's wrong:** Two implementations of training upload behavior can diverge and make future changes harder to place safely.
**Do this instead:** Add new training-upload UI to `lib/upload_screen.dart` and shared state to `lib/roboflow_provider.dart`; avoid extending `TrainPage` in `lib/main.dart` unless the app shell starts using it.

### Putting New Services Inside Widgets

**What happens:** `lib/main.dart` already contains UI plus scan orchestration and legacy training widgets, making the file large.
**Why it's wrong:** Additional HTTP/model logic inside `lib/main.dart` couples rendering to I/O and makes tests/refactors harder.
**Do this instead:** Put new Roboflow/backend calls in `lib/roboflow_service.dart` or `lib/roboflow_inference_service.dart`, new model work in `lib/cloud_vision_service.dart` or `lib/classifier.dart`, and call those services from widgets.

### Blocking Request Work in Django Views

**What happens:** Roboflow upload/version/training is intentionally moved to `_upload_generate_and_train()` and scheduled with `threading.Thread` in `backend/training/views.py`.
**Why it's wrong:** Running SDK upload/training inline in `trigger_training()` would keep the Flutter client waiting for long-running operations and increase timeout risk.
**Do this instead:** Keep `trigger_training()` as a scheduler and put long-running work in helpers or a proper background worker module under `backend/training/`.

## Error Handling

**Strategy:** Return user-renderable result objects in Flutter services for expected failures, return JSON errors in Django views, and log diagnostics only in debug/server logs.

**Patterns:**
- Validate required app configuration and return `HostedInferenceResult.failed()` for missing Roboflow project/API key values in `lib/roboflow_inference_service.dart`.
- Validate upload inputs and return `UploadTrainingResult.failed()` with a message in `lib/roboflow_service.dart`.
- Use HTTP status checks and API logger calls around `http` calls in `lib/roboflow_inference_service.dart`, `lib/roboflow_service.dart`, and `lib/model_updater.dart`.
- Return `JsonResponse` with 400/405/500 status codes from `backend/training/views.py` for invalid request method, missing fields, missing backend API key, or exceptions.
- Use `logger.exception()` in `backend/training/views.py` for server-side failures and cleanup temporary directories on background exceptions.

## Cross-Cutting Concerns

**Logging:** Use `ApiLogger` in `lib/api_logger.dart` for outbound Flutter API calls; it redacts `api_key` query parameters. Use Python `logging` in `backend/training/views.py` for backend workflow logs.
**Validation:** Validate required env var names and request fields in service/endpoint boundaries: `lib/roboflow_inference_service.dart`, `lib/roboflow_service.dart`, and `backend/training/views.py`.
**Authentication:** The Flutter app uses Roboflow API key env vars for hosted inference and model downloads; the backend uses `ROBOFLOW_API_KEY` from `backend/.env`; no app-user identity/auth flow is implemented in the files read.

---

*Architecture analysis: 2026-05-27*
