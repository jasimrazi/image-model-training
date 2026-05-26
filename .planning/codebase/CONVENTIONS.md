# Coding Conventions

**Analysis Date:** 2026-05-25

## Naming Patterns

**Files:**
- Use lowercase `snake_case.dart` for Dart source files, matching the current files in `lib/`: `lib/main.dart`, `lib/classifier.dart`, `lib/model_updater.dart`, `lib/roboflow_service.dart`, and `lib/cloud_vision_service.dart`.
- Keep app-level widgets and screens in `lib/main.dart` only while following the current single-file UI shape. If the UI is split later, preserve file names based on the primary class or feature, such as `scan_page.dart` for `ScanPage` and `train_page.dart` for `TrainPage`.

**Functions:**
- Use lower camelCase for methods and functions: `main()` in `lib/main.dart`, `checkAndUpdate()` and `downloadFromUrl()` in `lib/model_updater.dart`, `uploadBatchForTraining()` and `runTrainingPipeline()` in `lib/roboflow_service.dart`, and `scanFile()` in `lib/cloud_vision_service.dart`.
- Prefix private helpers with `_`: `_initModel()` in `lib/main.dart`, `_latestVersion()` in `lib/model_updater.dart`, `_safe()` and `_split()` in `lib/roboflow_service.dart`, and `_imageToInputTensor()` in `lib/cloud_vision_service.dart`.
- Name callback parameters by intent, not implementation: `onTap`, `onConfirm`, `onReset`, `onCamera`, `onGallery`, and `onStatusUpdate` appear throughout `lib/main.dart` and `lib/roboflow_service.dart`.

**Variables:**
- Use lower camelCase for local values and fields: `_modelReady`, `_uploaded`, `_pipeMessage`, `_pipelineDone`, and `_className` in `lib/main.dart`; `latestVersion`, `modelDownloadUrl`, and `savePath` in `lib/model_updater.dart`.
- Prefix private state fields and constants with `_`: `_tab`, `_classifier`, `_items`, `_picker`, `_kMinImages`, `_kIdealImages`, `_bg`, `_surface`, and `_accent` in `lib/main.dart`.
- Use short loop variables only in compact loops or builders: `i` in loops in `lib/roboflow_service.dart` and item builders in `lib/main.dart`; use descriptive names for request and model values such as `modelResponse`, `versionResult`, `trainingJob`, and `exportUrl`.

**Types:**
- Use UpperCamelCase for classes and enums: `Classifier` in `lib/classifier.dart`, `ModelUpdater` in `lib/model_updater.dart`, `RoboflowService`, `TrainingStatus`, `PipelineResult`, `VersionGenerationResult`, `TrainingState`, and `PipelineStep` in `lib/roboflow_service.dart`.
- Use public widget classes for app-level screens (`MyApp`, `ScanPage`, `TrainPage`, `ScanItem` in `lib/main.dart`) and private widget classes for implementation details (`_BottomNav`, `_ScanCard`, `_StepPipeline`, `_ActionBtn`, `_Sheet` in `lib/main.dart`).
- Use immutable value classes with `final` fields and `const` constructors when possible, as in `TrainingStatus`, `VersionGenerationResult`, and `PipelineResult` in `lib/roboflow_service.dart`. `VisionLabel` and `VisionResult` in `lib/cloud_vision_service.dart` use final fields but non-const constructors.

## Code Style

**Formatting:**
- Use Dart formatting (`dart format .`) and Flutter analyzer formatting expectations from `package:flutter_lints/flutter.yaml`, included by `analysis_options.yaml`.
- Prefer two-space indentation and trailing commas in multi-line Flutter widget constructors. This style is common in `lib/main.dart`, for example `MaterialApp`, `Scaffold`, `Container`, and `TextStyle` constructions.
- Prefer `const` widgets and values wherever constructor inputs are compile-time constants. Existing examples include `const MyApp()` in `lib/main.dart`, `const _Loader(...)`, `const SizedBox(...)`, `const TextStyle(...)`, and `const Duration(...)` in `lib/main.dart` and `lib/roboflow_service.dart`.
- Keep long widget trees split into small private widgets. `lib/main.dart` uses private widgets such as `_ScanActions`, `_StepClassName`, `_StepAddImages`, `_StepPipeline`, `_PipelineRow`, `_PageHeader`, `_ActionBtn`, `_InfoCard`, and `_Banner`.
- Use section comments sparingly to divide large files by feature area. `lib/main.dart`, `lib/roboflow_service.dart`, and `lib/cloud_vision_service.dart` use visible divider comments such as `// ─────────────────────────────────────────────` and `// ═════════════════════════════════════════════`.

