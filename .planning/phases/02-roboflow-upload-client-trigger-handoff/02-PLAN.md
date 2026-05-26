# Phase 2 Plan: Roboflow Upload Client & Trigger Handoff

## Goal

Selected images upload directly to Roboflow and backend training is triggered only after all uploads succeed.

## Requirements

- ROBO-01
- ROBO-02
- ROBO-03
- BACK-01

## Tasks

1. Add a typed upload result model to `lib/roboflow_service.dart`.
2. Implement multipart upload for `List<File>` using Roboflow query parameters `api_key`, `name`, `split=train`, and `tag`.
3. Add backend trigger POST using a configurable `BACKEND_TRIGGER_URL`.
4. Wire `RoboflowProvider.uploadAndTrain()` to the service and expose status/error text.
5. Update `UploadScreen` to show provider status after success/failure.
6. Update `.env.example` with backend trigger URL placeholder.
7. Run `dart format` and `flutter analyze`.

## Verification

- Upload fails clearly when required config is missing.
- Backend trigger is not called when upload fails.
- `flutter analyze` has no new warnings from Phase 2 files.
