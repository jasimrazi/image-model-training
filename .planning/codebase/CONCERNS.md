# Codebase Concerns

**Analysis Date:** 2026-05-25

## Tech Debt

**Single oversized UI file:**
- Issue: `lib/main.dart` contains app shell, scanner flow, training flow, dialogs, styling constants, and shared widgets in one 2,004-line source file.
- Files: `lib/main.dart`
- Impact: Small UI changes risk unrelated scanner/training regressions, widget tests are hard to target, and feature ownership is unclear.
- Fix approach: Split by feature into `lib/scan/`, `lib/train/`, and `lib/widgets/`; keep `lib/main.dart` limited to bootstrapping, theme, and top-level navigation.

**Duplicate inference implementations:**
- Issue: `lib/classifier.dart` performs TFLite classification for the active UI while `lib/cloud_vision_service.dart` defines a separate TFLite + ML Kit/OCR service that is not imported by the current UI.
- Files: `lib/classifier.dart`, `lib/cloud_vision_service.dart`, `lib/main.dart`
- Impact: Model preprocessing, output-shape handling, error handling, and resource disposal can diverge; future model updates may fix one path while leaving the other broken.
- Fix approach: Consolidate inference behind one service interface. Move OCR/ML Kit behavior into the active service only if the UI uses it, then delete or quarantine unused code.

**Dynamic result maps at UI boundary:**
- Issue: `Classifier.classify()` returns `Map<String, dynamic>` and `ScanPage` casts keys such as `label`, `confidence`, `isRecognized`, and `all` directly.
- Files: `lib/classifier.dart`, `lib/main.dart`
- Impact: Typos or type changes surface as runtime failures instead of analyzer errors.
- Fix approach: Replace the map with a typed immutable result class, for example `ClassificationResult`, and update `_ScanCard` in `lib/main.dart` to consume fields.

**Environment variable naming drift:**
- Issue: `lib/model_updater.dart` reads `WORKSPACE` and `PROJECT`, while the environment example uses Roboflow-prefixed names; `lib/roboflow_service.dart` reads only `PROJECT` for upload.
- Files: `lib/model_updater.dart`, `lib/roboflow_service.dart`, `.env.example`
- Impact: A developer can configure documented variables and still silently fall back to bundled models or fail uploads.
- Fix approach: Centralize config parsing in a `lib/config.dart` helper that accepts one canonical variable set and validates required values at startup.

**Release packaging still uses template identity and debug signing:**
- Issue: Android keeps the template package name and debug release signing configuration.
- Files: `android/app/build.gradle.kts`
- Impact: Release builds are not production-distributable and can collide with other template apps using `com.example.vision`.
- Fix approach: Set a real `applicationId`, configure release signing through secure Gradle properties, and keep signing secrets out of source control.

## Known Bugs

**Train/valid/test split calculation is ignored:**
- Symptoms: `_TrainPageState._upload()` calculates `final split = _splitFor(i, _images.length)` but `RoboflowService.uploadForTraining()` always sends `split=train`.
- Files: `lib/main.dart`, `lib/roboflow_service.dart`
- Trigger: Upload a training batch from the Train tab; all images are submitted to the train split.
- Workaround: Manually split images in Roboflow after upload.

**Individual tag mode is unreachable:**
- Symptoms: `_TagMode.individual` exists but no UI changes `_tagMode` away from `_TagMode.same`; analyzer reports the enum value as unused.
- Files: `lib/main.dart`
- Trigger: Use the Train tab and attempt to label images individually; no control exposes the mode.
- Workaround: Upload separate batches per class label.

**Invalid or unsupported image files can crash classification:**
- Symptoms: `img.decodeImage(bytes)!` force-unwraps a nullable decode result.
- Files: `lib/classifier.dart`
- Trigger: Select a corrupt, unsupported, or unreadable image from camera/gallery.
- Workaround: Avoid unsupported image formats; add a null check before running inference.

**Model output length assumes bundled label count:**
- Symptoms: `Classifier.classify()` allocates output using `_labels.length` even when a downloaded custom model has a different output tensor size.
- Files: `lib/classifier.dart`, `lib/model_updater.dart`, `assets/labels.txt`
- Trigger: Download a custom model from `ModelUpdater.checkAndUpdate()` whose class count differs from `assets/labels.txt`.
- Workaround: Keep downloaded model outputs aligned exactly with bundled `assets/labels.txt`.

