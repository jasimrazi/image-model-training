import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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

  /// New batch method: Uploads multiple images and tags them all with the same label
  static Future<UploadTrainingResult> uploadBatchForTraining(
    List<File> images,
    String label,
  ) async {
    final apiKey = dotenv.env['ROBOFLOW_API_KEY'] ?? '';
    final dataset =
        dotenv.env['ROBOFLOW_PROJECT'] ?? dotenv.env['PROJECT'] ?? '';
    final workspace =
        dotenv.env['ROBOFLOW_WORKSPACE'] ?? dotenv.env['WORKSPACE'] ?? '';
    final batchName = dotenv.env['ROBOFLOW_BATCH_NAME'] ?? 'mobile-training';
    final triggerUrl = dotenv.env['BACKEND_TRIGGER_URL'] ?? '';

    if (images.isEmpty) {
      return UploadTrainingResult.failed(
        uploaded: 0,
        total: 0,
        message: 'Add at least one image before uploading.',
      );
    }

    if (apiKey.isEmpty || dataset.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'Roboflow upload skipped: missing env values '
          'dataset=$dataset apiKeySet=${apiKey.isNotEmpty}',
        );
      }
      return UploadTrainingResult.failed(
        uploaded: 0,
        total: images.length,
        message:
            'Missing Roboflow configuration. Set ROBOFLOW_API_KEY and ROBOFLOW_PROJECT.',
      );
    }

    if (triggerUrl.isEmpty) {
      return UploadTrainingResult.failed(
        uploaded: 0,
        total: images.length,
        message: 'Missing backend trigger URL. Set BACKEND_TRIGGER_URL.',
      );
    }

    if (workspace.isEmpty) {
      return UploadTrainingResult.failed(
        uploaded: 0,
        total: images.length,
        message: 'Missing Roboflow workspace. Set ROBOFLOW_WORKSPACE.',
      );
    }

    final safeLabel = _safe(label);
    var uploaded = 0;

    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      final fileName = image.uri.pathSegments.isNotEmpty
          ? image.uri.pathSegments.last
          : '$safeLabel-$i.jpg';

      final uri = Uri.https('api.roboflow.com', '/dataset/$dataset/upload', {
        'api_key': apiKey,
        'name': fileName,
        'split': 'train',
        'tag': safeLabel,
        'batch': batchName,
      });

      if (kDebugMode) {
        final redactedUri = uri.replace(
          queryParameters: {...uri.queryParameters, 'api_key': _redact(apiKey)},
        );
        debugPrint('--- Uploading image ${i + 1} of ${images.length} ---');
        debugPrint('Roboflow upload request: POST $redactedUri');
        debugPrint('Roboflow upload tag: $safeLabel');
      }

      try {
        final request = http.MultipartRequest('POST', uri)
          ..files.add(await http.MultipartFile.fromPath('file', image.path));
        final streamed = await request.send().timeout(
          const Duration(seconds: 45),
        );
        final response = await http.Response.fromStream(streamed);

        if (kDebugMode) {
          debugPrint('Roboflow upload status: ${response.statusCode}');
          // Only print the full body on failure to avoid console spam during successful batches
          if (response.statusCode >= 300) {
            debugPrint('Roboflow upload response: ${response.body}');
          }
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          return UploadTrainingResult.failed(
            uploaded: uploaded,
            total: images.length,
            message:
                'Roboflow upload failed for image ${i + 1} (${response.statusCode}).',
          );
        }
        uploaded++;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Roboflow upload error for image ${i + 1}: $e');
        }
        return UploadTrainingResult.failed(
          uploaded: uploaded,
          total: images.length,
          message: 'Roboflow upload failed for image ${i + 1}: $e',
        );
      }
    }

    final triggered = await _triggerTraining(
      triggerUrl: triggerUrl,
      workspace: workspace,
      project: dataset,
      className: safeLabel,
      imageCount: images.length,
    );

    if (!triggered.success) {
      return UploadTrainingResult.failed(
        uploaded: uploaded,
        total: images.length,
        message: triggered.message,
      );
    }

    return UploadTrainingResult.ok(images.length);
  }

  static Future<({bool success, String message})> _triggerTraining({
    required String triggerUrl,
    required String workspace,
    required String project,
    required String className,
    required int imageCount,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(triggerUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'workspace_id': workspace,
              'project_id': project,
              'class_name': className,
              'image_count': imageCount,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (success: true, message: 'Training trigger accepted.');
      }

      if (kDebugMode) {
        debugPrint(
          'Backend trigger failed: ${response.statusCode} ${response.body}',
        );
      }
      return (
        success: false,
        message: 'Backend trigger failed (${response.statusCode}).',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Backend trigger error: $e');
      }
      return (success: false, message: 'Backend trigger failed: $e');
    }
  }

  static String _safe(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
  }

  static String _redact(String value) {
    if (value.length <= 6) return '***';
    return '${value.substring(0, 3)}***${value.substring(value.length - 3)}';
  }
}