**Linting:**
- Linting uses `flutter_lints` via `analysis_options.yaml`; run `flutter analyze` as the primary quality gate.
- There are no repository-specific lint overrides in `analysis_options.yaml`, so new code should satisfy the default Flutter lint set.
- Avoid analyzer warnings that already appear in the code style surface: prefer braces around multi-line `if` bodies, prefer `debugPrint` over raw `print`, and prefer `const` where possible.

## Import Organization

**Order:**
1. Dart SDK imports first, such as `dart:io`, `dart:convert`, and `dart:typed_data` in `lib/main.dart`, `lib/roboflow_service.dart`, and `lib/cloud_vision_service.dart`.
2. Package imports next, such as `package:flutter/material.dart`, `package:flutter_dotenv/flutter_dotenv.dart`, `package:http/http.dart`, `package:image/image.dart`, and `package:tflite_flutter/tflite_flutter.dart`.
3. Project imports last. `lib/main.dart` uses both `package:vision/model_updater.dart` and relative imports `classifier.dart` and `roboflow_service.dart`; prefer one style per file when adding new imports.

**Path Aliases:**
- The package name is `vision` in `pubspec.yaml`, enabling `package:vision/...` imports. Current code uses `package:vision/model_updater.dart` in `lib/main.dart`.
- Relative imports are also present in `lib/main.dart` (`classifier.dart`, `roboflow_service.dart`). For consistency in new code under `lib/`, prefer `package:vision/...` imports when crossing feature files and keep relative imports only for tightly coupled files in the same directory.

## Error Handling

**Patterns:**
- Return explicit result objects or nullable fallback values from service boundaries rather than throwing across UI code. `ModelUpdater.checkAndUpdate()` in `lib/model_updater.dart` returns `String?`, `RoboflowService.uploadBatchForTraining()` in `lib/roboflow_service.dart` returns `bool`, and `RoboflowService.runTrainingPipeline()` returns `PipelineResult`.
- Use typed result classes for multi-field outcomes. `TrainingStatus`, `VersionGenerationResult`, `TrainingJobStartResult`, and `PipelineResult` in `lib/roboflow_service.dart` carry status, IDs, URLs, progress, and errors without exceptions.
- In widgets, guard async UI updates with `mounted` after awaits. `_initModel()`, `_promptLabel()`, and `_startPipeline()` in `lib/main.dart` check `mounted` before `setState`, `ScaffoldMessenger`, or other context-dependent actions.
- Surface user-facing failures through UI messages. `_initModel()` in `lib/main.dart` shows a `SnackBar` when model loading fails, `_startPipeline()` stores failure text in `_doneMsg`, and `_promptLabel()` displays upload success or failure through `_toast()`.
- At service boundaries, catch network and platform errors and convert them to failure results. `RoboflowService.startTraining()`, `RoboflowService.getTrainingStatus()`, `_getTfliteExportUrl()`, and `ModelUpdater.downloadFromUrl()` all catch exceptions and return failed/null values.
- Avoid swallowing exceptions without diagnostics in new code. Existing silent catches in `lib/cloud_vision_service.dart` asset verification and `lib/model_updater.dart` fallback logic should not be copied unless the fallback behavior is explicitly documented.

## Logging

**Framework:** console logging via `debugPrint` and `print`.

**Patterns:**
- Prefer `debugPrint()` for diagnostic logs in Flutter code. `lib/roboflow_service.dart` uses `debugPrint()` for upload errors, training status, export URL errors, and transient polling errors. `lib/model_updater.dart` uses `debugPrint()` in `downloadFromUrl()`.
- Avoid raw `print()` in new code. `lib/model_updater.dart` and `lib/cloud_vision_service.dart` use `print()` for model update and inference logs, but `debugPrint()` is the better app convention because it is Flutter-aware and truncation-safe.
- Do not log secrets or full authenticated URLs. `lib/roboflow_service.dart` and `lib/model_updater.dart` build Roboflow URLs containing `api_key`; new logs should include status codes, endpoint categories, or IDs only, not complete URLs or API key query parameters.