## Security Considerations

**Secrets are bundled into app assets:**
- Risk: `pubspec.yaml` declares `.env` as a Flutter asset, and `lib/main.dart` loads it with `dotenv.load(fileName: '.env')`; Roboflow API keys in a bundled mobile asset can be extracted from the app package.
- Files: `pubspec.yaml`, `lib/main.dart`, `.env`
- Current mitigation: `.gitignore` ignores `.env`; `RoboflowService` redacts the API key in debug request logs.
- Recommendations: Move Roboflow training/upload operations behind a backend service, issue scoped short-lived tokens, and remove `.env` from bundled Flutter assets.

**API keys are sent in query strings:**
- Risk: Roboflow URLs include `api_key` as a query parameter, which can appear in proxies, crash reports, platform logs, or analytics.
- Files: `lib/roboflow_service.dart`, `lib/model_updater.dart`
- Current mitigation: Debug logging in `lib/roboflow_service.dart` redacts the key before printing upload URLs.
- Recommendations: Avoid client-side Roboflow API keys; if direct calls remain, keep all authenticated URLs out of logs and prefer a server-side proxy.

**Downloaded models are not integrity-checked:**
- Risk: `ModelUpdater.checkAndUpdate()` writes downloaded bytes to app storage and `Classifier.loadModel()` loads them without checksum, signature, size, or schema validation.
- Files: `lib/model_updater.dart`, `lib/classifier.dart`
- Current mitigation: HTTPS is used for Roboflow URLs generated with `Uri.https`; direct `MODEL_DOWNLOAD_URL` is accepted as configured.
- Recommendations: Require HTTPS, pin an expected hash/version manifest, validate tensor shapes before saving, and keep the previous known-good model until validation passes.

