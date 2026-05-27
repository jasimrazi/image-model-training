# Coding Conventions

**Analysis Date:** 2026-05-27

## Naming Patterns

**Files:**
- Use lowercase `snake_case.dart` for Flutter source files: `lib/main.dart`, `lib/upload_screen.dart`, `lib/roboflow_service.dart`, `lib/roboflow_inference_service.dart`, `lib/cloud_vision_service.dart`, `lib/model_updater.dart`, `lib/api_logger.dart`.
- Use Django's conventional lowercase Python module names under `backend/training/` and `backend/training_backend/`: `backend/training/views.py`, `backend/training/urls.py`, `backend/training_backend/settings.py`.
- Use platform-generated naming for generated/native files; avoid hand-editing generated registrants such as `windows/flutter/generated_plugin_registrant.cc`.

**Functions:**
- Use Dart `lowerCamelCase` for public and private methods: `main()` in `lib/main.dart`, `uploadBatchForTraining()` in `lib/roboflow_service.dart`, `checkAndUpdate()` in `lib/model_updater.dart`, `scanFile()` in `lib/cloud_vision_service.dart`.
- Prefix private Dart helpers with `_`: `_process()` and `_promptLabel()` in `lib/main.dart`, `_safe()` in `lib/roboflow_service.dart`, `_latestVersion()` and `_modelDownloadUrl()` in `lib/model_updater.dart`, `_parsePrediction()` in `lib/roboflow_inference_service.dart`.
- Use Python `snake_case` for Django views and helpers: `trigger_training()` and `_upload_generate_and_train()` in `backend/training/views.py`.

**Variables:**
- Use Dart `lowerCamelCase` for locals and fields: `configuredVersion`, `triggerUrl`, `safeLabel`, `statusMessage`, `isProcessing` in `lib/roboflow_inference_service.dart`, `lib/roboflow_service.dart`, and `lib/roboflow_provider.dart`.
- Use leading `_` for private state fields and top-level private constants: `_images`, `_className`, `_isProcessing` in `lib/roboflow_provider.dart`; `_bg`, `_surface`, `_ink`, `_muted`, `_border`, `_accent` in `lib/main.dart` and `lib/upload_screen.dart`.
- Use Python `UPPER_CASE` for Django settings constants: `BASE_DIR`, `SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS`, `INSTALLED_APPS` in `backend/training_backend/settings.py`.

**Types:**
- Use Dart `UpperCamelCase` for classes and data objects: `MyApp`, `ScanPage`, `ScanItem`, `HostedInferenceResult`, `UploadTrainingResult`, `RoboflowProvider`, `CloudVisionService`, `VisionResult`, `VisionLabel`.
- Use private widget classes with leading `_` when the widget is only used in one file: `_AppShell`, `_BottomNav`, `_ScanCard`, `_ActionBtn`, `_LabelDialog` in `lib/main.dart`; `_Header`, `_InfoCard`, `_ImageTile`, `_ActionBar` in `lib/upload_screen.dart`.
- Use immutable result objects with `final` fields and `const` constructors/factories where possible: `HostedInferenceResult` in `lib/roboflow_inference_service.dart` and `UploadTrainingResult` in `lib/roboflow_service.dart`.

## Code Style

**Formatting:**
- Use Dart's standard formatter (`dart format .`) and Flutter's default two-space indentation. The repo uses `analysis_options.yaml` with `include: package:flutter_lints/flutter.yaml`.
- Prefer `const` constructors and widgets wherever inputs are compile-time constants, as seen throughout `lib/main.dart` and `lib/upload_screen.dart`.
- Keep Flutter UI trees declarative with extracted private widgets for repeated sections: `_ActionBtn`, `_Chip`, `_Loader`, `_EmptyState` in `lib/main.dart`; `_Button`, `_StatusMessage`, `_SelectedImages` in `lib/upload_screen.dart`.
- Python backend style is close to PEP 8: four-space indentation, lowercase function names, module-level logger in `backend/training/views.py`.

**Linting:**
- Dart linting uses `flutter_lints` via `analysis_options.yaml`; run `flutter analyze` before handing off changes.
- No custom Dart analyzer rule overrides are present; follow the default Flutter lint set.
- No Python formatter/linter config is detected; keep Django changes PEP 8-compatible and avoid introducing project-specific style drift.

## Import Organization

**Order:**
1. Dart SDK imports first: `dart:io`, `dart:convert`, `dart:typed_data` in `lib/main.dart`, `lib/roboflow_inference_service.dart`, and `lib/cloud_vision_service.dart`.
2. Flutter and third-party package imports next: `package:flutter/material.dart`, `package:flutter_dotenv/flutter_dotenv.dart`, `package:http/http.dart`, `package:provider/provider.dart`.
3. App package imports last: `package:vision/api_logger.dart`, `package:vision/roboflow_provider.dart`, `package:vision/upload_screen.dart`.
4. Local relative imports are rare; `lib/main.dart` uses `import 'roboflow_service.dart';`. Prefer `package:vision/...` imports for consistency with most files.

