import 'dart:io';

import 'package:flutter/foundation.dart';

class RoboflowProvider extends ChangeNotifier {
  final List<File> _images = [];
  String _className = '';
  bool _isProcessing = false;

  List<File> get images => List.unmodifiable(_images);
  String get className => _className;
  bool get isProcessing => _isProcessing;
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
    notifyListeners();
  }

  void removeImageAt(int index) {
    if (index < 0 || index >= _images.length) return;
    _images.removeAt(index);
    notifyListeners();
  }

  Future<void> uploadAndTrain() async {
    if (!canSubmit || _isProcessing) return;
    _setProcessing(true);

    // Phase 1 owns UI/state only. Network upload and backend trigger are added
    // in Phase 2 after the Roboflow and Django request contracts are wired.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    _setProcessing(false);
  }

  void reset() {
    _images.clear();
    _className = '';
    _isProcessing = false;
    notifyListeners();
  }

  void _setProcessing(bool value) {
    if (_isProcessing == value) return;
    _isProcessing = value;
    notifyListeners();
  }
}
