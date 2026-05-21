import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class RoboflowService {
  /// Keeps your existing single-image logic working perfectly without breaking your UI
  static Future<bool> uploadForTraining(File image, String label) async {
    return uploadBatchForTraining([image], label);
  }

  /// New batch method: Uploads multiple images and tags them all with the same label
  static Future<bool> uploadBatchForTraining(
    List<File> images,
    String label,
  ) async {
    final apiKey = dotenv.env['ROBOFLOW_API_KEY'] ?? '';
    final project = dotenv.env['PROJECT'] ?? '';
    final batchName = dotenv.env['ROBOFLOW_BATCH_NAME'] ?? 'mobile-training';

    if (apiKey.isEmpty || project.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'Roboflow upload skipped: missing env values '
          'project=$project apiKeySet=${apiKey.isNotEmpty}',
        );
      }
      return false;
    }

    // Format the label to be safe for URLs/Tags (e.g. "Pepsi 500ml" -> "pepsi-500ml")
    final safeLabel = label.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '-',
    );
    bool allSuccess = true;

    for (int i = 0; i < images.length; i++) {
      final image = images[i];

      // Ensure each file has a unique name if it doesn't already have one
      final fileName = image.uri.pathSegments.isNotEmpty
          ? image.uri.pathSegments.last
          : '$safeLabel-$i.jpg';

      final uri = Uri.https('api.roboflow.com', '/dataset/$project/upload', {
        'api_key': apiKey,
        'name': fileName,
        'batch': batchName,
        'split': 'train',
        'tag': safeLabel, // Attach the label here as a tag
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
        final response = await http.post(
          uri,
          headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
          body: base64Encode(await image.readAsBytes()),
        );

        if (kDebugMode) {
          debugPrint('Roboflow upload status: ${response.statusCode}');
          // Only print the full body on failure to avoid console spam during successful batches
          if (response.statusCode >= 300) {
            debugPrint('Roboflow upload response: ${response.body}');
          }
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          allSuccess = false;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Roboflow upload error for image ${i + 1}: $e');
        }
        allSuccess = false;
      }
    }

    return allSuccess;
  }

  static String _redact(String value) {
    if (value.length <= 6) return '***';
    return '${value.substring(0, 3)}***${value.substring(value.length - 3)}';
  }
}
