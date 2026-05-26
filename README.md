# Vision

A Flutter-based mobile proof-of-concept for image scanning, local vision inference, and Roboflow-backed training upload.

## What this project does

- Provides a clean mobile UI for scanning objects from the camera or choosing images from the gallery.
- Sends selected images to a Roboflow inference endpoint and presents the top classification label, confidence, and raw response.
- Supports submission of scanned images to a backend training workflow, where images are tagged and forwarded to Roboflow for dataset update and model training.
- Bundles an on-device TensorFlow Lite + Google ML Kit vision pipeline for local label and text extraction support.

## Key features

- `Scan` tab
  - Capture a new photo or pick from gallery.
  - Display inferred product label and confidence.
  - View raw backend response metadata.
  - Submit items for training with a user-provided class/tag name.

- `Train` tab
  - Select a batch of images for upload.
  - Enter a class name/tag for the dataset.
  - Upload images and trigger the backend training flow.

- Local inference support
  - TensorFlow Lite model at `assets/model.tflite`
  - Label list at `assets/labels.txt`
  - Google ML Kit text recognition and image labeling support

## Project structure

- `lib/main.dart` — main app shell, scan UI, and navigation.
- `lib/cloud_vision_service.dart` — local TFLite + ML Kit image scanning logic.
- `lib/roboflow_service.dart` — upload client for backend training triggers.
- `lib/upload_screen.dart` — upload UI for training data batches.
- `lib/roboflow_provider.dart` — provider state management for training uploads.
- `backend/` — minimal Django backend to trigger Roboflow dataset and YOLOv8 training.

## Requirements

- Flutter SDK compatible with the repo's `pubspec.yaml`.
- An Android or iOS device/emulator with camera/gallery support for scanning flows.
- Backend environment variables for Roboflow and training trigger endpoint.

## Setup

1. Install Flutter dependencies:

```bash
flutter pub get
```

2. Create a `.env` file in the project root with your backend and Roboflow settings. Example:

```text
ROBOFLOW_PROJECT=your-project
ROBOFLOW_WORKSPACE=your-workspace
BACKEND_TRIGGER_URL=http://localhost:8000/api/trigger-training/
```

3. Run the app:

```bash
flutter run
```

4. (Optional) Start the backend server from `backend/`:

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python manage.py runserver
```

## Notes

- The app currently relies on an existing backend endpoint to process training image uploads and trigger Roboflow dataset training.
- The bundled TFLite model and label file are used for local inference, but the main product flow focuses on the Roboflow scanning/upload experience.
- Keep `assets/model.tflite` and `assets/labels.txt` in sync if you replace the model.

## License

This repository is provided as a reference demo. Adjust the README and licensing details as needed for your project.
