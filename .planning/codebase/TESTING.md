# Testing Patterns

**Analysis Date:** 2026-05-27

## Test Framework

**Runner:**
- Flutter test runner from `flutter_test` SDK dependency in `pubspec.yaml`.
- Config: Not detected. There is no `test/` directory, `flutter_test_config.dart`, `package:test` config, `mockito` config, or `build_runner` test setup.
- macOS native XCTest template exists at `macos/RunnerTests/RunnerTests.swift`; it contains only the generated `testExample()` placeholder.

**Assertion Library:**
- Dart: Flutter's `expect()` from `flutter_test` is available through `dev_dependencies` in `pubspec.yaml`.
- Swift/macOS: XCTest assertions are available in `macos/RunnerTests/RunnerTests.swift`.
- Python/Django: Not configured. `requirements.txt` contains `django`, `python-dotenv`, and `roboflow`; no `pytest`, `pytest-django`, or Django test modules are present.

**Run Commands:**
```bash
flutter test              # Run all Flutter tests when test/**/*.dart files exist
flutter test --watch      # Watch mode is not a standard Flutter command; rerun focused tests manually
flutter test --coverage   # Generate Flutter coverage in coverage/lcov.info when tests exist
flutter analyze           # Primary current verification because no Flutter tests are present
```

## Test File Organization

**Location:**
- No Dart test files are present. Add Flutter tests under `test/` at the repository root.
- Co-locate tests by feature name rather than mirroring every private widget. Suggested first files: `test/roboflow_provider_test.dart`, `test/roboflow_inference_service_test.dart`, `test/roboflow_service_test.dart`, and widget tests such as `test/upload_screen_test.dart`.
- Django tests are not present. Add backend tests under `backend/training/tests.py` or `backend/training/tests/test_views.py` if the backend receives behavior changes.

**Naming:**
- Use `*_test.dart` for Flutter/Dart test files, matching Flutter conventions.
- Use `test_*.py` or Django `tests.py` for Python backend tests if introduced.
- Keep test names behavior-oriented: `uploadAndTrain sets status message on success`, `scan returns failure when API key is missing`, `trigger_training rejects non-POST requests`.

**Structure:**
```
test/
├── roboflow_provider_test.dart          # ChangeNotifier state and upload flow behavior
├── roboflow_service_test.dart           # Multipart validation/result mapping with injectable HTTP seams
├── roboflow_inference_service_test.dart # Response parsing and failure cases
└── upload_screen_test.dart              # Widget state and provider interactions

backend/training/tests.py                # Django endpoint tests if Python tests are added
```

## Test Structure

**Suite Organization:**
```typescript
// Dart pattern to use for this repo (no existing Dart tests are present):
import 'package:flutter_test/flutter_test.dart';
import 'package:vision/roboflow_provider.dart';

void main() {
  group('RoboflowProvider', () {
    test('addImages appends files and clears status', () {
      final provider = RoboflowProvider();

      // arrange input files, act through provider methods, assert public getters
      expect(provider.images, isEmpty);
    });
  });
}
```

**Patterns:**
- Test public APIs and state transitions rather than private helpers. Examples: `RoboflowProvider` getters and methods in `lib/roboflow_provider.dart`, `HostedInferenceResult.failed()` in `lib/roboflow_inference_service.dart`, `UploadTrainingResult.failed()` and `.ok()` in `lib/roboflow_service.dart`.
- Use `setUp()` for shared provider/service setup once tests exist.
- Use `testWidgets()` for Flutter UI behavior in `lib/upload_screen.dart` and `lib/main.dart`; wrap widgets with required providers, e.g. `ChangeNotifierProvider(create: (_) => RoboflowProvider(), child: const MaterialApp(home: UploadScreen()))`.
- For backend endpoint tests, use Django's test `Client` against `backend/training/views.py` and assert JSON bodies plus status codes.

## Mocking

**Framework:** Not detected.

