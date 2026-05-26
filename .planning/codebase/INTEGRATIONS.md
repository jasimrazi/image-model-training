# External Integrations

**Analysis Date:** 2026-05-25

## APIs & External Services

**Roboflow training and model export:**
- Roboflow API - Uploads user-provided training images, starts training jobs, polls training status, requests TFLite exports, and constructs model-download URLs.
  - SDK/Client: `http` package used directly in `lib/roboflow_service.dart` and `lib/model_updater.dart`.
  - Auth: `ROBOFLOW_API_KEY` from `.env` via `flutter_dotenv` in `lib/roboflow_service.dart` and `lib/model_updater.dart`.
  - Workspace/project config: `ROBOFLOW_WORKSPACE`, `WORKSPACE`, `ROBOFLOW_PROJECT`, and `PROJECT` in `lib/roboflow_service.dart` and `lib/model_updater.dart`.
  - Upload endpoint: `https://api.roboflow.com/dataset/{project}/upload` in `lib/roboflow_service.dart`.
  - Training job endpoint: `https://api.roboflow.com/{workspace}/{project}/jobs` in `lib/roboflow_service.dart`.
  - Training status endpoint: `https://api.roboflow.com/{workspace}/{project}/jobs/{jobId}` in `lib/roboflow_service.dart`.
  - Export endpoint: `https://api.roboflow.com/{workspace}/{project}/{version}/export` with `format=tflite` in `lib/roboflow_service.dart`.
  - Direct TFLite URL builder: `https://api.roboflow.com/{workspace}/{project}/{version}/tflite` in `lib/model_updater.dart`.

**Google ML Kit on-device vision:**
- Google ML Kit Text Recognition - Optional OCR implementation through `TextRecognizer` in `lib/cloud_vision_service.dart`.
  - SDK/Client: `google_mlkit_text_recognition` package.
  - Auth: Not required; on-device model integration.
- Google ML Kit Image Labeling - Optional on-device labeler through `ImageLabeler` in `lib/cloud_vision_service.dart`.
  - SDK/Client: `google_mlkit_image_labeling` package.
  - Auth: Not required; on-device model integration.
- Google ML Kit Android dependency preloading - Android manifest metadata `com.google.mlkit.vision.DEPENDENCIES=ocr,label,object_detection` in `android/app/src/main/AndroidManifest.xml`.

**Generic model update endpoints:**
- Custom model version endpoint - `MODEL_VERSION_URL` is fetched with `http.get(Uri.parse(...))` and expected to return an integer version in `lib/model_updater.dart`.
  - SDK/Client: `http` package.
  - Auth: Not detected by code; endpoint URL comes from `.env`.
- Direct model download endpoint - `MODEL_DOWNLOAD_URL` is fetched with `http.get(Uri.parse(...))` in `lib/model_updater.dart`.
  - SDK/Client: `http` package.
  - Auth: Not detected by code; endpoint URL comes from `.env`.

## Data Storage

**Databases:**
- Not detected - No database package, ORM, database schema, or database connection config is present in `pubspec.yaml`, `lib/`, or platform config files.

**File Storage:**
- Local app documents directory - `path_provider` returns `getApplicationDocumentsDirectory()` for downloaded TFLite files in `lib/model_updater.dart`.
- Bundled Flutter assets - `assets/model.tflite`, `assets/labels.txt`, and `.env` are declared under `flutter.assets` in `pubspec.yaml`.
- User-selected image files - `image_picker` returns local `XFile` paths that are converted to `File` objects in `lib/main.dart`.

**Caching:**
- `shared_preferences` - Stores `saved_model_version` and `model_version` keys in `lib/model_updater.dart`.
- Local model cache - Downloaded model files `custom_model.tflite` and `model.tflite` are written to the app documents directory in `lib/model_updater.dart`.

## Authentication & Identity

**Auth Provider:**
- No user authentication provider detected - No Firebase Auth, OAuth, Supabase, or custom session management appears in `pubspec.yaml` or `lib/`.
- Service authentication is API-key based for Roboflow - `ROBOFLOW_API_KEY` is appended as an `api_key` query parameter in `lib/roboflow_service.dart` and `lib/model_updater.dart`.

## Monitoring & Observability

**Error Tracking:**
- None detected - No Sentry, Crashlytics, analytics, or observability package is declared in `pubspec.yaml`.

**Logs:**
- Console/debug logging only - `print` is used in `lib/model_updater.dart`, `lib/classifier.dart`-adjacent inference paths use returned maps, and `debugPrint` is used in `lib/roboflow_service.dart` and `lib/cloud_vision_service.dart`.
- User-visible operational failures are shown through `SnackBar` in `lib/main.dart` for model initialization, upload, and training flows.

## CI/CD & Deployment

**Hosting:**
- Not detected - No deployment configuration is present; platform host projects exist under `android/`, `ios/`, `macos/`, `linux/`, `windows/`, and `web/`.

**CI Pipeline:**
- None detected - No workflow files found under `.github/workflows/`; no repo-level CI config detected.

## Environment Configuration

**Required env vars:**
- `ROBOFLOW_API_KEY` - Required for Roboflow uploads, training jobs, status polling, export requests, and Roboflow TFLite downloads in `lib/roboflow_service.dart` and `lib/model_updater.dart`.
- `ROBOFLOW_WORKSPACE` or `WORKSPACE` - Required for Roboflow job and TFLite download paths in `lib/roboflow_service.dart` and `lib/model_updater.dart`.
- `ROBOFLOW_PROJECT` or `PROJECT` - Required for Roboflow upload, job, export, and TFLite download paths in `lib/roboflow_service.dart` and `lib/model_updater.dart`.
- `ROBOFLOW_BATCH_NAME` - Optional upload batch label; defaults to `mobile-training` in `lib/roboflow_service.dart`.
- `ROBOFLOW_TRAIN_VERSION` or `MODEL_VERSION` - Selects an existing Roboflow dataset/model version in `lib/roboflow_service.dart`; `MODEL_VERSION` also drives model update checks in `lib/model_updater.dart`.
- `ROBOFLOW_MODEL_TYPE` - Optional Roboflow training model type; defaults to `rfdetr-nano` in `lib/roboflow_service.dart`.
- `MODEL_VERSION_URL` - Optional endpoint for latest model version lookup in `lib/model_updater.dart`.
- `MODEL_DOWNLOAD_URL` - Optional direct model download URL in `lib/model_updater.dart`.

**Secrets location:**
- `.env` file present - referenced by `lib/main.dart` and bundled by `pubspec.yaml`; contents are not read or documented.
- `.env.example` file present - template exists; contents are not read or documented because `.env*` files can contain secrets.
- Avoid placing actual secret values in documentation or logs; `lib/roboflow_service.dart` currently sends the Roboflow API key as a query parameter.

## Webhooks & Callbacks

**Incoming:**
- None detected - No server, route handler, webhook endpoint, or backend process exists in the Flutter app code under `lib/`.

**Outgoing:**
- Roboflow HTTP calls from the client app - `lib/roboflow_service.dart` sends image upload, training job, status, and export requests to `api.roboflow.com`.
- Model update HTTP calls from the client app - `lib/model_updater.dart` requests version metadata and downloads model files from `MODEL_VERSION_URL`, `MODEL_DOWNLOAD_URL`, or Roboflow-generated TFLite URLs.

---

*Integration audit: 2026-05-25*
