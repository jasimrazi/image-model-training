import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:vision/api_logger.dart'; // Adjust if your path is different

class UploadTrainingResult {
  final bool success;
  final int uploaded;
  final int total;
  final String message;

  const UploadTrainingResult({
    required this.success,
    required this.uploaded,
    required this.total,
    required this.message,
  });

  factory UploadTrainingResult.ok(int total) {
    return UploadTrainingResult(
      success: true,
      uploaded: total,
      total: total,
      message:
          'Uploaded $total image${total == 1 ? '' : 's'} and triggered training.',
    );
  }

  factory UploadTrainingResult.failed({
    required int uploaded,
    required int total,
    required String message,
  }) {
    return UploadTrainingResult(
      success: false,
      uploaded: uploaded,
      total: total,
      message: message,
    );
  }
}

class RoboflowService {
  /// Keeps your existing single-image logic working perfectly without breaking your UI
  static Future<bool> uploadForTraining(File image, String label) async {
    final result = await uploadBatchForTraining([image], label);
    return result.success;
  }

  /// New batch method: Sends multiple images and metadata to the backend for labeling & training
  static Future<UploadTrainingResult> uploadBatchForTraining(
    List<File> images,
    String label,
  ) async {
    final dataset =
        dotenv.env['ROBOFLOW_PROJECT'] ?? dotenv.env['PROJECT'] ?? '';
    final workspace =
        dotenv.env['ROBOFLOW_WORKSPACE'] ?? dotenv.env['WORKSPACE'] ?? '';
    final triggerUrl = dotenv.env['BACKEND_TRIGGER_URL'] ?? '';

    if (images.isEmpty) {
      return UploadTrainingResult.failed(
        uploaded: 0,
        total: 0,
        message: 'Add at least one image before uploading.',
      );
    }

    if (triggerUrl.isEmpty) {
      return UploadTrainingResult.failed(
        uploaded: 0,
        total: images.length,
        message: 'Missing backend trigger URL. Set BACKEND_TRIGGER_URL.',
      );
    }

    if (dataset.isEmpty || workspace.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'Roboflow upload skipped: missing env values '
          'dataset=$dataset workspace=$workspace',
        );
      }
      return UploadTrainingResult.failed(
        uploaded: 0,
        total: images.length,
        message:
            'Missing Roboflow configuration. Set ROBOFLOW_WORKSPACE and ROBOFLOW_PROJECT.',
      );
    }

    final safeLabel = _safe(label);
    final uri = Uri.parse(triggerUrl);

    if (kDebugMode) {
      debugPrint('--- Sending batch of ${images.length} images to backend ---');
      debugPrint('Target class: $safeLabel');
    }

    try {
      ApiLogger.request('POST', uri, label: 'Backend trigger & upload');

      final request = http.MultipartRequest('POST', uri);
      final clientToken = dotenv.env['MCP_CLIENT_TOKEN'] ?? '';
      if (clientToken.isNotEmpty) {
        request.headers['X-MCP-Client-Token'] = clientToken;
      }

      // 1. Attach metadata required by Django backend
      request.fields['workspace_id'] = workspace;
      request.fields['project_id'] = dataset;
      request.fields['class_name'] = safeLabel;

      // 2. Attach all images under the 'images' key
      for (int i = 0; i < images.length; i++) {
        final image = images[i];
        final fileName = image.uri.pathSegments.isNotEmpty
            ? image.uri.pathSegments.last
            : '$safeLabel-$i.jpg';

        request.files.add(
          await http.MultipartFile.fromPath(
            'images',
            image.path,
            filename: fileName,
          ),
        );
      }

      // 3. Send request (timeout increased slightly to allow for multi-image upload)
      final streamed = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamed);

      ApiLogger.response(
        'POST',
        uri,
        response.statusCode,
        label: 'Backend trigger & upload',
        body: response.statusCode >= 300 ? response.body : null,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return UploadTrainingResult.ok(images.length);
      }

      if (kDebugMode) {
        debugPrint(
          'Backend upload failed: ${response.statusCode} ${response.body}',
        );
      }
      return UploadTrainingResult.failed(
        uploaded: 0, // Since it's a single batch request, it's all or nothing
        total: images.length,
        message: 'Backend upload failed (${response.statusCode}).',
      );
    } catch (e) {
      ApiLogger.error('POST', uri, e, label: 'Backend trigger & upload');
      if (kDebugMode) {
        debugPrint('Backend upload error: $e');
      }
      return UploadTrainingResult.failed(
        uploaded: 0,
        total: images.length,
        message: 'Network error during upload: $e',
      );
    }
  }

  static String _safe(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
  }
}