**Patterns:**
```typescript
// Current code uses static services and top-level dotenv access, so prefer adding seams
// before heavy mocking. Example target seam for future tests:
class FakeUploadService {
  Future<UploadTrainingResult> uploadBatchForTraining(files, label) async {
    return UploadTrainingResult.ok(files.length);
  }
}
```

**What to Mock:**
- Mock network calls to Roboflow and the backend for `lib/roboflow_inference_service.dart`, `lib/roboflow_service.dart`, and `lib/model_updater.dart`.
- Mock or fake file/image inputs for provider and service tests; avoid requiring camera/gallery access in automated tests.
- Mock `SharedPreferences` for `ModelUpdater.checkAndUpdate()` in `lib/model_updater.dart` using `SharedPreferences.setMockInitialValues()` once tests are added.
- Mock Django Roboflow SDK calls in `backend/training/views.py` so backend tests do not upload datasets or start training.

**What NOT to Mock:**
- Do not mock `RoboflowProvider` when testing `UploadScreen`; use the real provider from `lib/roboflow_provider.dart` unless testing an integration seam.
- Do not mock simple result value objects like `HostedInferenceResult`, `UploadTrainingResult`, `VisionResult`, or `VisionLabel`; construct real instances.
- Do not run real Roboflow requests, camera capture, gallery picker, ML Kit, or TFLite inference in unit tests.

## Fixtures and Factories

**Test Data:**
```typescript
// Recommended fixture pattern for future Dart tests:
const successfulInferenceJson = {
  'top': 'Pepsi-500ml',
  'confidence': 0.91,
};

const uploadOk = UploadTrainingResult(
  success: true,
  uploaded: 2,
  total: 2,
  message: 'Uploaded 2 images and triggered training.',
);
```

**Location:**
- No fixture directory exists. Keep small fixtures inline in the relevant `test/*_test.dart` file.
- Add larger JSON/API fixtures under `test/fixtures/` only when multiple test files share them.
- Keep binary image/model fixtures minimal. Prefer generated temporary files for tests around `File` lists in `lib/roboflow_provider.dart`.

## Coverage

**Requirements:** None enforced. No coverage thresholds or CI coverage gates are configured.

**View Coverage:**
```bash
flutter test --coverage
# open or upload coverage/lcov.info with an LCOV viewer if needed
```

## Test Types

**Unit Tests:**
- Best current targets are pure or mostly pure logic: `RoboflowProvider` state transitions in `lib/roboflow_provider.dart`, result factories in `lib/roboflow_service.dart`, parsing behavior in `lib/roboflow_inference_service.dart`, and URI redaction/truncation behavior in `lib/api_logger.dart` if helper visibility is adjusted or tested through public logging.
- Service tests need dependency injection before they can avoid real HTTP, dotenv, and filesystem side effects.

**Integration Tests:**
- Not configured. Add Flutter integration tests only for device-level camera/gallery flows after unit/widget coverage exists.
- Backend integration tests can use Django test client for `backend/training/views.py`; mock Roboflow SDK calls and assert the request validation and scheduling response.

**E2E Tests:**
- Not used. Camera, gallery, Roboflow, ML Kit, and TFLite flows are currently verified manually on a camera-capable emulator/device.

## Common Patterns

**Async Testing:**
```typescript
test('uploadAndTrain ignores empty state', () async {
  final provider = RoboflowProvider();

  await provider.uploadAndTrain();

  expect(provider.isProcessing, isFalse);
  expect(provider.statusMessage, isNull);
});
```

**Error Testing:**
```typescript
test('failed inference result carries error message', () {
  final result = HostedInferenceResult.failed('Missing ROBOFLOW_API_KEY.');

  expect(result.success, isFalse);
  expect(result.label, 'Error');
  expect(result.confidence, 0);
  expect(result.error, contains('ROBOFLOW_API_KEY'));
});
```

---

*Testing analysis: 2026-05-27*
