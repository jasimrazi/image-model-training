import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

// ─────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────

class VisionLabel {
  final String description;
  final double score;

  VisionLabel({required this.description, required this.score});
}

class VisionResult {
  final List<VisionLabel> labels;
  final String extractedText;
  final Map<String, dynamic> rawResponse;

  VisionResult({
    required this.labels,
    this.extractedText = '',
    required this.rawResponse,
  });

  String get topLabel => labels.isNotEmpty ? labels.first.description : '';

  bool get hasResults => labels.isNotEmpty || extractedText.trim().isNotEmpty;
}

// ─────────────────────────────────────────────
// TensorFlow Lite Service
// ─────────────────────────────────────────────

class CloudVisionService {
  late Interpreter _interpreter;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  late ImageLabeler _imageLabeler;

  List<String> _labels = [];

  bool _isInitialized = false;

  static const int inputSize = 224;

  // ─────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      // First verify the assets exist
      try {
        await rootBundle.load('assets/model.tflite');
      } catch (e) {
        // Handle error implicitly
      }

      try {
        await rootBundle.loadString('assets/labels.txt');
      } catch (e) {
        // Handle error implicitly
      }

      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      final labelData = await rootBundle.loadString('assets/labels.txt');
      
      _labels = labelData.split('\n');
      _imageLabeler = ImageLabeler(options: ImageLabelerOptions());
      _isInitialized = true;
    } catch (e) {
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────

  Future<VisionResult> scanFile(File imageFile, {bool useMLKit = false}) async {
    if (!_isInitialized) {
      return VisionResult(
        labels: [],
        rawResponse: {'error': 'Model not initialized'},
      );
    }

    try {
      // Decode image
      final imageBytes = imageFile.readAsBytesSync();
      img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        return VisionResult(
          labels: [],
          rawResponse: {'error': 'Failed to decode image'},
        );
      }

      // Resize image
      final resizedImage = img.copyResize(
        originalImage,
        width: inputSize,
        height: inputSize,
      );

      // Convert image to model input
      final input = _imageToInputTensor(resizedImage);

      // Query the interpreter for the real output shape and size
      final outShape = _interpreter.getOutputTensor(0).shape; // e.g. [1, 1000]
      final int outLen = outShape.isNotEmpty ? outShape.last : _labels.length;

      // Check output tensor type
      final outTensorType = _interpreter.getOutputTensor(0).type;
      final outTypeStr = outTensorType.toString().toLowerCase();
      final outputIsUint8 = outTypeStr.contains('uint');

      // Create output buffer sized to the model's output
      // Use appropriate type based on model output
      final List<dynamic> output = outputIsUint8
          ? List.generate(1, (_) => Uint8List(outLen))
          : List.generate(1, (_) => List.filled(outLen, 0.0));

      // Run inference
      _interpreter.run(input, output);

      // Extract scores - handle both uint8 and float outputs
      final List<double> scores;
      if (outputIsUint8) {
        // Convert uint8 to doubles
        scores = (output[0] as List<int>).map((v) => v.toDouble()).toList();
      } else {
        scores = List<double>.from(output[0]);
      }

      // Ensure label list aligns with model outputs
      final List<String> effectiveLabels;
      if (_labels.length >= outLen) {
        effectiveLabels = _labels.sublist(0, outLen);
      } else {
        // pad with unknowns if labels file is shorter than model outputs
        effectiveLabels = List<String>.from(_labels)
          ..addAll(List.filled(outLen - _labels.length, 'unknown'));
      }

      // Create label list
      List<VisionLabel> results = [];
      String modelName = '';

      if (useMLKit) {
        modelName = 'Google ML Kit';
        final inputImage = InputImage.fromFile(imageFile);
        final labels = await _imageLabeler.processImage(inputImage);
        for (final label in labels) {
          results.add(VisionLabel(description: label.label, score: label.confidence));
        }
        results = results.take(5).toList();
      } else {
        modelName = 'MobileNet v3 (TFLite)';
        for (int i = 0; i < scores.length; i++) {
          final labelName = i < effectiveLabels.length
              ? effectiveLabels[i]
              : 'unknown';
          results.add(
            VisionLabel(description: labelName, score: scores[i].toDouble()),
          );
        }

        // Sort by confidence
        results.sort((a, b) => b.score.compareTo(a.score));

        // Top 5 results
        final filteredResults = results.where((r) => r.score > 0.0001).toList();
        results = filteredResults.take(5).toList();
      }

      // ML Kit Text Recognition
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      print('Model used: $modelName');

      return VisionResult(
        labels: results,
        extractedText: recognizedText.text,
        rawResponse: {
          'model': modelName,
          'topPrediction': results.isNotEmpty
              ? results.first.description
              : '',
          'rawTopScore': results.isNotEmpty ? results.first.score : 0,
        },
      );
    } catch (e) {
      print('Inference error: $e');

      return VisionResult(labels: [], rawResponse: {'error': e.toString()});
    }
  }

  // ─────────────────────────────────────────────
  // Image Preprocessing
  // ─────────────────────────────────────────────

  dynamic _imageToInputTensor(img.Image image) {
    // Determine interpreter input type and produce matching tensor
    final inputTensor = _interpreter.getInputTensor(0);
    final tensorType = inputTensor.type;

    if (kDebugMode) print('Input tensor type: $tensorType');

    // Check if model expects uint8
    final tensorTypeStr = tensorType.toString().toLowerCase();
    final isUint8 = tensorTypeStr.contains('uint');

    if (isUint8) {
      // For uint8 models: use ints (0-255) in a 4D list
      return List.generate(
        1,
        (_) => List.generate(
          inputSize,
          (y) => List.generate(inputSize, (x) {
            final pixel = image.getPixel(x, y);
            return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
          }),
        ),
      );
    } else {
      // For float32 models: use doubles with normalization
      return List.generate(
        1,
        (_) => List.generate(
          inputSize,
          (y) => List.generate(inputSize, (x) {
            final pixel = image.getPixel(x, y);
            return [
              (pixel.r - 127.5) / 127.5,
              (pixel.g - 127.5) / 127.5,
              (pixel.b - 127.5) / 127.5
            ];
          }),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────

  void dispose() {
    _interpreter.close();
    _textRecognizer.close();
    _imageLabeler.close();
  }
}

// ─────────────────────────────────────────────
// Exception
// ─────────────────────────────────────────────

class VisionApiException implements Exception {
  final String message;
  final String? code;
  final String? details;

  VisionApiException(this.message, {this.code, this.details});

  @override
  String toString() =>
      'VisionApiException: $message'
      '${code != null ? ' (code: $code)' : ''}'
      '${details != null ? '\n$details' : ''}';
}