**Path Aliases:**
- Dart app code imports itself through the package name `package:vision/...`, configured by `name: vision` in `pubspec.yaml`.
- No custom Dart import aliases or build-time path aliases are detected.

## Error Handling

**Patterns:**
- Service calls should return typed failure results instead of throwing into the UI. Use `HostedInferenceResult.failed()` in `lib/roboflow_inference_service.dart` and `UploadTrainingResult.failed()` in `lib/roboflow_service.dart`.
- Validate required inputs before network calls. Examples: empty image batches and missing `BACKEND_TRIGGER_URL` in `lib/roboflow_service.dart`; missing `ROBOFLOW_API_KEY` and project in `lib/roboflow_inference_service.dart`.
- Wrap network and model operations in `try`/`catch` at service boundaries: `RoboflowInferenceService.scan()` in `lib/roboflow_inference_service.dart`, `RoboflowService.uploadBatchForTraining()` in `lib/roboflow_service.dart`, and `ModelUpdater.checkAndUpdate()` in `lib/model_updater.dart`.
- Guard Flutter async UI updates with `mounted` before using `context` or `setState` after awaits. Existing examples are `_promptLabel()` and `_process()` in `lib/main.dart`, and `_addImages()` in `lib/upload_screen.dart`.
- Django endpoints return `JsonResponse` with explicit status codes for invalid method, bad input, missing server config, and unexpected exceptions in `backend/training/views.py`.

## Logging

**Framework:** `debugPrint` through `ApiLogger` for Dart API calls; Python `logging` for Django backend.

**Patterns:**
- Route API request/response/error logs through `ApiLogger` in `lib/api_logger.dart`; it redacts `api_key` query parameters and truncates long response bodies.
- Only emit Dart API logs in debug mode. `ApiLogger` checks `kDebugMode` before printing in `lib/api_logger.dart`.
- For new Dart network integrations, call `ApiLogger.request()`, `ApiLogger.response()`, and `ApiLogger.error()` as done in `lib/roboflow_service.dart`, `lib/roboflow_inference_service.dart`, and `lib/model_updater.dart`.
- Avoid raw `print()` in new Dart code; existing `print()` calls remain in `lib/cloud_vision_service.dart` and `lib/model_updater.dart`, but new code should use `debugPrint` behind `kDebugMode` or `ApiLogger`.
- Use `logger.info()` and `logger.exception()` in Django backend code, following `backend/training/views.py`.

## Comments

**When to Comment:**
- Use section comments to separate large UI/service regions when a file contains multiple responsibilities, as in `lib/main.dart` and `lib/cloud_vision_service.dart`.
- Use step comments for multi-step workflows such as multipart upload in `lib/roboflow_service.dart` and Roboflow training orchestration in `backend/training/views.py`.
- Keep comments current and implementation-focused. Avoid placeholder comments such as `// Adjust import path as needed` in new code; existing examples are in `lib/roboflow_service.dart` and `lib/roboflow_provider.dart`.

**JSDoc/TSDoc:**
- Dart doc comments are sparse. Use `///` for public services and non-obvious public methods, matching `uploadForTraining()` and `uploadBatchForTraining()` in `lib/roboflow_service.dart` and `checkAndUpdate()` in `lib/model_updater.dart`.
- Private widgets and helpers generally rely on clear names plus section comments rather than doc comments.

## Function Design

**Size:** Keep business/service functions focused on one workflow. `RoboflowService.uploadBatchForTraining()` in `lib/roboflow_service.dart` owns validation, multipart creation, timeout, logging, and result mapping for one upload request. Extract parsing helpers as private statics, as in `lib/roboflow_inference_service.dart`.

**Parameters:** Use named parameters for constructors and factory methods, especially result objects and widgets: `ScanItem({required this.image, required this.result})` in `lib/main.dart`, `UploadTrainingResult.failed({required ...})` in `lib/roboflow_service.dart`, and widget constructors in `lib/upload_screen.dart`.

**Return Values:** Return domain-specific data objects rather than raw maps when values cross file boundaries: `HostedInferenceResult` in `lib/roboflow_inference_service.dart`, `UploadTrainingResult` in `lib/roboflow_service.dart`, `VisionResult` in `lib/cloud_vision_service.dart`. Raw maps are limited to model metadata or inference output internals such as `rawResponse` in `lib/cloud_vision_service.dart`.

## Module Design

**Exports:**
- Modules expose concrete classes directly; there are no barrel export files. Import the exact file that owns the class, such as `package:vision/roboflow_provider.dart` or `package:vision/api_logger.dart`.
- Stateful app state lives in `RoboflowProvider` in `lib/roboflow_provider.dart`; UI should read or watch it through `provider` instead of duplicating upload state.
- Service modules use static methods for simple integration boundaries: `RoboflowInferenceService` in `lib/roboflow_inference_service.dart`, `RoboflowService` in `lib/roboflow_service.dart`, and `ModelUpdater` in `lib/model_updater.dart`.

**Barrel Files:**
- Not used. Do not add barrel files unless a broader module split is introduced; direct imports are the current convention.

---

*Convention analysis: 2026-05-27*
