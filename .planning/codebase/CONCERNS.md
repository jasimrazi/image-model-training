# Codebase Concerns

**Analysis Date:** 2026-05-27

## Tech Debt

**Oversized UI entrypoint:**
- Issue: `lib/main.dart` contains the app shell, scan flow, an unused training flow, shared widgets, result rendering, and upload orchestration in one 1,805-line file.
- Files: `lib/main.dart`, `lib/upload_screen.dart`, `lib/roboflow_provider.dart`
- Impact: Navigation and scan changes are risky because private widgets, duplicated training concepts, and shared styling are tightly coupled inside one file.
- Fix approach: Split scan UI into `lib/scan/`, shared widgets into `lib/widgets/`, and remove or route the legacy `TrainPage` code in `lib/main.dart` after verifying `UploadScreen` is the supported train tab.

**Duplicate training upload flows:**
- Issue: `lib/main.dart` defines `TrainPage` and sequential single-image upload logic, while the actual tab uses `UploadScreen` and `RoboflowProvider` batch upload state.
- Files: `lib/main.dart`, `lib/upload_screen.dart`, `lib/roboflow_provider.dart`, `lib/roboflow_service.dart`
- Impact: Future upload behavior can be fixed in one flow while stale UI copy and upload behavior remain in the other; `TrainPage` also tells users that `ModelUpdater` updates the app even though it is not invoked by startup.
- Fix approach: Keep one training flow. Prefer `UploadScreen` + `RoboflowProvider` because `_AppShell` instantiates `UploadScreen` at `lib/main.dart:88`; delete or migrate `TrainPage` from `lib/main.dart`.

**Unused / disconnected local inference pipeline:**
- Issue: `CloudVisionService`, `Classifier`, and `ModelUpdater` are present but not wired into `main()` or the active scan flow, which uses hosted Roboflow inference only.
- Files: `lib/main.dart`, `lib/cloud_vision_service.dart`, `lib/classifier.dart`, `lib/model_updater.dart`, `README.md`
- Impact: The app advertises local TFLite + ML Kit support, but active scanning does not initialize or dispose these services; model updater behavior can silently drift from actual runtime behavior.
- Fix approach: Either wire local inference behind a clear mode switch in `ScanPage`, or move inactive files behind a documented experimental path and remove user-facing claims from `README.md` and UI copy.

**Flutter `.env` bundled as an app asset:**
- Issue: `pubspec.yaml` includes `.env` under Flutter assets, and `lib/main.dart` loads `.env` at startup.
- Files: `pubspec.yaml`, `lib/main.dart`, `.gitignore`
- Impact: Any secret placed in `.env` can be packaged into mobile builds; `.gitignore` prevents source control leakage but does not prevent runtime asset extraction.
- Fix approach: Do not package secrets in Flutter assets. Use a backend-only secret boundary and provide non-secret public configuration through build-time defines or a checked-in example config.

**Backend implementation committed inside app repo with generated/runtime artifacts:**
- Issue: The repo contains `backend/db.sqlite3` and Python `__pycache__` files alongside source.
- Files: `backend/db.sqlite3`, `backend/__pycache__/manage.cpython-310.pyc`, `backend/training/__pycache__/views.cpython-310.pyc`, `backend/training_backend/__pycache__/settings.cpython-310.pyc`
- Impact: Runtime artifacts increase repository noise and can contain stale code or local state. SQLite files can accidentally capture development data.
- Fix approach: Add `backend/db.sqlite3`, `backend/**/__pycache__/`, and `backend/**/*.pyc` to `.gitignore`; remove committed generated/runtime artifacts.

## Known Bugs

**Upload progress reports success when backend only schedules work:**
- Symptoms: `UploadTrainingResult.ok()` says images were uploaded and training was triggered when the Django endpoint only starts a daemon thread and returns `scheduled` before Roboflow work completes.
- Files: `lib/roboflow_service.dart`, `lib/roboflow_provider.dart`, `backend/training/views.py`
- Trigger: Submit images through `UploadScreen` and receive any 2xx response from `POST /api/trigger-training/`.
- Workaround: Treat current success messages as scheduling confirmation only; inspect backend logs for actual Roboflow upload/version/training failures.

