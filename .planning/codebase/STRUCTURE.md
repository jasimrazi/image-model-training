# Codebase Structure

**Analysis Date:** 2026-05-27

## Directory Layout

```
vision/
├── lib/                         # Flutter Dart source for app UI, state, services, and ML helpers
├── backend/                     # Minimal Django backend for upload/training trigger workflow
│   ├── training/                # Django app with trigger endpoint and Roboflow SDK workflow
│   └── training_backend/        # Django project settings, root URLs, WSGI
├── assets/                      # Bundled TFLite model and label file used by local inference
├── android/                     # Android Flutter runner, Gradle config, permissions, ML Kit metadata
├── ios/                         # iOS Flutter runner and Xcode project files
├── linux/                       # Linux Flutter runner generated project files
├── macos/                       # macOS Flutter runner generated project files
├── web/                         # Web Flutter runner generated project files
├── windows/                     # Windows Flutter runner generated project files
├── .planning/                   # GSD planning and codebase mapping documents
├── .vscode/                     # Workspace editor settings
├── .idea/                       # JetBrains IDE project metadata
├── pubspec.yaml                 # Flutter package manifest, dependencies, and asset declarations
├── pubspec.lock                 # Locked Dart/Flutter dependency versions
├── requirements.txt             # Python backend dependency constraints
├── analysis_options.yaml        # Dart lint configuration
├── README.md                    # Project overview and setup instructions
└── AGENTS.md                    # Agent-facing project conventions and gotchas
```

## Directory Purposes

**`lib/`:**
- Purpose: Primary Flutter application source.
- Contains: App entrypoint, UI screens/widgets, Provider state, HTTP services, TFLite/ML Kit helpers, model update helper, API logger.
- Key files: `lib/main.dart`, `lib/upload_screen.dart`, `lib/roboflow_provider.dart`, `lib/roboflow_service.dart`, `lib/roboflow_inference_service.dart`, `lib/cloud_vision_service.dart`, `lib/classifier.dart`, `lib/model_updater.dart`, `lib/api_logger.dart`.

**`backend/`:**
- Purpose: Minimal Django project that receives Flutter training uploads and starts Roboflow training work.
- Contains: Django `manage.py`, `training_backend` project, `training` app, SQLite database, backend `.env` file, Python bytecode cache files.
- Key files: `backend/manage.py`, `backend/README.md`, `backend/training/views.py`, `backend/training/urls.py`, `backend/training_backend/settings.py`, `backend/training_backend/urls.py`, `backend/training_backend/wsgi.py`.

**`backend/training/`:**
- Purpose: Django app for the training trigger endpoint.
- Contains: App config, endpoint URL mapping, function-based view, Roboflow background-worker helper functions.
- Key files: `backend/training/views.py`, `backend/training/urls.py`, `backend/training/apps.py`.

**`backend/training_backend/`:**
- Purpose: Django project configuration.
- Contains: Settings, root URL include, WSGI module, package init.
- Key files: `backend/training_backend/settings.py`, `backend/training_backend/urls.py`, `backend/training_backend/wsgi.py`.

**`assets/`:**
- Purpose: Flutter-bundled local inference artifacts.
- Contains: TFLite model and ImageNet-style label list.
- Key files: `assets/model.tflite`, `assets/labels.txt`.

**`android/`:**
- Purpose: Android platform runner and build configuration for the Flutter app.
- Contains: Gradle Kotlin DSL files, Android manifest, Kotlin `MainActivity`, launcher resources, generated build/report files.
- Key files: `android/app/build.gradle.kts`, `android/settings.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/com/example/vision/MainActivity.kt`.

**`ios/`:**
- Purpose: iOS platform runner and Xcode project files.
- Contains: Runner app delegate, scene delegate, Info.plist, assets, storyboards, generated plugin registrant files, Xcode project/workspace.
- Key files: `ios/Runner/Info.plist`, `ios/Runner/AppDelegate.swift`, `ios/Runner/SceneDelegate.swift`, `ios/Runner.xcodeproj/project.pbxproj`.

