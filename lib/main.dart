import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vision/model_updater.dart';
import 'package:vision/roboflow_provider.dart';
import 'package:vision/upload_screen.dart';

import 'classifier.dart';
import 'roboflow_service.dart';

// ─────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

// ─────────────────────────────────────────────
// Palette
// ─────────────────────────────────────────────

const _bg = Color(0xFFF7F7F5);
const _surface = Color(0xFFFFFFFF);
const _ink = Color(0xFF111111);
const _muted = Color(0xFF888888);
const _border = Color(0xFFE4E4E0);
const _accent = Color(0xFF1A1A1A);
const _green = Color(0xFF00875A);
const _amber = Color(0xFFB45309);
const _red = Color(0xFFDC2626);
const _tag = Color(0xFFEEF2FF);
const _tagText = Color(0xFF4338CA);

// ─────────────────────────────────────────────
// App
// ─────────────────────────────────────────────

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RoboflowProvider(),
      child: MaterialApp(
        title: 'Scanly',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: _bg,
          fontFamily: 'Georgia', // serif warmth — distinctive
          colorScheme: ColorScheme.light(primary: _accent, surface: _surface),
          useMaterial3: true,
        ),
        home: const _AppShell(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// App Shell — bottom nav between Scan and Train
// ─────────────────────────────────────────────

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _tab = 0;

  final _classifier = Classifier();
  bool _modelReady = false;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    try {
      final path = await ModelUpdater.checkAndUpdate();
      await _classifier.loadModel(modelPath: path);
      if (mounted) setState(() => _modelReady = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Model load failed: $e')));
      }
    }
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ScanPage(classifier: _classifier, modelReady: _modelReady),
      const UploadScreen(),
    ];

    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: _BottomNav(
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Bottom Nav
// ─────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.image_search_rounded,
                label: 'Scan',
                active: current == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.model_training_rounded,
                label: 'Train',
                active: current == 1,
                onTap: () => onTap(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? _accent : _muted;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                fontFamily: 'Georgia',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════
// SCAN PAGE
// ═════════════════════════════════════════════

class ScanPage extends StatefulWidget {
  final Classifier classifier;
  final bool modelReady;
  const ScanPage({
    super.key,
    required this.classifier,
    required this.modelReady,
  });

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class ScanItem {
  final File image;
  final Map<String, dynamic> result;
  ScanItem({required this.image, required this.result});
}

class _ScanPageState extends State<ScanPage> {
  final _picker = ImagePicker();
  final List<ScanItem> _items = [];
  bool _loading = false;

  // ── Picking ───────────────────────────────

  Future<void> _pickCamera() async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (x == null) return;
    await _process([x]);
  }

  Future<void> _pickGallery() async {
    final xs = await _picker.pickMultiImage(imageQuality: 85);
    if (xs.isEmpty) return;
    await _process(xs);
  }

  // ── Processing ────────────────────────────

  Future<void> _process(List<XFile> picked) async {
    setState(() {
      _loading = true;
      _items.clear();
    });

    final results = <ScanItem>[];

    for (final x in picked) {
      final file = File(x.path);
      final result = await widget.classifier.classify(file);
      results.add(ScanItem(image: file, result: result));

      if (result['isRecognized'] == false && mounted) {
        await _showUnknownDialog(file);
      }
    }

    if (mounted)
      setState(() {
        _items.addAll(results);
        _loading = false;
      });
  }

  // ── Unknown dialogs ───────────────────────

  Future<void> _showUnknownDialog(File image) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _Sheet(
        icon: Icons.help_outline_rounded,
        iconBg: const Color(0xFFFEF3C7),
        iconColor: _amber,
        title: 'Product not recognized',
        body:
            'Confidence too low. You can submit this image to improve the model.',
        cancel: 'Skip',
        confirm: 'Submit for training',
        onConfirm: () {
          Navigator.pop(context);
          _promptLabel(image);
        },
      ),
    );
  }

  void _promptLabel(File image) {
    showDialog<String>(
      context: context,
      builder: (_) => const _LabelDialog(
        title: 'Name this product',
        hint: 'e.g. Pepsi 500ml',
        confirm: 'Submit',
      ),
    ).then((label) async {
      if (label == null || label.isEmpty) return;
      if (!mounted) return;
      final ok = await RoboflowService.uploadForTraining(image, label);
      if (!mounted) return;
      _toast(ok ? '✓ Submitted — thank you!' : '✗ Upload failed');
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _PageHeader(
              title: 'Scanner',
              subtitle: 'Classify a product',
              action: widget.modelReady && !_loading ? null : null,
            ),
            Expanded(child: _body()),
            _ScanActions(
              enabled: widget.modelReady && !_loading,
              onCamera: _pickCamera,
              onGallery: _pickGallery,
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (!widget.modelReady) {
      return const _Loader(label: 'Initializing model…');
    }
    if (_loading) {
      return const _Loader(label: 'Classifying…');
    }
    if (_items.isEmpty) {
      return _EmptyState(
        icon: Icons.image_search_rounded,
        title: 'Nothing scanned yet',
        body: 'Take a photo or pick from gallery to classify a product.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) => _ScanCard(
        item: _items[i],
        onSubmit: () => _promptLabel(_items[i].image),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Scan Card
// ─────────────────────────────────────────────

class _ScanCard extends StatelessWidget {
  final ScanItem item;
  final VoidCallback onSubmit;
  const _ScanCard({required this.item, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final label = item.result['label'] as String? ?? 'Unknown';
    final confidence = (item.result['confidence'] as double? ?? 0) * 100;
    final recognized = item.result['isRecognized'] as bool? ?? false;
    final allScores = item.result['all'] as Map<String, double>? ?? {};
    final topEntries = allScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final confColor = confidence >= 70
        ? _green
        : confidence >= 45
        ? _amber
        : _red;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          SizedBox(
            height: 220,
            width: double.infinity,
            child: Image.file(item.image, fit: BoxFit.cover),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status + label
                Row(
                  children: [
                    _Chip(
                      label: recognized ? 'Recognized' : 'Unknown',
                      color: recognized ? _green : _red,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 10),

                // Confidence bar
                Row(
                  children: [
                    const Text(
                      'Confidence',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                    const Spacer(),
                    Text(
                      '${confidence.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: confColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: confidence / 100,
                    minHeight: 5,
                    backgroundColor: _border,
                    valueColor: AlwaysStoppedAnimation(confColor),
                  ),
                ),

                // Top predictions list
                if (topEntries.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Divider(color: _border, height: 1),
                  const SizedBox(height: 12),
                  const Text(
                    'All predictions',
                    style: TextStyle(
                      fontSize: 11,
                      color: _muted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...topEntries.take(4).map((e) {
                    final pct = (e.value * 100).clamp(0.0, 100.0);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.key,
                              style: const TextStyle(fontSize: 13, color: _ink),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: pct / 100,
                                minHeight: 4,
                                backgroundColor: _border,
                                valueColor: const AlwaysStoppedAnimation(
                                  _accent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 38,
                            child: Text(
                              '${pct.toStringAsFixed(1)}%',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 14),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onSubmit,
                    icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                    label: const Text('Submit for training'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent,
                      side: const BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Georgia',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Scan actions bar
// ─────────────────────────────────────────────

class _ScanActions extends StatelessWidget {
  final bool enabled;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  const _ScanActions({
    required this.enabled,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionBtn(
              icon: Icons.camera_alt_outlined,
              label: 'Camera',
              onTap: enabled ? onCamera : null,
              primary: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionBtn(
              icon: Icons.photo_library_outlined,
              label: 'Gallery',
              onTap: enabled ? onGallery : null,
              primary: false,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════
// TRAIN PAGE
// ═════════════════════════════════════════════

class TrainPage extends StatefulWidget {
  const TrainPage({super.key});

  @override
  State<TrainPage> createState() => _TrainPageState();
}

class _TrainPageState extends State<TrainPage> {
  final _picker = ImagePicker();

  // ── Active batch state ────────────────────
  List<File> _images = [];
  String _className = '';
  bool _uploading = false;
  int _uploaded = 0;
  String? _doneMsg;

  // ── Step tracking ─────────────────────────
  // 0 = choose class name
  // 1 = add images
  // 2 = uploading / done
  int _step = 0;

  final _classCtrl = TextEditingController();

  @override
  void dispose() {
    _classCtrl.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _images = [];
      _className = '';
      _uploading = false;
      _uploaded = 0;
      _doneMsg = null;
      _step = 0;
      _classCtrl.clear();
    });
  }

  // ── Step 0 → Step 1 ───────────────────────

  void _confirmClassName() {
    final name = _classCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _className = name;
      _step = 1;
    });
  }

  // ── Add images ────────────────────────────

  Future<void> _addFromCamera() async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() => _images.add(File(x.path)));
  }

  Future<void> _addFromGallery() async {
    final xs = await _picker.pickMultiImage(imageQuality: 85);
    if (xs.isEmpty) return;
    final files = xs.map((x) => File(x.path));
    setState(() => _images.addAll(files));
  }

  void _removeImage(int i) => setState(() => _images.removeAt(i));

  // ── Upload batch ──────────────────────────

  Future<void> _upload() async {
    if (_images.isEmpty) return;
    setState(() {
      _uploading = true;
      _uploaded = 0;
      _step = 2;
    });

    int success = 0;

    for (int i = 0; i < _images.length; i++) {
      final ok = await RoboflowService.uploadForTraining(
        _images[i],
        _className,
      );
      if (ok) success++;
      setState(() => _uploaded = i + 1);
    }

    setState(() {
      _uploading = false;
      _doneMsg =
          '$success / ${_images.length} images uploaded as "$_className"';
    });
  }

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _PageHeader(
              title: 'Train',
              subtitle: 'Add images for a product class',
              action: _step > 0
                  ? IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _ink,
                        size: 20,
                      ),
                      onPressed: _reset,
                      tooltip: 'Start over',
                    )
                  : null,
            ),
            Expanded(
              child: _step == 0
                  ? _StepClassName(
                      controller: _classCtrl,
                      onConfirm: _confirmClassName,
                    )
                  : _step == 1
                  ? _StepAddImages(
                      images: _images,
                      className: _className,
                      onCamera: _addFromCamera,
                      onGallery: _addFromGallery,
                      onRemove: _removeImage,
                      onUpload: _upload,
                    )
                  : _StepUploadProgress(
                      images: _images,
                      className: _className,
                      uploaded: _uploaded,
                      uploading: _uploading,
                      doneMsg: _doneMsg,
                      onReset: _reset,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Step 0 — Enter class name
// ─────────────────────────────────────────────

class _StepClassName extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onConfirm;
  const _StepClassName({required this.controller, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicator
          _StepBadge(step: 1, total: 2, label: 'Name the product class'),
          const SizedBox(height: 20),

          // Info card — explains annotation
          _InfoCard(
            icon: Icons.auto_awesome_outlined,
            title: 'How annotation works',
            body:
                'You give a product a class name (e.g. "Pepsi-500ml"). '
                'Every image you upload is automatically tagged with that class '
                'in Roboflow — no manual annotation needed. '
                'Then you generate a dataset version and train.',
          ),
          const SizedBox(height: 24),

          const Text(
            'Product class name',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _ink,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onConfirm(),
            style: const TextStyle(
              fontSize: 16,
              color: _ink,
              fontFamily: 'Georgia',
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Pepsi-500ml',
              hintStyle: const TextStyle(color: _muted, fontFamily: 'Georgia'),
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _accent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use hyphens instead of spaces. Keep it unique per product variant.',
            style: TextStyle(fontSize: 12, color: _muted),
          ),

          const SizedBox(height: 28),

          // Tips
          _TipsList(
            tips: const [
              'Use at least 50 images per class for good accuracy.',
              'Vary angles, lighting and background in your photos.',
              'Each product variant (size, flavour) should be its own class.',
              'After uploading, go to Roboflow dashboard to generate version & train.',
            ],
          ),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: _ActionBtn(
              icon: Icons.arrow_forward_rounded,
              label: 'Next — Add images',
              onTap: onConfirm,
              primary: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Step 1 — Add images
// ─────────────────────────────────────────────

class _StepAddImages extends StatelessWidget {
  final List<File> images;
  final String className;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final ValueChanged<int> onRemove;
  final VoidCallback onUpload;

  const _StepAddImages({
    required this.images,
    required this.className,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final count = images.length;
    final hasEnough = count >= 10;
    final ideal = count >= 50;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepBadge(
                  step: 2,
                  total: 2,
                  label: 'Add images for "$className"',
                ),
                const SizedBox(height: 16),

                // Class name pill
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _tag,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.label_rounded,
                            size: 14,
                            color: _tagText,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            className,
                            style: const TextStyle(
                              color: _tagText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Count + progress
                _ImageCountBar(count: count),
                const SizedBox(height: 16),

                // Grid of images
                if (images.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: images.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemBuilder: (_, i) => _TrainImageTile(
                      file: images[i],
                      onRemove: () => onRemove(i),
                    ),
                  ),

                const SizedBox(height: 16),

                // Add buttons
                Row(
                  children: [
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.camera_alt_outlined,
                        label: 'Camera',
                        onTap: onCamera,
                        primary: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.photo_library_outlined,
                        label: 'Gallery',
                        onTap: onGallery,
                        primary: false,
                      ),
                    ),
                  ],
                ),

                if (!hasEnough && count > 0) ...[
                  const SizedBox(height: 12),
                  _Banner(
                    color: const Color(0xFFFEF3C7),
                    icon: Icons.warning_amber_rounded,
                    iconColor: _amber,
                    text:
                        'You have $count image${count == 1 ? '' : 's'}. '
                        'Add at least ${10 - count} more before uploading. '
                        '50+ recommended for good accuracy.',
                  ),
                ],

                if (ideal) ...[
                  const SizedBox(height: 12),
                  _Banner(
                    color: const Color(0xFFDCFCE7),
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: _green,
                    text:
                        'Great — $count images ready. You can upload now or add more.',
                  ),
                ],

                const SizedBox(height: 80), // space for bottom bar
              ],
            ),
          ),
        ),

        // Upload bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: _surface,
            border: Border(top: BorderSide(color: _border)),
          ),
          child: SizedBox(
            width: double.infinity,
            child: _ActionBtn(
              icon: Icons.cloud_upload_outlined,
              label: count == 0
                  ? 'Add images first'
                  : 'Upload $count image${count == 1 ? '' : 's'} as "$className"',
              onTap: hasEnough ? onUpload : null,
              primary: true,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Step 2 — Upload progress / done
// ─────────────────────────────────────────────

class _StepUploadProgress extends StatelessWidget {
  final List<File> images;
  final String className;
  final int uploaded;
  final bool uploading;
  final String? doneMsg;
  final VoidCallback onReset;

  const _StepUploadProgress({
    required this.images,
    required this.className,
    required this.uploaded,
    required this.uploading,
    required this.doneMsg,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final total = images.length;
    final progress = total == 0 ? 0.0 : uploaded / total;
    final done = !uploading && doneMsg != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (uploading) ...[
            const Text(
              'Uploading…',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$uploaded of $total images sent to Roboflow',
              style: const TextStyle(fontSize: 14, color: _muted),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: _border,
                valueColor: const AlwaysStoppedAnimation(_accent),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _accent,
              ),
            ),
          ],

          if (done) ...[
            // Success header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: _green,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload complete',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      Text(
                        'Images are now in Roboflow',
                        style: TextStyle(fontSize: 13, color: _muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Text(
                doneMsg!,
                style: const TextStyle(fontSize: 14, color: _ink, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),

            // What to do next — the training steps guide
            const Text(
              'What to do next',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 12),
            _NextStepsList(className: className),
            const SizedBox(height: 24),

            _InfoCard(
              icon: Icons.info_outline_rounded,
              title: 'About automatic annotation',
              body:
                  'Every image you uploaded was tagged with "$className" in Roboflow. '
                  'For image classification, the tag IS the annotation — there are no '
                  'bounding boxes to draw. When you generate a dataset version, '
                  'Roboflow converts those tags into class labels automatically.',
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: _ActionBtn(
                icon: Icons.add_rounded,
                label: 'Train another product',
                onTap: onReset,
                primary: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// "What to do next" steps
// ─────────────────────────────────────────────

class _NextStepsList extends StatelessWidget {
  final String className;
  const _NextStepsList({required this.className});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        '1',
        'Open Roboflow dashboard',
        'Go to roboflow.com → your project → you will see your uploaded images in the Annotate section.',
      ),
      (
        '2',
        'Assign images to a class',
        'Select all images in the batch tagged "$className" → Assign to class → type "$className" → Save. This is how Roboflow knows which class each image belongs to.',
      ),
      (
        '3',
        'Generate a dataset version',
        'Click Versions → Generate New Version. Set preprocessing: Auto-Orient + Resize 224×224. Add augmentations if desired. Split: 80/10/10.',
      ),
      (
        '4',
        'Train the model',
        'On the version page click Train → Roboflow Train → Classification. This trains a TFLite-compatible model. Takes 10–30 min.',
      ),
      (
        '5',
        'Export TFLite',
        'After training → Deploy → Export → TFLite (float32). Your app\'s ModelUpdater will detect the new version and auto-download it on next launch.',
      ),
    ];

    return Column(
      children: steps.map((s) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    s.$1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.$2,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.$3,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ═════════════════════════════════════════════
// Shared small widgets
// ═════════════════════════════════════════════

class _PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  const _PageHeader({required this.title, required this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    fontFamily: 'Georgia',
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.4 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: primary ? _accent : _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary ? _accent : _border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: primary ? Colors.white : _ink, size: 18),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: primary ? Colors.white : _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Georgia',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _Loader extends StatelessWidget {
  final String label;
  const _Loader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2, color: _accent),
          const SizedBox(height: 16),
          Text(label, style: const TextStyle(color: _muted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: const Color(0xFFD1D1D1)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  final int step;
  final int total;
  final String label;
  const _StepBadge({
    required this.step,
    required this.total,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Step $step of $total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: _muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipsList extends StatelessWidget {
  final List<String> tips;
  const _TipsList({required this.tips});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _tag.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCDD5F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tips_and_updates_outlined, size: 14, color: _tagText),
              SizedBox(width: 6),
              Text(
                'Tips for better accuracy',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _tagText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...tips.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '·  ',
                    style: TextStyle(color: _tagText, fontSize: 13),
                  ),
                  Expanded(
                    child: Text(
                      t,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _tagText,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String text;
  const _Banner({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: iconColor, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageCountBar extends StatelessWidget {
  final int count;
  const _ImageCountBar({required this.count});

  @override
  Widget build(BuildContext context) {
    final pct = (count / 50).clamp(0.0, 1.0);
    final color = count >= 50
        ? _green
        : count >= 10
        ? _amber
        : _red;
    final status = count >= 50
        ? 'Great amount'
        : count >= 10
        ? 'Minimum reached'
        : 'Need more images';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$count image${count == 1 ? '' : 's'} added',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 5,
            backgroundColor: _border,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('0', style: TextStyle(fontSize: 10, color: _muted)),
            Text('10 min', style: TextStyle(fontSize: 10, color: _muted)),
            Text('50 ideal', style: TextStyle(fontSize: 10, color: _muted)),
          ],
        ),
      ],
    );
  }
}

class _TrainImageTile extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  const _TrainImageTile({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(file, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Label dialog (reusable)
// ─────────────────────────────────────────────

class _LabelDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String confirm;
  const _LabelDialog({
    required this.title,
    required this.hint,
    required this.confirm,
  });

  @override
  State<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<_LabelDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: 'Georgia',
        ),
      ),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        style: const TextStyle(fontFamily: 'Georgia'),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: _muted),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: _muted)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(widget.confirm),
        ),
      ],
    );
  }

  void _submit() {
    final label = _ctrl.text.trim().replaceAll(RegExp(r'\s+'), '-');
    Navigator.pop(context, label);
  }
}

// ─────────────────────────────────────────────
// Confirmation sheet (reusable)
// ─────────────────────────────────────────────

class _Sheet extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String body;
  final String cancel;
  final String confirm;
  final VoidCallback onConfirm;

  const _Sheet({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.cancel,
    required this.confirm,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(fontSize: 13, color: _muted, height: 1.5),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(cancel, style: const TextStyle(color: _muted)),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(confirm),
        ),
      ],
    );
  }
}
