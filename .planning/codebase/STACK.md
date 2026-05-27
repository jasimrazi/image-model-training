# Technology Stack

**Analysis Date:** 2026-05-27

## Languages

**Primary:**
- Dart >=3.11.4 <4.0.0 - Flutter mobile/desktop/web app code in `lib/main.dart`, `lib/roboflow_inference_service.dart`, `lib/roboflow_service.dart`, `lib/cloud_vision_service.dart`, and related `lib/*.dart` files.
- Python 3.x - Minimal Django training backend in `backend/manage.py`, `backend/training_backend/settings.py`, and `backend/training/views.py`.

**Secondary:**
- Kotlin DSL / Gradle - Android build configuration in `android/settings.gradle.kts`, `android/build.gradle.kts`, and `android/app/build.gradle.kts`.
- Swift / C++ / CMake - Generated Flutter platform runner scaffolding in `macos/`, `ios/`, `windows/`, and `linux/`.

## Runtime

**Environment:**
- Flutter >=3.38.4 with Dart >=3.11.4, from `pubspec.lock` SDK constraints.
- Android Gradle Plugin 8.11.1 and Kotlin Android plugin 2.2.20, configured in `android/settings.gradle.kts`.
- Android Java/Kotlin target 17, configured in `android/app/build.gradle.kts`.
- Django >=5.0,<6.0 runtime for backend API, declared in `requirements.txt`.

**Package Manager:**
- Flutter/Dart package manager: `flutter pub` using `pubspec.yaml`.
- Lockfile: `pubspec.lock` present.
- Python package manager: `pip` using `requirements.txt`.
- Python lockfile: Not detected.

## Frameworks

**Core:**
- Flutter SDK - Cross-platform UI framework; app entrypoint and Material UI live in `lib/main.dart`.
- Provider 6.1.5+1 - Flutter state management; `ChangeNotifierProvider` is created in `lib/main.dart`, and `RoboflowProvider` is implemented in `lib/roboflow_provider.dart`.
- Django >=5.0,<6.0 - Backend API framework; settings live in `backend/training_backend/settings.py`, URL routing in `backend/training_backend/urls.py` and `backend/training/urls.py`, endpoint implementation in `backend/training/views.py`.

**Testing:**
- flutter_test SDK - Declared in `pubspec.yaml`; no `test/**/*.dart` files detected.
- Django testing framework is available through Django but no backend tests were detected under `backend/`.

**Build/Dev:**
- flutter_lints 6.0.0 - Analyzer/lint rules included via `analysis_options.yaml`.
- Android Gradle Plugin 8.11.1 - Android packaging in `android/app/build.gradle.kts`.
- Kotlin Android plugin 2.2.20 - Android Kotlin integration in `android/settings.gradle.kts`.
- Gradle repositories: Google Maven and Maven Central in `android/build.gradle.kts`.

## Key Dependencies

**Critical:**
- camera 0.11.4 - Camera capture dependency declared in `pubspec.yaml`; Android camera permission is declared in `android/app/src/main/AndroidManifest.xml`.
- image_picker 1.2.2 - Camera/gallery image selection used in `lib/main.dart` and `lib/upload_screen.dart`.
- http 1.6.0 - HTTP requests to Roboflow, backend trigger endpoint, model version URL, and model download URL in `lib/roboflow_inference_service.dart`, `lib/roboflow_service.dart`, and `lib/model_updater.dart`.
- flutter_dotenv 6.0.1 - Loads `.env` from bundled Flutter assets in `lib/main.dart` and provides runtime configuration in `lib/roboflow_inference_service.dart`, `lib/roboflow_service.dart`, and `lib/model_updater.dart`.
- tflite_flutter 0.11.0 - Local TensorFlow Lite inference in `lib/cloud_vision_service.dart` and `lib/classifier.dart`.
- google_mlkit_text_recognition 0.13.1 - On-device OCR in `lib/cloud_vision_service.dart`.
- google_mlkit_image_labeling 0.12.1 - On-device image labeling path in `lib/cloud_vision_service.dart`.
- google_mlkit_object_detection 0.13.1 - Declared in `pubspec.yaml` and preloaded on Android in `android/app/src/main/AndroidManifest.xml`.
- roboflow >=1.1,<2.0 - Python SDK used by `backend/training/views.py` to upload datasets, generate versions, export models, and start training.

