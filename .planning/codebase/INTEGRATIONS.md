# External Integrations

**Analysis Date:** 2026-05-27

## APIs & External Services

**Roboflow Inference:**
- Roboflow Hosted Inference - Classifies camera/gallery images from the Flutter scan flow.
  - SDK/Client: Dart `http` 1.6.0 in `lib/roboflow_inference_service.dart`.
  - Endpoint: `https://classify.roboflow.com/{project}/{version}` constructed with `Uri.https('classify.roboflow.com', '/$project/$version', ...)` in `lib/roboflow_inference_service.dart`.
  - Auth: `ROBOFLOW_API_KEY` query parameter, redacted by `lib/api_logger.dart`.
  - Config: `ROBOFLOW_PROJECT` or `PROJECT`, plus optional `ROBOFLOW_INFER_VERSION`.

**Roboflow Project Metadata:**
- Roboflow API - Looks up the latest trained project version when Flutter inference version is `latest`.
  - SDK/Client: Dart `http` 1.6.0 in `lib/roboflow_inference_service.dart`.
  - Endpoint: `https://api.roboflow.com/{workspace}/{project}` constructed in `lib/roboflow_inference_service.dart`.
  - Auth: `ROBOFLOW_API_KEY` query parameter, redacted by `lib/api_logger.dart`.
  - Config: `ROBOFLOW_WORKSPACE` or `WORKSPACE`, and `ROBOFLOW_PROJECT` or `PROJECT`.

**Roboflow Model Download:**
- Roboflow API - Downloads TensorFlow Lite export for local/custom model updates.
  - SDK/Client: Dart `http` 1.6.0 in `lib/model_updater.dart`.
  - Endpoint: `https://api.roboflow.com/{workspace}/{project}/{version}/tflite` constructed in `lib/model_updater.dart`.
  - Auth: `ROBOFLOW_API_KEY` query parameter, redacted by `lib/api_logger.dart`.
  - Config: `WORKSPACE`, `PROJECT`, `MODEL_VERSION`, `MODEL_VERSION_URL`, and optional `MODEL_DOWNLOAD_URL`.

**Training Trigger Backend:**
- Django backend trigger - Flutter uploads training images and metadata to a backend endpoint.
  - SDK/Client: Dart `http.MultipartRequest` in `lib/roboflow_service.dart`.
  - Endpoint: `BACKEND_TRIGGER_URL` from Flutter `.env`.
  - Auth: No app-side auth detected in `lib/roboflow_service.dart`.
  - Payload: multipart fields `workspace_id`, `project_id`, `class_name`, and repeated `images` files in `lib/roboflow_service.dart`.

**Roboflow Training Backend:**
- Roboflow Python SDK - Backend uploads datasets, generates versions, exports model artifacts, and starts training.
  - SDK/Client: Python `roboflow` package from `requirements.txt`, imported in `backend/training/views.py`.
  - Auth: `ROBOFLOW_API_KEY` environment variable read in `backend/training/views.py`.
  - Operations: `workspace.upload_dataset(...)`, `project.generate_version(...)`, `version.export(...)`, and `rfapi.start_version_training(...)` in `backend/training/views.py`.

**Google ML Kit On-Device Models:**
- Google ML Kit Text Recognition / Image Labeling / Object Detection - On-device ML features bundled through Flutter plugins and Android model dependency preload.
  - SDK/Client: `google_mlkit_text_recognition`, `google_mlkit_image_labeling`, and `google_mlkit_object_detection` from `pubspec.yaml`.
  - Implementation: OCR and image labeling in `lib/cloud_vision_service.dart`.
  - Auth: None detected; these are on-device SDK integrations.
  - Android preload: `com.google.mlkit.vision.DEPENDENCIES=ocr,label,object_detection` in `android/app/src/main/AndroidManifest.xml`.

## Data Storage

**Databases:**
- SQLite for Django backend.
  - Connection: configured in `backend/training_backend/settings.py` as `django.db.backends.sqlite3` at `backend/db.sqlite3`.
  - Client: Django ORM, although no app models were detected in `backend/training/`.

**File Storage:**
- Flutter bundled assets: `assets/model.tflite` and `assets/labels.txt` declared in `pubspec.yaml` and loaded in `lib/cloud_vision_service.dart` and `lib/classifier.dart`.
- Flutter app documents directory: `custom_model.tflite` downloaded and stored through `path_provider` in `lib/model_updater.dart`.
- Flutter platform image paths: image files selected through `image_picker` are passed as `File` instances in `lib/main.dart` and `lib/upload_screen.dart`.
- Backend temporary filesystem: uploaded training images are saved under a temporary class-name folder in `backend/training/views.py` and deleted with `shutil.rmtree(...)`.

**Caching:**
- Shared preferences cache the downloaded model version under `saved_model_version` in `lib/model_updater.dart`.
- No Redis, Memcached, CDN, or server-side cache integration detected.

