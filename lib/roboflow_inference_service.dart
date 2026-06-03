import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:vision/api_logger.dart';

class HostedInferenceResult {
  final bool success;
  final String label;
  final double confidence;
  final String rawResponse;
  final String? error;

  const HostedInferenceResult({
    required this.success,
    required this.label,
    required this.confidence,
    required this.rawResponse,
    this.error,
  });

  factory HostedInferenceResult.failed(String message) {
    return HostedInferenceResult(
      success: false,
      label: 'Error',
      confidence: 0,
      rawResponse: message,
      error: message,
    );
  }
}

class RoboflowInferenceService {
  static Future<HostedInferenceResult> scan(File image) async {
    final project =
        dotenv.env['ROBOFLOW_PROJECT'] ?? dotenv.env['PROJECT'] ?? '';
    final configuredVersion = dotenv.env['ROBOFLOW_INFER_VERSION'] ?? '';

    final uri = _backendInferenceUri();
    if (uri == null) {
      return HostedInferenceResult.failed(
        'Missing backend inference URL. Set BACKEND_INFERENCE_URL or BACKEND_BASE_URL.',
      );
    }

    try {
      ApiLogger.request('POST', uri, label: 'Backend inference');

      final request = http.MultipartRequest('POST', uri);
      if (project.isNotEmpty) {
        request.fields['project_id'] = project;
      }
      if (configuredVersion.isNotEmpty) {
        request.fields['version'] = configuredVersion;
      }

      final fileName = image.uri.pathSegments.isNotEmpty
          ? image.uri.pathSegments.last
          : 'image.jpg';
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          image.path,
          filename: fileName,
        ),
      );

      final streamed = await request.send().timeout(
        const Duration(seconds: 45),
      );
      final response = await http.Response.fromStream(streamed);

      ApiLogger.response(
        'POST',
        uri,
        response.statusCode,
        label: 'Backend inference',
        body: response.body,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return HostedInferenceResult.failed(
          'Backend inference failed (${response.statusCode}): ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      final parsed = _parsePrediction(decoded);
      return HostedInferenceResult(
        success: true,
        label: parsed.label,
        confidence: parsed.confidence,
        rawResponse: const JsonEncoder.withIndent('  ').convert(decoded),
      );
    } catch (e) {
      ApiLogger.error('POST', uri, e, label: 'Backend inference');
      if (kDebugMode) {
        debugPrint('Backend inference error: $e');
      }
      return HostedInferenceResult.failed('Backend inference failed: $e');
    }
  }

  static Uri? _backendInferenceUri() {
    final explicitUrl = dotenv.env['BACKEND_INFERENCE_URL']?.trim() ?? '';
    if (explicitUrl.isNotEmpty) {
      return Uri.tryParse(explicitUrl);
    }

    final triggerUrl = dotenv.env['BACKEND_TRIGGER_URL']?.trim() ?? '';
    if (triggerUrl.isNotEmpty) {
      final inferred = triggerUrl
          .replaceFirst(RegExp(r'/trigger-training/?$'), '/infer/')
          .replaceFirst(RegExp(r'trigger-training/?$'), 'infer/');
      return Uri.tryParse(inferred);
    }

    final baseUrl = dotenv.env['BACKEND_BASE_URL']?.trim() ?? '';
    if (baseUrl.isEmpty) return null;
    return Uri.tryParse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}/api/infer/');
  }

  static ({String label, double confidence}) _parsePrediction(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final top = decoded['top'];
      final confidence = decoded['confidence'];
      if (top is String) {
        return (label: top, confidence: _asDouble(confidence));
      }

      final predictions = decoded['predictions'];
      if (predictions is List && predictions.isNotEmpty) {
        final first = predictions.first;
        if (first is Map<String, dynamic>) {
          return (
            label: (first['class'] ?? first['label'] ?? 'Prediction')
                .toString(),
            confidence: _asDouble(first['confidence']),
          );
        }
      }
    }

    return (label: 'Response received', confidence: 0);
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