**`linux/`, `macos/`, `web/`, `windows/`:**
- Purpose: Generated Flutter platform runners for desktop/web targets.
- Contains: Platform build files, generated plugin registrants, host application source, app icons/resources.
- Key files: `linux/CMakeLists.txt`, `macos/Runner/Info.plist`, `web/index.html`, `windows/runner/main.cpp`.

**`.planning/`:**
- Purpose: Project planning state, phase records, and codebase maps consumed by GSD commands.
- Contains: Project/requirements/roadmap docs, phase plans/summaries/verification, codebase map documents.
- Key files: `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`, `.planning/codebase/STACK.md`, `.planning/codebase/INTEGRATIONS.md`, `.planning/codebase/CONVENTIONS.md`, `.planning/codebase/TESTING.md`, `.planning/codebase/CONCERNS.md`.

## Key File Locations

**Entry Points:**
- `lib/main.dart`: Flutter app entrypoint, provider installation, app shell, scan tab, and legacy train widgets.
- `backend/manage.py`: Django command-line entrypoint.
- `backend/training_backend/urls.py`: Django root URL entrypoint for incoming HTTP requests.
- `backend/training/views.py`: `POST /api/trigger-training/` endpoint implementation.
- `android/app/src/main/kotlin/com/example/vision/MainActivity.kt`: Android Flutter host activity.
- `ios/Runner/AppDelegate.swift`: iOS Flutter plugin/app delegate entrypoint.

**Configuration:**
- `pubspec.yaml`: Dart SDK constraint, Flutter dependencies, and asset bundle declarations for `.env`, `assets/model.tflite`, and `assets/labels.txt`.
- `analysis_options.yaml`: Flutter lint include.
- `requirements.txt`: Python backend dependencies (`django`, `python-dotenv`, `roboflow`).
- `android/app/build.gradle.kts`: Android namespace, Java/Kotlin 17, release signing placeholder, and TFLite `noCompress` rule.
- `android/settings.gradle.kts`: Android Gradle plugin and Kotlin plugin versions.
- `android/app/src/main/AndroidManifest.xml`: Android camera/internet/storage permissions, Flutter activity, UCrop activity, ML Kit dependency metadata.
- `ios/Runner/Info.plist`: iOS bundle metadata and supported orientations.
- `backend/training_backend/settings.py`: Django env loading, apps, middleware, allowed hosts, SQLite database, static URL.
- `.env`: Root Flutter environment configuration file present; do not read or commit secret values.
- `backend/.env`: Backend environment configuration file present; do not read or commit secret values.

**Core Logic:**
- `lib/roboflow_inference_service.dart`: Hosted Roboflow inference scan client and response parser.
- `lib/roboflow_service.dart`: Multipart backend upload/training trigger client.
- `lib/roboflow_provider.dart`: Provider state for upload image list, class name, processing state, and status message.
- `lib/upload_screen.dart`: Active upload/training tab UI.
- `lib/cloud_vision_service.dart`: Local TFLite + ML Kit image labeling/text recognition service.
- `lib/classifier.dart`: Compact TFLite classifier abstraction.
- `lib/model_updater.dart`: Custom model version check/download and shared-preferences persistence.
- `lib/api_logger.dart`: Redacted API request/response/error debug logging.
- `backend/training/views.py`: Django multipart parsing, temporary dataset folder creation, Roboflow SDK upload/version/export/training.

**Testing:**
- `test/`: Not present in the current source tree.
- `ios/RunnerTests/RunnerTests.swift`: Generated iOS runner test scaffold.
- `macos/RunnerTests/RunnerTests.swift`: Generated macOS runner test scaffold.
- Use future Flutter tests under `test/` with names like `test/<feature>_test.dart`.

## Naming Conventions

**Files:**
- Dart source files use `snake_case.dart`: `lib/roboflow_inference_service.dart`, `lib/upload_screen.dart`, `lib/cloud_vision_service.dart`.
- Service files end in `_service.dart` when wrapping external APIs or local ML service logic: `lib/roboflow_service.dart`, `lib/cloud_vision_service.dart`.
- Provider state file ends in `_provider.dart`: `lib/roboflow_provider.dart`.
- Django modules use standard lowercase Python names: `backend/training/views.py`, `backend/training/urls.py`, `backend/training_backend/settings.py`.
- Platform files follow generated Flutter conventions: `android/app/build.gradle.kts`, `ios/Runner/Info.plist`, `windows/runner/main.cpp`.

