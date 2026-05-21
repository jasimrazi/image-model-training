import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class RoboflowService {
  static Future<bool> uploadForTraining(File image, String label) async {
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

    final fileName = image.uri.pathSegments.isNotEmpty
        ? image.uri.pathSegments.last
        : '$label.jpg';

    final uri = Uri.https(
      'api.roboflow.com',
      '/dataset/$project/upload',
      {
        'api_key': apiKey,
        'name': fileName,
        'batch': batchName,
        'split': 'train',
        'tag': label,
      },
    );

    if (kDebugMode) {
      final redactedUri = uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          'api_key': _redact(apiKey),
        },
      );
      debugPrint('Roboflow upload request: POST $redactedUri');
      debugPrint('Roboflow upload label: $label');
      debugPrint('Roboflow upload batch: $batchName');
      debugPrint('Roboflow upload file: ${image.path}');
    }

    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: base64Encode(await image.readAsBytes()),
    );

    if (kDebugMode) {
      debugPrint('Roboflow upload status: ${response.statusCode}');
      debugPrint('Roboflow upload response: ${response.body}');
    }

    return response.statusCode >= 200 && response.statusCode < 300;
  }

  static String _redact(String value) {
    if (value.length <= 6) return '***';
    return '${value.substring(0, 3)}***${value.substring(value.length - 3)}';
  }
}
