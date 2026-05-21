import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vision/model_updater.dart';

// Assuming these are your custom service files:
import 'classifier.dart';
import 'roboflow_service.dart';

// ─────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables if needed by your services
  await dotenv.load(fileName: '.env');

  runApp(const MyApp());
}

// ─────────────────────────────────────────────
// App
// ─────────────────────────────────────────────

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Product Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const ScannerScreen(),
    );
  }
}

// ─────────────────────────────────────────────
// Scanner Screen
// ─────────────────────────────────────────────

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerState();
}

class _ScannerState extends State<ScannerScreen> {
  final _classifier = Classifier();
  final _picker = ImagePicker();

  File? _image;
  Map? _result;
  bool _loading = false;
  bool _modelReady = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // 1. Check for model update
      final newModelPath = await ModelUpdater.checkAndUpdate();

      // 2. Load model (updated or bundled)
      await _classifier.loadModel(modelPath: newModelPath);

      if (mounted) {
        setState(() => _modelReady = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load model: $e')));
      }
    }
  }

  Future<void> _scan(ImageSource src) async {
    final picked = await _picker.pickImage(source: src, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _loading = true;
      _result = null;
    });

    try {
      final result = await _classifier.classify(_image!);

      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });

      if (result['isRecognized'] == false) {
        _showUnknownDialog();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Classification failed: $e')));
    }
  }

  void _showUnknownDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Product not recognized'),
        content: const Text('Help improve the app by naming this product.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showLabelDialog();
            },
            child: const Text('Submit for training'),
          ),
        ],
      ),
    );
  }

  void _showLabelDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Name this product'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'e.g. Pepsi 500ml',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final label = ctrl.text.trim().replaceAll(' ', '-'); // URL safe
              Navigator.pop(context);

              if (label.isEmpty || _image == null) return;

              // Optional: Show a loading snackbar while uploading
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Uploading for training...')),
              );

              final ok = await RoboflowService.uploadForTraining(
                _image!,
                label,
              );

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? '✅ Submitted! Thank you.'
                        : '❌ Upload failed. Try again.',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // UI Building
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scanner',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMainContent()),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (!_modelReady) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing Model...'),
          ],
        ),
      );
    }

    if (_image == null) {
      return Center(
        child: Icon(
          Icons.image_search_rounded,
          size: 120,
          color: Colors.grey.shade300,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Image Card
        Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.file(
                _image!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 350,
              ),
              if (_loading)
                Container(
                  width: double.infinity,
                  height: 350,
                  color: Colors.black45,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Results Section
        if (_result != null && !_loading) ...[
          const Text(
            'Analysis Result',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildResultRow(
                    'Recognized',
                    _result!['isRecognized'] == true ? 'Yes' : 'No',
                    _result!['isRecognized'] == true
                        ? Colors.green
                        : Colors.red,
                  ),
                  const Divider(height: 24),
                  // Assuming your map has 'label' and 'confidence' keys
                  _buildResultRow(
                    'Label',
                    _result!['label']?.toString() ?? 'Unknown',
                    Colors.black87,
                  ),
                  const SizedBox(height: 8),
                  _buildResultRow(
                    'Confidence',
                    _result!['confidence']?.toString() ?? 'N/A',
                    Colors.black54,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _image == null ? null : _showLabelDialog,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Submit this image for training'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultRow(String title, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _modelReady && !_loading
                  ? () => _scan(ImageSource.gallery)
                  : null,
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton.icon(
              onPressed: _modelReady && !_loading
                  ? () => _scan(ImageSource.camera)
                  : null,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