**Infrastructure:**
- image 4.8.0 - Dart image decoding/resizing/preprocessing in `lib/cloud_vision_service.dart` and `lib/classifier.dart`.
- path_provider 2.1.5 - Local app documents directory for downloaded model storage in `lib/model_updater.dart`.
- shared_preferences 2.5.5 - Persists downloaded model version in `lib/model_updater.dart`.
- python-dotenv >=1.0,<2.0 - Loads backend `.env` into Django settings in `backend/training_backend/settings.py`.
- SQLite - Default Django database at `backend/db.sqlite3`, configured in `backend/training_backend/settings.py`.

## Configuration

**Environment:**
- Flutter app loads `.env` at startup with `dotenv.load(fileName: '.env')` in `lib/main.dart`.
- Flutter `.env` is bundled as an asset in `pubspec.yaml`; `.env` file present at repository root and must not be read or committed with real secrets.
- Backend loads `backend/.env` through `python-dotenv` in `backend/training_backend/settings.py`; `backend/.env` file present and must not be read or committed with real secrets.
- Flutter runtime env var names used by code: `ROBOFLOW_API_KEY`, `ROBOFLOW_PROJECT`, `PROJECT`, `ROBOFLOW_WORKSPACE`, `WORKSPACE`, `ROBOFLOW_INFER_VERSION`, `BACKEND_TRIGGER_URL`, `MODEL_VERSION`, `MODEL_VERSION_URL`, and `MODEL_DOWNLOAD_URL`.
- Backend env var names used by code: `DJANGO_SECRET_KEY`, `DJANGO_DEBUG`, `DJANGO_ALLOWED_HOSTS`, and `ROBOFLOW_API_KEY`.

**Build:**
- Flutter package manifest and asset wiring: `pubspec.yaml`.
- Dart/Flutter dependency lockfile: `pubspec.lock`.
- Dart analyzer/lints: `analysis_options.yaml`.
- Android app build config: `android/app/build.gradle.kts`.
- Android top-level Gradle config: `android/build.gradle.kts` and `android/settings.gradle.kts`.
- Android permissions and ML Kit dependency preload: `android/app/src/main/AndroidManifest.xml`.
- iOS app metadata: `ios/Runner/Info.plist`.
- Web app shell/PWA manifest: `web/index.html` and `web/manifest.json`.
- Backend dependencies: `requirements.txt`.
- Backend Django settings: `backend/training_backend/settings.py`.

## Platform Requirements

**Development:**
- Install Flutter dependencies with `flutter pub get` after changing `pubspec.yaml` or assets.
- Run Flutter static analysis with `flutter analyze` using `analysis_options.yaml`.
- Run Flutter tests with `flutter test`; no `test/**/*.dart` files are currently present.
- Install backend dependencies with `pip install -r requirements.txt` and run backend with `python backend/manage.py runserver`, as documented in `backend/README.md`.
- Camera/gallery flows need a device or emulator with image source support because `lib/main.dart` and `lib/upload_screen.dart` use `image_picker`.

**Production:**
- Flutter app targets Android, iOS, web, macOS, Windows, and Linux through generated platform folders (`android/`, `ios/`, `web/`, `macos/`, `windows/`, `linux/`).
- Android production packaging must preserve `androidResources.noCompress += "tflite"` in `android/app/build.gradle.kts` so `assets/model.tflite` remains loadable by `tflite_flutter`.
- Backend production deployment target is not specified; `backend/training_backend/wsgi.py` exposes a WSGI app and `backend/training_backend/settings.py` defaults to SQLite and DEBUG controlled by env vars.

---

*Stack analysis: 2026-05-27*