**Directories:**
- Flutter app code belongs in `lib/` at the package root.
- Backend Django app code belongs under `backend/training/`.
- Backend Django project configuration belongs under `backend/training_backend/`.
- ML/runtime assets belong under `assets/` and must be listed in `pubspec.yaml`.
- Platform-specific changes belong in the matching runner directory: `android/`, `ios/`, `linux/`, `macos/`, `web/`, or `windows/`.

## Where to Add New Code

**New Feature:**
- Flutter UI: Add feature screens/widgets in a focused Dart file under `lib/`; use `lib/upload_screen.dart` as the pattern for feature-level UI files instead of growing `lib/main.dart`.
- Flutter state: Add shared mutable state to a `ChangeNotifier` file under `lib/`, following `lib/roboflow_provider.dart`.
- Flutter services: Add HTTP/backend clients under `lib/` with a clear service name such as `lib/<feature>_service.dart`; keep callers in widgets/providers.
- Backend API endpoint: Add URL routes in `backend/training/urls.py` and endpoint functions or helper modules under `backend/training/`.
- Tests: Add Dart unit/widget tests under `test/` when test coverage is introduced; add Python backend tests under `backend/training/tests.py` or `backend/training/tests/` if backend tests are added.

**New Component/Module:**
- Reusable Flutter widgets: Prefer private widgets in the feature file (`lib/upload_screen.dart`) for screen-specific UI; promote to a new shared file under `lib/` only when reused by multiple screens.
- New scan-related UI: Place near `ScanPage` initially or extract from `lib/main.dart` into a new `lib/scan_screen.dart` to keep entrypoint size manageable.
- New upload/training UI: Place in `lib/upload_screen.dart` or split into `lib/upload_<part>.dart` files when the screen grows.
- New model/inference abstraction: Place in `lib/cloud_vision_service.dart`, `lib/classifier.dart`, or a new `lib/<model>_service.dart` depending on ownership.
- New backend worker logic: Place long-running Roboflow/background helpers under `backend/training/` and keep `backend/training/views.py` as request parsing/scheduling glue.

**Utilities:**
- Shared Flutter API logging: Extend `lib/api_logger.dart`.
- Shared Flutter environment parsing or API helpers: Add a focused utility under `lib/`, and keep secret values out of logs.
- Backend utility functions: Add helper modules under `backend/training/`, not under `backend/training_backend/` unless they are project configuration.

## Special Directories

**`assets/`:**
- Purpose: Bundled model files consumed by Flutter services.
- Generated: No.
- Committed: Yes.

**`backend/__pycache__/`, `backend/training/__pycache__/`, `backend/training_backend/__pycache__/`:**
- Purpose: Python bytecode caches.
- Generated: Yes.
- Committed: Should not be committed for source changes.

**`build/`:**
- Purpose: Flutter and platform build outputs.
- Generated: Yes.
- Committed: Should not be committed for source changes.

**`.dart_tool/`:**
- Purpose: Flutter/Dart package resolution and generated tool state.
- Generated: Yes.
- Committed: No.

**`.planning/`:**
- Purpose: GSD planning and codebase documentation.
- Generated: Partly, by planning/mapping commands.
- Committed: Yes when project planning artifacts are tracked.

**`.idea/` and `.vscode/`:**
- Purpose: Local/editor workspace metadata.
- Generated: Partly by IDEs/editors.
- Committed: Project-specific settings may be tracked; avoid storing user secrets here.

**Platform runner directories (`android/`, `ios/`, `linux/`, `macos/`, `web/`, `windows/`):**
- Purpose: Flutter-generated host projects and platform configuration.
- Generated: Initially by Flutter, then hand-edited for permissions, build rules, and metadata.
- Committed: Yes.

---

*Structure analysis: 2026-05-27*
