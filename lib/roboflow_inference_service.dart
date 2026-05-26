import 'dart:convert';
import 'dart:io';

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
    final apiKey = dotenv.env['ROBOFLOW_API_KEY'] ?? '';
    final project =
        dotenv.env['ROBOFLOW_PROJECT'] ?? dotenv.env['PROJECT'] ?? '';
    final configuredVersion = dotenv.env['ROBOFLOW_INFER_VERSION'] ?? 'latest';

    if (apiKey.isEmpty) {
      return HostedInferenceResult.failed('Missing ROBOFLOW_API_KEY.');
    }
    if (project.isEmpty) {
      return HostedInferenceResult.failed('Missing ROBOFLOW_PROJECT.');
    }

    final uri = await _inferenceUri(
      apiKey: apiKey,
      project: project,
      configuredVersion: configuredVersion,
    );

    try {
      final body = base64Encode(await image.readAsBytes());
      ApiLogger.request('POST', uri, label: 'Roboflow inference');
      final response = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));
      ApiLogger.response(
        'POST',
        uri,
        response.statusCode,
        label: 'Roboflow inference',
        body: response.body,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return HostedInferenceResult.failed(
          'Roboflow inference failed (${response.statusCode}): ${response.body}',
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
      ApiLogger.error('POST', uri, e, label: 'Roboflow inference');
      return HostedInferenceResult.failed('Roboflow inference failed: $e');
    }
  }

  static Future<Uri> _inferenceUri({
    required String apiKey,
    required String project,
    required String configuredVersion,
  }) async {
    final version =
        configuredVersion.trim().toLowerCase() == 'latest' ||
            configuredVersion.trim().isEmpty
        ? await _latestVersion(apiKey: apiKey, project: project)
        : configuredVersion.trim();

    return Uri.https('classify.roboflow.com', '/$project/$version', {
      'api_key': apiKey,
    });
  }

  static Future<String> _latestVersion({
    required String apiKey,
    required String project,
  }) async {
    final workspace =
        dotenv.env['ROBOFLOW_WORKSPACE'] ?? dotenv.env['WORKSPACE'] ?? '';
    if (workspace.isEmpty) {
      throw StateError('Missing ROBOFLOW_WORKSPACE for latest version lookup.');
    }

    final uri = Uri.https('api.roboflow.com', '/$workspace/$project', {
      'api_key': apiKey,
    });
    ApiLogger.request('GET', uri, label: 'Roboflow latest version');
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    ApiLogger.response(
      'GET',
      uri,
      response.statusCode,
      label: 'Roboflow latest version',
      body: response.statusCode >= 300 ? response.body : null,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Latest version lookup failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    Object? versions;
    if (decoded is Map<String, dynamic>) {
      versions = decoded['versions'];
      final projectData = decoded['project'];
      if (versions == null && projectData is Map<String, dynamic>) {
        versions = projectData['versions'];
      }
    }
    if (versions is List && versions.isNotEmpty) {
      final numbers =
          versions
              .where(_hasTrainedModel)
              .map(_versionNumber)
              .whereType<int>()
              .toList()
            ..sort();
      if (numbers.isNotEmpty) return numbers.last.toString();

      final fallbackNumbers =
          versions.map(_versionNumber).whereType<int>().toList()..sort();
      if (fallbackNumbers.isNotEmpty) return fallbackNumbers.last.toString();
    }

    throw StateError('Roboflow project response did not include versions.');
  }

  static int? _versionNumber(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? int.tryParse(value.split('/').last);
    }
    if (value is Map<String, dynamic>) {
      return _versionNumber(
        value['version'] ?? value['id'] ?? value['name'] ?? value['number'],
      );
    }
    return null;
  }

  static bool _hasTrainedModel(dynamic value) {
    if (value is! Map<String, dynamic>) return false;
    final model = value['model'];
    return model is Map<String, dynamic> && model.isNotEmpty;
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