**Backend background training can be lost on process restart:**
- Symptoms: A training job can disappear after the HTTP response if the Django process exits because `_upload_generate_and_train` runs in a daemon thread without persistent job state.
- Files: `backend/training/views.py`
- Trigger: Stop/reload the Django process after `trigger_training()` returns and before Roboflow upload/training completes.
- Workaround: Keep the dev server alive and monitor logs; use a real queue or job runner before relying on this in production.

**Model updater is referenced by UX but not executed:**
- Symptoms: The train flow says the app's `ModelUpdater` detects and downloads exported TFLite models on next launch, but `main()` never calls `ModelUpdater.checkAndUpdate()` and `Classifier.loadModel()` is not used by active scan.
- Files: `lib/main.dart`, `lib/model_updater.dart`, `lib/classifier.dart`
- Trigger: Train/export a model and relaunch the app.
- Workaround: Manually replace `assets/model.tflite` and `assets/labels.txt`, or wire `ModelUpdater` into startup before exposing this instruction.

**Local classifier can crash on invalid image input:**
- Symptoms: `img.decodeImage(bytes)!` force-unwraps decoding and crashes if the file is not decodable.
- Files: `lib/classifier.dart`
- Trigger: Call `Classifier.classify()` with a corrupt or unsupported image file.
- Workaround: Only pass validated files from `image_picker`; add null handling before using this class in production UI.

## Security Considerations

**Unauthenticated CSRF-exempt training endpoint:**
- Risk: Any client that can reach the Django server can submit files and trigger Roboflow uploads/training because `trigger_training` is decorated with `@csrf_exempt` and has no authentication or shared-token check.
- Files: `backend/training/views.py`, `backend/training/urls.py`, `backend/training_backend/urls.py`
- Current mitigation: None detected in code; endpoint validates required fields only.
- Recommendations: Require server-side authentication or a signed request token, rate-limit requests, and keep Roboflow credentials exclusively on the backend.

**Client-controlled workspace and project IDs:**
- Risk: The Flutter client sends `workspace_id` and `project_id` in multipart fields, and the backend trusts them when using its Roboflow API key.
- Files: `lib/roboflow_service.dart`, `backend/training/views.py`
- Current mitigation: Empty-value validation only.
- Recommendations: Configure allowed workspace/project values on the backend and reject client-supplied values that do not match the server allowlist.

**Filename path traversal / unsafe uploaded names:**
- Risk: `backend/training/views.py` writes uploaded files with `os.path.join(class_dir, f.name)` without normalizing the basename.
- Files: `backend/training/views.py`
- Current mitigation: Files are placed under a temporary class directory, but uploaded names are not sanitized in backend code.
- Recommendations: Use a generated filename or `os.path.basename()` plus extension allowlisting; validate MIME type and size before writing chunks.

**Mobile API key exposure:**
- Risk: `RoboflowInferenceService` reads `ROBOFLOW_API_KEY` in the Flutter app and sends it as a query parameter to Roboflow; query parameters are redacted in `ApiLogger`, but a packaged `.env` asset or network instrumentation can expose the key.
- Files: `lib/roboflow_inference_service.dart`, `lib/api_logger.dart`, `pubspec.yaml`
- Current mitigation: `ApiLogger._redactUri()` masks `api_key` in debug log URLs.
- Recommendations: Proxy hosted inference through the backend or use constrained public inference credentials; never package high-privilege Roboflow keys into mobile builds.

**Development Django defaults are unsafe for deployment:**
- Risk: Django settings enable debug by environment default and fall back to a development secret when no `DJANGO_SECRET_KEY` is supplied.
- Files: `backend/training_backend/settings.py`, `backend/README.md`
- Current mitigation: `ALLOWED_HOSTS` defaults to localhost addresses.
- Recommendations: Fail startup when production secrets are absent, set debug false by deployment default, and document a production settings profile.

## Performance Bottlenecks

