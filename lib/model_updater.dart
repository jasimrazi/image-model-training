import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelUpdater {
  static const String _modelFilename = 'custom_model.tflite';
  static const String _versionKey = 'saved_model_version';

  /// Checks for an update, downloads it if available, and returns the local file path.
  /// Returns [null] if no custom model is found, triggering the fallback to assets.
  static Future<String?> checkAndUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentVersion = prefs.getInt(_versionKey) ?? 0;

      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/$_modelFilename';
      final localFile = File(savePath);

      final latestVersion = await _latestVersion();
      final modelDownloadUrl = _modelDownloadUrl(latestVersion);

      if (latestVersion <= 0 || modelDownloadUrl == null) {
        return localFile.existsSync() ? savePath : null;
      }

      if (latestVersion > currentVersion ||
          (currentVersion > 0 && !localFile.existsSync())) {
        print('Downloading new model version $latestVersion...');

        final modelResponse = await http.get(Uri.parse(modelDownloadUrl));

        if (modelResponse.statusCode == 200) {
          // Save the file to device storage
          await localFile.writeAsBytes(modelResponse.bodyBytes);
          // Save the new version number
          await prefs.setInt(_versionKey, latestVersion);

          print('Model updated successfully.');
          return savePath;
        } else {
          print(
            'Failed to download model. Status Code: ${modelResponse.statusCode}',
          );
        }
      }

      /* 
       * 3. RETURN SAVED FILE (If no update was needed)
       */
      if (localFile.existsSync()) {
        print('Using previously downloaded custom model.');
        return savePath;
      }

      // 4. Return null if we've never downloaded an update.
      // Your Classifier will see 'null' and load 'assets/model.tflite' instead.
      print('No custom model found. Falling back to bundled assets.');
      return null;
    } catch (e) {
      print('Error during model update: $e');

      // If there's no internet, try to load the previously downloaded model anyway
      try {
        final dir = await getApplicationDocumentsDirectory();
        final savePath = '${dir.path}/$_modelFilename';
        if (File(savePath).existsSync()) {
          return savePath;
        }
      } catch (_) {}

      return null;
    }
  }

  static Future<int> _latestVersion() async {
    final configuredVersion = int.tryParse(dotenv.env['MODEL_VERSION'] ?? '');
    if (configuredVersion != null) return configuredVersion;

    final versionUrl = dotenv.env['MODEL_VERSION_URL'] ?? '';
    if (versionUrl.isEmpty) return 0;

    final response = await http.get(Uri.parse(versionUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) return 0;

    return int.tryParse(response.body.trim()) ?? 0;
  }

  static String? _modelDownloadUrl(int version) {
    final directUrl = dotenv.env['MODEL_DOWNLOAD_URL'] ?? '';
    if (directUrl.isNotEmpty) return directUrl;

    final apiKey = dotenv.env['ROBOFLOW_API_KEY'] ?? '';
    final workspace = dotenv.env['WORKSPACE'] ?? '';
    final project = dotenv.env['PROJECT'] ?? '';

    if (apiKey.isEmpty || workspace.isEmpty || project.isEmpty || version <= 0) {
      return null;
    }

    return Uri.https(
      'api.roboflow.com',
      '/$workspace/$project/$version/tflite',
      {'api_key': apiKey},
    ).toString();
  }
}