## Authentication & Identity

**Auth Provider:**
- Roboflow API key authentication.
  - Implementation: Flutter reads `ROBOFLOW_API_KEY` from `.env` via `flutter_dotenv` in `lib/roboflow_inference_service.dart` and `lib/model_updater.dart`; backend reads `ROBOFLOW_API_KEY` from environment in `backend/training/views.py`.
  - Transport: query parameter `api_key` for Flutter Roboflow API calls; Python SDK constructor `Roboflow(api_key=...)` for backend training in `backend/training/views.py`.
- Django app authentication: Not detected.
  - Implementation: `trigger_training` is decorated with `@csrf_exempt` in `backend/training/views.py`, and no token/session checks were detected.
- User identity/accounts: Not detected in Flutter `lib/` or Django `backend/`.

## Monitoring & Observability

**Error Tracking:**
- None detected. No Sentry, Crashlytics, Rollbar, OpenTelemetry, or analytics package is declared in `pubspec.yaml` or `requirements.txt`.

**Logs:**
- Flutter API logging uses `ApiLogger` in `lib/api_logger.dart`; it logs only in `kDebugMode` and redacts `api_key` query parameters.
- Flutter model/inference paths use `print(...)` and `debugPrint(...)` in `lib/cloud_vision_service.dart`, `lib/model_updater.dart`, `lib/roboflow_service.dart`, and `lib/api_logger.dart`.
- Backend logging uses Python `logging.getLogger(__name__)` and `logger.info(...)` / `logger.exception(...)` in `backend/training/views.py`.

## CI/CD & Deployment

**Hosting:**
- Flutter hosting target is not specified; generated platform folders exist for `android/`, `ios/`, `web/`, `macos/`, `windows/`, and `linux/`.
- Backend hosting target is not specified; Django WSGI entrypoint exists at `backend/training_backend/wsgi.py`.

**CI Pipeline:**
- None detected. No `.github/workflows/*` files were found.

## Environment Configuration

**Required env vars:**
- Flutter app:
  - `ROBOFLOW_API_KEY` - required for hosted inference in `lib/roboflow_inference_service.dart` and Roboflow model downloads in `lib/model_updater.dart`.
  - `ROBOFLOW_PROJECT` or `PROJECT` - required for hosted inference in `lib/roboflow_inference_service.dart`.
  - `ROBOFLOW_WORKSPACE` or `WORKSPACE` - required when `ROBOFLOW_INFER_VERSION` is `latest` in `lib/roboflow_inference_service.dart`.
  - `ROBOFLOW_INFER_VERSION` - optional; defaults to `latest` in `lib/roboflow_inference_service.dart`.
  - `BACKEND_TRIGGER_URL` - required for training uploads in `lib/roboflow_service.dart`.
  - `MODEL_VERSION`, `MODEL_VERSION_URL`, and `MODEL_DOWNLOAD_URL` - optional model-update configuration in `lib/model_updater.dart`.
- Django backend:
  - `DJANGO_SECRET_KEY` - Django secret setting in `backend/training_backend/settings.py`.
  - `DJANGO_DEBUG` - controls debug mode in `backend/training_backend/settings.py`.
  - `DJANGO_ALLOWED_HOSTS` - controls allowed hosts in `backend/training_backend/settings.py`.
  - `ROBOFLOW_API_KEY` - required by `backend/training/views.py` to use the Roboflow SDK.

**Secrets location:**
- Repository root `.env` file present and bundled by `pubspec.yaml`; contents were not read.
- `backend/.env` file present and loaded by `backend/training_backend/settings.py`; contents were not read.
- `backend/README.md` documents placeholder env var names only and instructs not to commit real API keys.

## Webhooks & Callbacks

**Incoming:**
- `POST /api/trigger-training/` - Django endpoint routed by `backend/training_backend/urls.py` and `backend/training/urls.py`, implemented by `trigger_training` in `backend/training/views.py`.
- Flutter calls the incoming backend URL through `BACKEND_TRIGGER_URL` in `lib/roboflow_service.dart`.
- No third-party webhook receiver endpoints detected.

**Outgoing:**
- Flutter outgoing POST to Roboflow Hosted Inference from `lib/roboflow_inference_service.dart`.
- Flutter outgoing GET to Roboflow project metadata from `lib/roboflow_inference_service.dart`.
- Flutter outgoing GET to model version/download URLs from `lib/model_updater.dart`.
- Flutter outgoing multipart POST to backend trigger URL from `lib/roboflow_service.dart`.
- Backend outgoing Roboflow SDK calls for dataset upload, version generation, export, and training start from `backend/training/views.py`.
- No webhook callback registration or asynchronous callback consumer was detected.

---

*Integration audit: 2026-05-27*
