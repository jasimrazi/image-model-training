# Testing Patterns

**Analysis Date:** 2026-05-25

## Test Framework

**Runner:**
- Flutter test runner via `flutter_test` from the Flutter SDK, declared in `pubspec.yaml`.
- Config: Not detected. There is no `test/` directory, no `flutter_test_config.dart`, no `mockito`/`mocktail`, and no separate coverage config.

**Assertion Library:**
- Flutter/Dart matcher assertions from `package:flutter_test/flutter_test.dart` are available through `flutter_test` in `pubspec.yaml`.
- No third-party assertion, fake, or mocking library is configured.

**Run Commands:**
```bash
flutter test              # Run all tests when test files exist
flutter test --coverage   # Run tests and generate coverage/lcov.info
flutter analyze           # Primary current verification command
```

## Test File Organization

**Location:**
- No test files detected. Add tests under a root `test/` directory, matching Flutter conventions.
- Place unit tests for services next to a mirrored path under `test/`: `test/classifier_test.dart` for `lib/classifier.dart`, `test/model_updater_test.dart` for `lib/model_updater.dart`, `test/roboflow_service_test.dart` for `lib/roboflow_service.dart`, and `test/cloud_vision_service_test.dart` for `lib/cloud_vision_service.dart`.
- Place widget tests under `test/widgets/` or feature-named files once UI is split from `lib/main.dart`. For current code, use `test/main_test.dart` or `test/scan_page_test.dart` when testing `MyApp`, `ScanPage`, and `TrainPage` from `lib/main.dart`.

**Naming:**
- Use Flutter/Dart convention `*_test.dart` for every test file. No current files match this pattern.
- Name test groups after the class or method under test, such as `group('Classifier', ...)`, `group('ModelUpdater.checkAndUpdate', ...)`, and `group('RoboflowService.runTrainingPipeline', ...)`.

**Structure:**
```
test/
├── classifier_test.dart              # Unit tests for `lib/classifier.dart`
├── model_updater_test.dart           # Unit tests for `lib/model_updater.dart`
├── roboflow_service_test.dart        # Unit tests for `lib/roboflow_service.dart`
├── cloud_vision_service_test.dart    # Unit tests for `lib/cloud_vision_service.dart`
└── widgets/
    ├── scan_page_test.dart           # Widget tests for scanner UI in `lib/main.dart`
    └── train_page_test.dart          # Widget tests for training UI in `lib/main.dart`
```

## Test Structure

**Suite Organization:**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vision/roboflow_service.dart';

void main() {
  group('RoboflowService', () {
    test('splits uploaded batches across train, valid, and test sets', () {
      // Arrange
      // Act
      // Assert
    });
  });
}
```

**Patterns:**
- Use `group()` per class or workflow and `test()` per behavior for service code in `lib/classifier.dart`, `lib/model_updater.dart`, `lib/roboflow_service.dart`, and `lib/cloud_vision_service.dart`.
- Use `testWidgets()` for UI behavior in `lib/main.dart`, pumping `MyApp`, `ScanPage`, or extracted widgets once dependencies are injectable.
- Use Arrange/Act/Assert comments in complex tests where setup includes file fixtures, HTTP clients, or asset bundles.
- Use `setUp()` to create temporary files, fake clients, and shared dependencies; use `tearDown()` to remove temporary files and dispose Flutter resources.
- For async code, `await` all futures and use `expectLater()` when asserting future failures.

## Mocking

**Framework:** Not configured.

**Patterns:**
```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelUpdater', () {
    test('returns null when no model update is configured', () async {
      // Prefer injectable wrappers for HTTP, SharedPreferences, and paths
      // before testing `lib/model_updater.dart` network/file behavior.
    });
  });
}
```

**What to Mock:**
- Mock or fake network calls from `RoboflowService` in `lib/roboflow_service.dart`, especially `http.post()` and `http.get()` calls that upload images, start training, poll jobs, and fetch export URLs.
- Mock or fake file-system paths and storage dependencies in `ModelUpdater` in `lib/model_updater.dart`: `getApplicationDocumentsDirectory()`, `SharedPreferences.getInstance()`, and model file writes.
- Mock or wrap image picker and camera/gallery behavior before widget testing `ScanPage` and `TrainPage` in `lib/main.dart`; direct `ImagePicker` calls are not test-friendly without injection.
- Mock or wrap TensorFlow Lite and ML Kit boundaries in `Classifier` and `CloudVisionService` (`lib/classifier.dart`, `lib/cloud_vision_service.dart`) because interpreter and recognizer creation depend on native plugins and bundled assets.

**What NOT to Mock:**
- Do not mock pure formatting and state helpers once they are public or extractable, such as safe label normalization behavior from `RoboflowService._safe()` and class name normalization in `_LabelDialogState._submit()` in `lib/main.dart`; prefer direct unit tests when possible.
- Do not mock simple value classes and factories in `lib/roboflow_service.dart`: `TrainingStatus`, `VersionGenerationResult`, `TrainingJobStartResult`, and `PipelineResult`.
- Do not mock Flutter widgets solely to test layout. Pump the real widget with fake dependencies and assert visible text, enabled/disabled buttons, and state transitions.

## Fixtures and Factories

**Test Data:**
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

Future<File> writeTempImageBytes(List<int> bytes) async {
  final dir = await Directory.systemTemp.createTemp('vision_test_');
  return File('${dir.path}/sample.jpg').writeAsBytes(bytes);
}
```

