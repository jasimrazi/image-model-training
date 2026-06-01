    # Vision

## What This Is

Vision is a Flutter mobile app for image-based product/object recognition with local model inference and Roboflow-powered model improvement. The current milestone extends the app into a full training feedback loop: users contribute labeled images, then a backend generates and trains a new YOLOv8 model asynchronously.

## Core Value

Users can improve recognition quality by contributing labeled images and triggering a reliable training pipeline without exposing service secrets in the mobile app.

## Current Milestone: v0.1 Roboflow Automated Training Pipeline

**Goal:** Users can select multiple images in Flutter, upload them to a Roboflow class, and trigger a Django backend to generate a new dataset version and start YOLOv8 training asynchronously.

**Target features:**
- Flutter multi-image upload screen with class/tag input and Provider-backed processing state.
- Direct Flutter multipart upload of raw image bytes to Roboflow with dataset, split, name, and tag parameters.
- Django endpoint that accepts a training trigger payload and keeps the Roboflow API key server-side.
- Background Roboflow dataset version generation with basic preprocessing and asynchronous YOLOv8 training.
- Dependency and environment documentation for Flutter and Django implementation.

## Requirements

### Validated

- ✓ Flutter app can acquire images from camera/gallery for recognition workflows — inferred from existing implementation.
- ✓ App can run local TFLite inference against bundled model assets — inferred from existing implementation.
- ✓ Existing code has Roboflow HTTP integration concepts for upload, training, export, and model update flows — inferred from existing implementation.
- ✓ User can prepare labeled training batches in Flutter with Provider-backed processing state — v0.1.
- ✓ App can upload selected images directly to Roboflow and trigger backend training only after upload success — v0.1.
- ✓ Django backend can accept training triggers and schedule Roboflow versioning/training asynchronously — v0.1.

### Active

(None — milestone v0.1 complete.)

### Out of Scope

- Full production job queue infrastructure — this milestone explicitly uses Python threading for asynchronous backend work.
- Real-time training progress polling — the requested flow only requires immediate trigger acknowledgment.
- User authentication and per-user training history — no auth system exists in the current app.
- Automatic mobile model download after training — existing model update work exists, but this milestone focuses on upload and train trigger generation.

## Context

- Single-package Flutter app with root `pubspec.yaml` as the source of truth.
- Main app UI currently lives largely in `lib/main.dart`; existing codebase concerns recommend splitting new training UI into focused files instead of growing `main.dart` further.
- Existing Flutter dependencies include `image_picker`, `http`, `flutter_dotenv`, `tflite_flutter`, and model storage helpers.
- Existing code has Roboflow-related client logic, but bundling `.env` into Flutter assets exposes secrets; this milestone moves training key ownership to Django.
- The requested backend is new to this repository; no Django project files are currently present.

## Constraints

- **Security:** Roboflow API key must be stored in the Django backend `.env`, not passed from Flutter.
- **Frontend state:** Flutter upload/training processing state must use `ChangeNotifier` with Provider.
- **Roboflow upload path:** Flutter must upload image bytes directly to `https://api.roboflow.com/dataset/{dataset}/upload` using multipart/form-data.
- **Backend async behavior:** Django trigger endpoint must return immediately while version generation and training run in a background thread.
- **Training target:** Backend training uses YOLOv8 with `epochs=50`.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Direct mobile uploads to Roboflow | Saves backend bandwidth for raw image payloads | — Pending |
| Backend-held Roboflow API key | Prevents exposing long-lived service secrets in the mobile app | — Pending |
| Python threading for training trigger | Matches requested implementation and keeps HTTP response immediate | — Pending |
| Split new Flutter upload feature into dedicated files | Avoids further expanding the large existing `lib/main.dart` | — Pending |
| Django backend under `backend/` | Keeps the training trigger implementation runnable in this repo | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check - still the right priority?
3. Audit Out of Scope - reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-26 after completing milestone v0.1*
