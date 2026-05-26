import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:vision/roboflow_service.dart'; // Adjust import path as needed

class RoboflowProvider extends ChangeNotifier {
  final List<File> _images = [];
  String _className = '';
  bool _isProcessing = false;
  String? _statusMessage;

  List<File> get images => List.unmodifiable(_images);
  String get className => _className;
  bool get isProcessing => _isProcessing;
  String? get statusMessage => _statusMessage;
  bool get canSubmit => _images.isNotEmpty && _className.trim().isNotEmpty;

  void setClassName(String value) {
    final normalized = value.trim();
    if (_className == normalized) return;
    _className = normalized;
    notifyListeners();
  }

  void addImages(List<File> files) {
    if (files.isEmpty) return;
    _images.addAll(files);
    _statusMessage = null;
    notifyListeners();
  }

  void removeImageAt(int index) {
    if (index < 0 || index >= _images.length) return;
    _images.removeAt(index);
    _statusMessage = null;
    notifyListeners();
  }

  Future<void> uploadAndTrain() async {
    if (!canSubmit || _isProcessing) return;
    _setProcessing(true);

    final result = await RoboflowService.uploadBatchForTraining(
      _images,
      _className,
    );
    _statusMessage = result.message;

    _setProcessing(false);
  }

  void reset() {
    _images.clear();
    _className = '';
    _isProcessing = false;
    _statusMessage = null;
    notifyListeners();
  }

  void _setProcessing(bool value) {
    if (_isProcessing == value) return;
    _isProcessing = value;
    notifyListeners();
  }
}