**Location:**
- No fixtures are currently present.
- Add reusable fixture helpers under `test/fixtures/` or `test/helpers/` when tests need image bytes, fake Roboflow responses, fake model version responses, or fake TFLite labels.
- Keep large model fixtures out of tests unless absolutely necessary. Prefer a tiny synthetic image fixture and mocked classifier/model boundaries for most tests of `lib/main.dart`.

## Coverage

**Requirements:** None enforced.

**View Coverage:**
```bash
flutter test --coverage
# Open or upload `coverage/lcov.info` with an LCOV-compatible viewer.
```

## Test Types

**Unit Tests:**
- Not present. Add unit tests first for deterministic service behavior in `lib/roboflow_service.dart`, especially result factories, HTTP status handling, training status mapping, timeout behavior, and split/tag/name generation.
- Add unit tests for `lib/model_updater.dart` only after dependency seams are introduced for HTTP, path provider, shared preferences, and file writes.
- Add unit tests for image preprocessing and result mapping in `lib/classifier.dart` and `lib/cloud_vision_service.dart` by wrapping TFLite/ML Kit dependencies or moving pure data-shaping logic into testable helpers.

**Integration Tests:**
- Not present. Add integration-style tests only after unit seams exist, because `lib/main.dart`, `lib/classifier.dart`, `lib/model_updater.dart`, and `lib/roboflow_service.dart` currently call plugins, filesystem APIs, network APIs, and bundled assets directly.
- Use integration tests for full scan and training workflows when a device/emulator and plugin setup are required.

**E2E Tests:**
- Not used. No `integration_test` dependency or `integration_test/` directory is present in `pubspec.yaml`.
- Camera/gallery and native ML flows should be verified manually with `flutter run -d <deviceId>` until an integration test harness is added.

## Common Patterns

**Async Testing:**
```dart
test('returns a failed result when training cannot start', () async {
  final result = await RoboflowService.startTraining('1');

  expect(result.success, isFalse);
  expect(result.error, isNotEmpty);
});
```

**Error Testing:**
```dart
test('failed pipeline results carry an error message', () {
  final result = PipelineResult.failed('Training timed out after 60 minutes.');

  expect(result.success, isFalse);
  expect(result.error, contains('timed out'));
});
```

**Widget Testing:**
```dart
testWidgets('shows scanner loading state before the model is ready', (tester) async {
  // Add an injectable fake classifier before pumping `ScanPage` from `lib/main.dart`.
  // Then assert visible loading text and disabled scan actions.
});
```

---

*Testing analysis: 2026-05-25*