**Sequential hosted inference for gallery scans:**
- Problem: `_process()` awaits each `RoboflowInferenceService.scan()` one at a time.
- Files: `lib/main.dart`, `lib/roboflow_inference_service.dart`
- Cause: The loop at `lib/main.dart:231` serializes network calls, and each request has up to a 30-second timeout.
- Improvement path: Use bounded concurrency for gallery batches and display per-image progress/results as each request completes.

**Full base64 image uploads for inference:**
- Problem: Hosted inference reads the complete image into memory, base64 encodes it, and posts the whole string body.
- Files: `lib/roboflow_inference_service.dart`
- Cause: `base64Encode(await image.readAsBytes())` duplicates image data in memory and expands payload size.
- Improvement path: Resize/compress before inference, cap input dimensions, and use Roboflow's preferred binary upload format if available.

**Local TFLite preprocessing builds deeply nested Dart lists:**
- Problem: `CloudVisionService._imageToInputTensor()` and `Classifier.classify()` allocate nested lists for every pixel and run on the UI isolate if called from UI.
- Files: `lib/cloud_vision_service.dart`, `lib/classifier.dart`
- Cause: Per-pixel `List.generate` structures create allocation-heavy tensors instead of typed buffers.
- Improvement path: Convert preprocessing to typed arrays and move CPU-heavy image decode/resize/inference work off the UI isolate.

**Backend training endpoint performs file writes before returning:**
- Problem: The request handler writes every uploaded file to disk synchronously before returning `scheduled`.
- Files: `backend/training/views.py`
- Cause: File chunks are copied in the request thread before spawning the background thread.
- Improvement path: Enforce upload limits, stream directly to durable job storage, and return a job ID after queueing rather than after all local writes finish.

## Fragile Areas

**Roboflow API response parsing:**
- Files: `lib/roboflow_inference_service.dart`
- Why fragile: `_parsePrediction()` supports a small set of response shapes and returns a generic successful result with `confidence: 0` for unrecognized JSON.
- Safe modification: Add fixture-driven parser tests for Roboflow classify responses before changing the scan UI; surface unknown response shapes as failures instead of successful zero-confidence predictions.
- Test coverage: No `test/**/*.dart` files detected.

**Roboflow backend SDK workflow:**
- Files: `backend/training/views.py`, `requirements.txt`
- Why fragile: The code depends on SDK methods such as `workspace.upload_dataset()`, `project.generate_version()`, `version.export()`, and `roboflow.adapters.rfapi.start_version_training()` without tests or version-specific wrappers.
- Safe modification: Encapsulate SDK calls behind a service module and add mocked Django tests for success/failure paths before changing training configuration.
- Test coverage: No Django test files detected.

