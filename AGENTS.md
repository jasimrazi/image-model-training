# AGENTS.md

## Project Shape
- Single-package Flutter app; root `pubspec.yaml` is the source of truth. There is no monorepo/task runner/CI config in this repo.
- Main app entrypoint is `lib/main.dart`; the scanner UI, camera lifecycle, gallery picker, and result screen are all currently in this file.
- Local inference/OCR logic is in `lib/cloud_vision_service.dart` via `tflite_flutter` plus `google_mlkit_text_recognition`.

## Commands
- Install deps after dependency or asset changes: `flutter pub get`.
- Primary verification: `flutter analyze`.
- Run tests with `flutter test`; there are currently no `test/**/*.dart` files, so add focused tests before relying on this for behavior coverage.
- Run a focused test file when tests exist: `flutter test test/<file>_test.dart`.
- Run locally with an attached device/emulator: `flutter run -d <deviceId>`; camera flows need a real camera-capable target to verify end to end.

## Assets And Model Wiring
- `pubspec.yaml` explicitly bundles `assets/model.tflite` and `assets/labels.txt`; keep these paths stable unless updating `CloudVisionService.initialize()` too.
- Android has `androidResources.noCompress += "tflite"` in `android/app/build.gradle.kts`; preserve this when touching Android packaging so the TFLite model remains loadable.
- `assets/labels.txt` contains 1000 ImageNet labels and is aligned against the model output length at runtime; changing the model usually requires validating labels and output shape together.

## Platform Gotchas
- Android ML Kit model preloading is declared in `android/app/src/main/AndroidManifest.xml` with `com.google.mlkit.vision.DEPENDENCIES=ocr,label,object_detection`; do not remove it casually.
- Android Gradle config uses Kotlin DSL and Java/Kotlin 17 (`android/app/build.gradle.kts`).
- iOS `Runner/Info.plist` and Android `AndroidManifest.xml` currently do not declare camera/photo usage permissions beyond the default Flutter template; verify platform permission requirements when changing camera or gallery behavior.

## Code Conventions In This Repo
- `main()` calls `availableCameras()` before `runApp`; camera-dependent changes should preserve initialization before `ScannerScreen` uses `_cameras`.
- `ScannerScreen` owns camera disposal across lifecycle changes; avoid introducing async camera operations that skip `mounted`/`_isDisposed` checks already used in `lib/main.dart`.
- `CloudVisionService.dispose()` closes both the TFLite interpreter and ML Kit recognizer; keep ownership of these resources inside the service.