## Comments

**When to Comment:**
- Use comments to explain workflow stages, external API behavior, and non-obvious ML/model constraints. Examples include pipeline step comments in `lib/roboflow_service.dart`, tensor preprocessing comments in `lib/cloud_vision_service.dart`, and training wizard step comments in `lib/main.dart`.
- Do not comment obvious Flutter widget structure. Prefer extracting a private widget or helper method when comments are only labeling a UI subsection.
- Preserve important platform/model assumptions near the implementation. `Classifier.threshold` in `lib/classifier.dart` comments the 70% confidence threshold, and `CloudVisionService.inputSize` plus `_imageToInputTensor()` in `lib/cloud_vision_service.dart` encode model input assumptions.

**JSDoc/TSDoc:**
- Dart uses `///` documentation comments for public APIs when the behavior is not obvious. Current examples are `ModelUpdater.checkAndUpdate()` in `lib/model_updater.dart` and `RoboflowService.runTrainingPipeline()` in `lib/roboflow_service.dart`.
- Add `///` comments to new public service methods, public model classes, and public enum values that are consumed outside their file. Private widgets in `lib/main.dart` generally do not need documentation comments.

## Function Design

**Size:**
- Keep service methods focused on one external operation or one workflow stage. `RoboflowService.uploadBatchForTraining()`, `startTraining()`, `getTrainingStatus()`, and `_getTfliteExportUrl()` in `lib/roboflow_service.dart` are good boundaries.
- Split large widget build logic into private methods or widgets. `lib/main.dart` uses `_body()`, `_stepView()`, `_progressView()`, `_doneView()`, and many small private `StatelessWidget` classes.
- Avoid adding more responsibilities to already-large classes in `lib/main.dart`; new scanner, training, or reusable UI behavior should become a private widget or a new file with a focused class.

**Parameters:**
- Use named parameters for constructors and public APIs with multiple values. Examples: `ScanPage({super.key, required this.classifier, required this.modelReady})` in `lib/main.dart`, `TrainingStatus({required this.state, this.progress, this.exportUrl, this.message})` in `lib/roboflow_service.dart`, and `Classifier.loadModel({String? modelPath})` in `lib/classifier.dart`.
- Use `required` for non-null dependencies, callbacks, and state passed into widgets. Current widgets in `lib/main.dart` consistently require callbacks and display data.
- Use nullable parameters only for genuine optional behavior, such as `String? modelPath` in `lib/classifier.dart`, `double? progress` in `lib/roboflow_service.dart`, and `Widget? action` in `_PageHeader` in `lib/main.dart`.

**Return Values:**
- Use `Future<T>` for asynchronous file, network, and model work. Examples: `Classifier.classify()` in `lib/classifier.dart`, `ModelUpdater.checkAndUpdate()` in `lib/model_updater.dart`, and `RoboflowService.runTrainingPipeline()` in `lib/roboflow_service.dart`.
- Use `Map<String, dynamic>` only where flexible model output is currently required. `Classifier.classify()` in `lib/classifier.dart` returns label, confidence, recognition status, and all scores as a map; prefer typed result classes for new service APIs when the schema is stable.
- Use factory constructors for success/failure result values. `VersionGenerationResult.success()`, `VersionGenerationResult.failed()`, `PipelineResult.success()`, and `PipelineResult.failed()` in `lib/roboflow_service.dart` are the current pattern.

## Module Design

**Exports:**
- There are no barrel files. Import concrete files directly from `lib/`, such as `package:vision/model_updater.dart` or `roboflow_service.dart` in `lib/main.dart`.
- Service classes are static utility-style APIs where no instance state is required. `ModelUpdater` in `lib/model_updater.dart` and `RoboflowService` in `lib/roboflow_service.dart` expose static methods and private static helpers.
- Stateful resources should remain instance-owned and disposable. `Classifier` in `lib/classifier.dart` owns the TFLite interpreter and exposes `dispose()`. `CloudVisionService` in `lib/cloud_vision_service.dart` owns both the interpreter and ML Kit recognizers and exposes `dispose()`.

**Barrel Files:**
- Not used. Do not add a barrel export file unless multiple feature files are introduced and import churn becomes significant.

---

*Convention analysis: 2026-05-25*