**Platform permissions and gallery storage:**
- Files: `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `lib/main.dart`, `lib/upload_screen.dart`
- Why fragile: Android declares camera/internet/storage permissions, but iOS `Info.plist` does not include camera/photo usage description keys while both scan and upload flows call `ImageSource.camera` and `pickMultiImage()`.
- Safe modification: Add platform permission keys and validate camera/gallery flows on real Android and iOS devices whenever picker behavior changes.
- Test coverage: Device permission flows are not covered by automated tests.

**Environment variable naming drift:**
- Files: `lib/roboflow_service.dart`, `lib/roboflow_inference_service.dart`, `lib/model_updater.dart`, `README.md`, `backend/README.md`
- Why fragile: Some paths accept `ROBOFLOW_PROJECT` / `ROBOFLOW_WORKSPACE`; `ModelUpdater` uses `PROJECT` / `WORKSPACE`; docs list only a subset of required variables.
- Safe modification: Centralize environment access in one Dart config class and one backend settings module; document canonical names and aliases.
- Test coverage: No config-loading tests detected.

## Scaling Limits

**Training jobs:**
- Current capacity: One request spawns one in-process daemon thread and Roboflow upload uses `num_workers=10`.
- Limit: Multiple concurrent requests can create uncontrolled threads, disk usage, and Roboflow training jobs from one Django process.
- Scaling path: Use a job queue such as Celery/RQ, persistent job records, concurrency limits, and status endpoints.

**Mobile batch uploads:**
- Current capacity: `UploadScreen` allows arbitrary image counts and `RoboflowService.uploadBatchForTraining()` sends all selected files in one multipart request with a 60-second timeout.
- Limit: Large batches can exceed memory, request size, backend disk, or timeout limits.
- Scaling path: Enforce max image count/size in UI and backend, chunk uploads, and report per-file validation failures.

**Local image rendering:**
- Current capacity: Selected/scanned images are stored as `File` references and rendered with `Image.file` in grids/lists.
- Limit: Large batches can create heavy image decoding and scrolling jank because thumbnails are not explicitly generated or cached.
- Scaling path: Generate thumbnails for grid display and cap in-memory visible items.

## Dependencies at Risk

**Roboflow Python SDK:**
- Risk: `requirements.txt` allows any `roboflow>=1.1,<2.0`, while backend code uses SDK and internal adapter APIs that may change across minor releases.
- Impact: Upload/version/training triggers can fail at runtime without compile-time checks.
- Migration plan: Pin a tested Roboflow SDK minor version, wrap SDK calls in `backend/training/`, and add mocked integration tests.

**Google ML Kit Flutter plugins:**
- Risk: `google_mlkit_image_labeling`, `google_mlkit_text_recognition`, and `google_mlkit_object_detection` are declared even though only text recognition and image labeling are used in inactive local inference code.
- Impact: App size and native model dependency surface stay larger than the active hosted-inference flow requires.
- Migration plan: Remove unused ML Kit plugins if local inference is not supported, or wire them into a maintained local scan path.

**Flutter analyzer findings:**
- Risk: `flutter analyze` reports 16 info-level issues including production `print()` usage and deprecated `withOpacity()` calls.
- Impact: New analyzer rule elevations can turn informational issues into CI/blocking warnings later.
- Migration plan: Replace `print()` with `debugPrint` guarded by `kDebugMode` or structured logging, remove unused imports, and migrate `withOpacity()` to `withValues()`.

## Missing Critical Features

**No automated test coverage:**
- Problem: No `test/**/*.dart` files and no backend test files were detected.
- Blocks: Safe refactors of Roboflow response parsing, upload state, local classifier preprocessing, and backend training orchestration.

**No job status tracking:**
- Problem: The backend returns only immediate scheduling status and does not expose job IDs, completion status, or failure details.
- Blocks: The Flutter UI cannot show whether Roboflow upload, dataset generation, export, or training actually succeeded.

**No production deployment boundary:**
- Problem: The repo has a proof-of-concept Django backend, local SQLite database, no deployment config, and no CI pipeline files detected.
- Blocks: Reliable production rollout, secret management, repeatable backend workers, and automated verification.

## Test Coverage Gaps

**Hosted inference parsing:**
- What's not tested: `_parsePrediction()`, `_latestVersion()`, non-2xx errors, malformed JSON, timeouts, and missing env-variable failures.
- Files: `lib/roboflow_inference_service.dart`
- Risk: Roboflow API response shape changes can produce misleading labels or generic successful responses.
- Priority: High

**Training upload state:**
- What's not tested: `RoboflowProvider.uploadAndTrain()`, `RoboflowService.uploadBatchForTraining()`, empty input validation, backend error body handling, and timeout behavior.
- Files: `lib/roboflow_provider.dart`, `lib/roboflow_service.dart`, `lib/upload_screen.dart`
- Risk: UI can report incorrect status or get stuck in processing state after network failures.
- Priority: High

**Backend endpoint security and cleanup:**
- What's not tested: Required-field validation, file sanitization, temporary directory cleanup, Roboflow SDK failure paths, and unauthenticated access behavior.
- Files: `backend/training/views.py`
- Risk: Unsafe uploads, orphaned temp files, and silent background failures can reach production unnoticed.
- Priority: High

**Local TFLite / ML Kit pipeline:**
- What's not tested: Asset loading, output shape/label alignment, corrupt image handling, score normalization, and resource disposal.
- Files: `lib/cloud_vision_service.dart`, `lib/classifier.dart`, `lib/model_updater.dart`
- Risk: Local inference can crash or produce incorrect labels when it is wired into UI.
- Priority: Medium

---

*Concerns audit: 2026-05-27*