**iOS/macOS permission usage descriptions are missing:**
- Risk: Camera/gallery access requires platform usage description keys; missing iOS keys can cause runtime denial or App Store rejection.
- Files: `ios/Runner/Info.plist`, `macos/Runner/Info.plist`, `lib/main.dart`
- Current mitigation: Android declares `android.permission.CAMERA` and `android.permission.READ_EXTERNAL_STORAGE` in `android/app/src/main/AndroidManifest.xml`.
- Recommendations: Add `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, and any platform-specific keys required by `image_picker` before shipping camera/gallery flows.

## Performance Bottlenecks

**Synchronous image reads in inference path:**
- Problem: `CloudVisionService.scanFile()` calls `imageFile.readAsBytesSync()` on the calling isolate.
- Files: `lib/cloud_vision_service.dart`
- Cause: File IO and decode work run synchronously before resizing and inference.
- Improvement path: Use `await imageFile.readAsBytes()` and move decode/resize/inference preprocessing to an isolate for large images.

**Nested Dart lists for tensor creation:**
- Problem: Both TFLite paths build deeply nested `List.generate` structures for every 224x224 image.
- Files: `lib/classifier.dart`, `lib/cloud_vision_service.dart`
- Cause: Per-pixel Dart object allocation is expensive and adds GC pressure.
- Improvement path: Use typed buffers such as `Float32List`/`Uint8List` shaped for `tflite_flutter`, reuse buffers where safe, and benchmark on real devices.

**Sequential network uploads without timeouts:**
- Problem: Training images upload one at a time, and HTTP calls do not set request timeouts.
- Files: `lib/main.dart`, `lib/roboflow_service.dart`, `lib/model_updater.dart`
- Cause: `_TrainPageState._upload()` awaits each upload serially; `http.get()` and `http.post()` use default behavior without timeout/retry/backoff.
- Improvement path: Add `timeout()` around all network calls, retry transient 5xx/429 failures with backoff, and consider bounded concurrency for batch uploads.

## Fragile Areas

**Model/label compatibility:**
- Files: `lib/classifier.dart`, `lib/model_updater.dart`, `assets/model.tflite`, `assets/labels.txt`
- Why fragile: Bundled labels are always used even for downloaded custom models, and the active classifier does not inspect output tensor shape before allocating output.
- Safe modification: Any model change must update labels together and include a startup validation that compares model output length to label count.
- Test coverage: No `test/` directory exists; no automated test validates tensor shape, label alignment, or custom model fallback.

**Async UI state after plugin/network calls:**
- Files: `lib/main.dart`
- Why fragile: Camera/gallery selection, classification, dialogs, and uploads all mutate widget state after awaits; some paths use `mounted`, but `_process()` and `_upload()` include `setState()` calls after awaited work without comprehensive disposal guards.
- Safe modification: Guard every post-await `setState()`/dialog operation with `if (!mounted) return;` and prevent overlapping scans/uploads while a previous operation is in flight.
- Test coverage: No widget tests exercise navigation away during scanning or upload.

**Roboflow API behavior is hard-coded in client code:**
- Files: `lib/roboflow_service.dart`, `lib/main.dart`
- Why fragile: Upload endpoint, query parameters, default batch name, and split handling are embedded in mobile code.
- Safe modification: Wrap Roboflow calls in a service that accepts an injectable HTTP client and explicit request objects; keep API-specific constants in one config file.
- Test coverage: No tests cover missing config, non-2xx responses, malformed labels, large batches, or partial upload failures.

## Scaling Limits

**Local training image list:**
- Current capacity: The UI recommends 50+ images and stores every selected image path in `_images`.
- Limit: Large batches increase memory pressure during thumbnail rendering and make uploads slow because they are sequential.
- Scaling path: Paginate thumbnails, cap batch size per upload, compress/resize before upload, and resume failed batches by persisting an upload queue.

**Client-side model updates:**
- Current capacity: One cached `custom_model.tflite` and one integer `saved_model_version` in app documents/preferences.
- Limit: No rollback metadata, no multiple model channels, and no validation before replacing the local model.
- Scaling path: Store model metadata alongside file hashes, keep current and previous models, and atomically promote validated downloads.

## Dependencies at Risk

**Unused or partially used ML/camera packages:**
- Risk: `camera`, `google_mlkit_image_labeling`, `google_mlkit_text_recognition`, and `google_mlkit_object_detection` are declared, but the active UI uses `image_picker` plus `Classifier` rather than `camera` APIs or `CloudVisionService`.
- Impact: App size, native permissions, and platform integration complexity increase without active feature value.
- Migration plan: Remove unused dependencies after confirming feature scope, or wire `CloudVisionService` into the UI and test ML Kit behavior on Android/iOS.

**Platform storage permissions:**
- Risk: Android declares legacy `READ_EXTERNAL_STORAGE` but no newer media permissions were detected.
- Impact: Gallery access can behave differently on newer Android versions depending on `image_picker` behavior and target SDK.
- Migration plan: Verify `image_picker` permission requirements for the resolved version and target SDK, then update `android/app/src/main/AndroidManifest.xml` with only required modern permissions.

## Missing Critical Features

**Automated tests:**
- Problem: `flutter test` reports `Test directory "test" not found.`
- Blocks: Safe refactoring of `lib/main.dart`, model update logic, Roboflow upload behavior, and classifier edge cases.

**Operational observability:**
- Problem: Failures are mostly `print`, `debugPrint`, boolean returns, or brief `SnackBar` messages.
- Blocks: Diagnosing model download failures, upload failures, and inference failures on user devices.

**Robust release configuration:**
- Problem: Android release signing and application identity are still template defaults.
- Blocks: Store distribution and production crash/security review.

## Test Coverage Gaps

**Classifier edge cases:**
- What's not tested: Corrupt images, custom model output shape mismatch, label count mismatch, threshold behavior, and TFLite interpreter failure.
- Files: `lib/classifier.dart`, `assets/model.tflite`, `assets/labels.txt`
- Risk: Users can see crashes or incorrect labels after model changes.
- Priority: High

**Model updater network and fallback behavior:**
- What's not tested: Missing env config, non-2xx downloads, invalid version bodies, cached model fallback, file write failures, and downloaded model validation.
- Files: `lib/model_updater.dart`
- Risk: App startup can silently use stale or invalid models.
- Priority: High

**Roboflow upload behavior:**
- What's not tested: API key absence, label sanitization, split assignment, partial failures, response parsing, timeouts, and retry behavior.
- Files: `lib/roboflow_service.dart`, `lib/main.dart`
- Risk: Training data can be uploaded to the wrong split or fail without actionable user feedback.
- Priority: High

**Scanner and training widget flows:**
- What's not tested: Camera/gallery cancellation, multiple selected images, unknown-product dialog, submit-for-training flow, navigation during async work, and disabled button states.
- Files: `lib/main.dart`
- Risk: Common user flows can regress during UI refactors.
- Priority: Medium

---

*Concerns audit: 2026-05-25*
