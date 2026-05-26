# Technology Stack

**Analysis Date:** 2026-05-25

## Languages

**Primary:**
- Dart `>=3.11.4 <4.0.0` - Flutter application code in `lib/main.dart`, `lib/classifier.dart`, `lib/model_updater.dart`, `lib/roboflow_service.dart`, and `lib/cloud_vision_service.dart`; SDK constraint is declared in `pubspec.yaml` and resolved in `pubspec.lock`.

**Secondary:**
- Kotlin / Java 17 - Android host project and plugin registration under `android/`; Java/Kotlin target 17 is configured in `android/app/build.gradle.kts`.
- Swift - iOS/macOS host project files under `ios/Runner/` and `macos/Runner/`.
- C++ / CMake - Linux and Windows Flutter host projects under `linux/` and `windows/`.

## Runtime

**Environment:**
- Flutter `>=3.38.4` - Resolved SDK requirement in `pubspec.lock`; root package is a single Flutter app configured by `pubspec.yaml`.
- Dart SDK `>=3.11.4 <4.0.0` - Declared in `pubspec.yaml` and `pubspec.lock`.
- Android Gradle Plugin `8.11.1` and Kotlin Android plugin `2.2.20` - Declared in `android/settings.gradle.kts`.
- Gradle `8.14` - Wrapper distribution in `android/gradle/wrapper/gradle-wrapper.properties`.

**Package Manager:**
- Dart Pub / Flutter Pub - Dependencies are declared in `pubspec.yaml`.
- Lockfile: present at `pubspec.lock`; use it as the resolved-version source.

## Frameworks

**Core:**
- Flutter SDK - Material app UI, navigation, assets, platform plugins, and mobile runtime; app entrypoint is `lib/main.dart`.
- Material 3 - `ThemeData(useMaterial3: true)` and `MaterialApp` are configured in `lib/main.dart`.

**Testing:**
- `flutter_test` SDK package - Declared in `pubspec.yaml` for widget/unit tests.
- `flutter_lints` `6.0.0` - Dev lint set declared in `pubspec.yaml`; enabled through `analysis_options.yaml`.

**Build/Dev:**
- Flutter Gradle plugin - Applied in `android/app/build.gradle.kts`.
- AndroidX - Enabled in `android/gradle.properties`.
- Android TFLite asset packaging - `androidResources.noCompress += "tflite"` in `android/app/build.gradle.kts`; preserve this for loadable TFLite assets.

## Key Dependencies

**Critical:**
- `tflite_flutter` `0.11.0` - Local TensorFlow Lite inference in `lib/classifier.dart` and `lib/cloud_vision_service.dart`.
- `image` `4.8.0` - Image decoding, resizing, and pixel normalization before inference in `lib/classifier.dart` and `lib/cloud_vision_service.dart`.
- `image_picker` `1.2.2` - Camera and gallery image acquisition in `lib/main.dart`.
- `http` `1.6.0` - Roboflow API calls and model downloads in `lib/roboflow_service.dart` and `lib/model_updater.dart`.
- `flutter_dotenv` `6.0.1` - Loads `.env` in `lib/main.dart` and reads Roboflow/model configuration in `lib/roboflow_service.dart` and `lib/model_updater.dart`.

**Infrastructure:**
- `path_provider` `2.1.5` - Locates application documents storage for downloaded model files in `lib/model_updater.dart`.
- `shared_preferences` `2.5.5` - Stores model version metadata in `lib/model_updater.dart`.
- `google_mlkit_text_recognition` `0.13.1` - Optional OCR path in `lib/cloud_vision_service.dart`.
- `google_mlkit_image_labeling` `0.12.1` - Optional ML Kit image labeler in `lib/cloud_vision_service.dart`.
- `google_mlkit_object_detection` `0.13.1` - Declared in `pubspec.yaml` and preloaded on Android via `android/app/src/main/AndroidManifest.xml`; no direct Dart import detected.
- `camera` `0.11.4` - Declared in `pubspec.yaml`; current UI uses `image_picker` in `lib/main.dart` rather than `camera` APIs.

## Configuration

**Environment:**
- `.env` file present - contains runtime environment configuration and is bundled as a Flutter asset by `pubspec.yaml`; do not read or commit secret values.
- `.env.example` file present - environment template exists, but contents are not read because `.env*` files are treated as secret-bearing.
- `lib/main.dart` calls `dotenv.load(fileName: '.env')` before `runApp`, so environment variables must be available as the bundled `.env` asset.
- Roboflow variables read by code: `ROBOFLOW_API_KEY`, `ROBOFLOW_WORKSPACE`, `WORKSPACE`, `ROBOFLOW_PROJECT`, `PROJECT`, `ROBOFLOW_BATCH_NAME`, `ROBOFLOW_TRAIN_VERSION`, `MODEL_VERSION`, and `ROBOFLOW_MODEL_TYPE` in `lib/roboflow_service.dart`.
- Model-update variables read by code: `MODEL_VERSION`, `MODEL_VERSION_URL`, `MODEL_DOWNLOAD_URL`, `ROBOFLOW_API_KEY`, `ROBOFLOW_WORKSPACE`, `WORKSPACE`, `ROBOFLOW_PROJECT`, and `PROJECT` in `lib/model_updater.dart`.

**Build:**
- `pubspec.yaml` declares app metadata, SDK constraints, dependencies, Material usage, and assets.
- `pubspec.lock` pins resolved package versions.
- `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`.
- `android/app/build.gradle.kts` configures Android namespace, SDK values from Flutter, Java/Kotlin 17, release signing, and TFLite no-compress behavior.
- `android/settings.gradle.kts` configures Flutter plugin loading, AGP, Kotlin plugin, and repositories.
- `android/app/src/main/AndroidManifest.xml` declares `CAMERA`, `INTERNET`, `READ_EXTERNAL_STORAGE`, Flutter embedding, and Google ML Kit dependency preloading.
- `ios/Runner/Info.plist` and `macos/Runner/Info.plist` contain platform bundle metadata; iOS camera/photo usage description keys are not detected in `ios/Runner/Info.plist`.

## Platform Requirements

**Development:**
- Run `flutter pub get` after editing `pubspec.yaml` or asset declarations.
- Run `flutter analyze` for static verification; lints are sourced from `analysis_options.yaml`.
- Use `flutter test` when tests exist; test dependency is declared in `pubspec.yaml`.
- Use a real camera-capable device/emulator to verify `ImageSource.camera` and gallery flows in `lib/main.dart`.
- Android builds require Java 17-compatible tooling because `android/app/build.gradle.kts` sets Java/Kotlin target 17.

**Production:**
- Android package id is currently `com.example.vision` in `android/app/build.gradle.kts`.
- Android release uses debug signing config in `android/app/build.gradle.kts`; configure production signing before release.
- Bundled model assets are `assets/model.tflite` and `assets/labels.txt` in `pubspec.yaml`; `lib/classifier.dart` and `lib/cloud_vision_service.dart` depend on these paths.
- Downloaded model files are stored in application documents storage by `lib/model_updater.dart` and selected ahead of the bundled asset when available.
- Roboflow training and model export require network access; Android declares `INTERNET` in `android/app/src/main/AndroidManifest.xml`.

---

*Stack analysis: 2026-05-25*
