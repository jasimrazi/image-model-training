import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class Classifier {
  late Interpreter _interpreter;
  late List<String> _labels;
  static const int inputSize = 224;
  static const double threshold = 0.70; // 70% confidence

  Future<void> loadModel({String? modelPath}) async {
    if (modelPath != null && File(modelPath).existsSync()) {
      _interpreter = Interpreter.fromFile(File(modelPath));
    } else {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
    }
    final raw = await rootBundle.loadString('assets/labels.txt');
    _labels = raw.split('\n')
        .map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<Map<String, dynamic>> classify(File image) async {
    final bytes = await image.readAsBytes();
    final decoded = img.decodeImage(bytes)!;
    final resized = img.copyResize(decoded,
        width: inputSize, height: inputSize);

    // Normalize pixels [0..1]
    final input = List.generate(1, (_) =>
      List.generate(inputSize, (y) =>
        List.generate(inputSize, (x) {
          final p = resized.getPixel(x, y);
          return [p.r/255.0, p.g/255.0, p.b/255.0];
        })));

    final output = List.filled(_labels.length, 0.0)
        .reshape([1, _labels.length]);
    _interpreter.run(input, output);

    final scores = output[0] as List<double>;
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final maxIdx = scores.indexOf(maxScore);

    return {
      'label': _labels[maxIdx],
      'confidence': maxScore,
      'isRecognized': maxScore >= threshold,
      'all': Map.fromIterables(_labels, scores),
    };
  }

  void dispose() => _interpreter.close();
}
