import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vision/roboflow_provider.dart';

const _bg = Color(0xFFF7F7F5);
const _surface = Color(0xFFFFFFFF);
const _ink = Color(0xFF111111);
const _muted = Color(0xFF888888);
const _border = Color(0xFFE4E4E0);
const _accent = Color(0xFF1A1A1A);
const _tag = Color(0xFFEEF2FF);
const _tagText = Color(0xFF4338CA);

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _picker = ImagePicker();
  final _classController = TextEditingController();

  @override
  void dispose() {
    _classController.dispose();
    super.dispose();
  }

  Future<void> _addImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (!mounted || picked.isEmpty) return;
    context.read<RoboflowProvider>().addImages(
      picked.map((image) => File(image.path)).toList(),
    );
  }

  Future<void> _uploadAndTrain() async {
    final provider = context.read<RoboflowProvider>();
    provider.setClassName(_classController.text);
    await provider.uploadAndTrain();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoboflowProvider>(
      builder: (context, provider, _) {
        final canSubmit = provider.canSubmit && !provider.isProcessing;

        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Column(
              children: [
                _Header(
                  onReset: provider.images.isEmpty && provider.className.isEmpty
                      ? null
                      : () {
                          _classController.clear();
                          provider.reset();
                        },
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _InfoCard(),
                        const SizedBox(height: 22),
                        _ClassNameField(
                          controller: _classController,
                          enabled: !provider.isProcessing,
                          onChanged: provider.setClassName,
                        ),
                        const SizedBox(height: 18),
                        _SelectedImages(
                          images: provider.images,
                          isProcessing: provider.isProcessing,
                          onRemove: provider.removeImageAt,
                        ),
                        const SizedBox(height: 22),
                        if (provider.isProcessing) const _ProcessingState(),
                        if (provider.statusMessage != null) ...[
                          const SizedBox(height: 14),
                          _StatusMessage(message: provider.statusMessage!),
                        ],
                      ],
                    ),
                  ),
                ),
                _ActionBar(
                  imageCount: provider.images.length,
                  canAdd: !provider.isProcessing,
                  canSubmit: canSubmit,
                  isProcessing: provider.isProcessing,
                  onAdd: _addImages,
                  onSubmit: _uploadAndTrain,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback? onReset;

  const _Header({required this.onReset});

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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                Text(
                  'Prepare images for Roboflow training',
                  style: TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
          if (onReset != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: _ink, size: 20),
              tooltip: 'Start over',
              onPressed: onReset,
            ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.model_training_rounded, color: _muted, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Select a batch of images, assign one class tag, then use Upload and Train. The actual Roboflow upload and Django trigger are wired in the next phases.',
              style: TextStyle(fontSize: 13, color: _muted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassNameField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _ClassNameField({
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Class name / tag',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          textInputAction: TextInputAction.done,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'e.g. Pepsi-500ml',
            hintStyle: const TextStyle(color: _muted),
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
          ),
        ),
      ],
    );
  }
}

class _SelectedImages extends StatelessWidget {
  final List<File> images;
  final bool isProcessing;
  final ValueChanged<int> onRemove;

  const _SelectedImages({
    required this.images,
    required this.isProcessing,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: const Column(
          children: [
            Icon(Icons.photo_library_outlined, size: 42, color: _muted),
            SizedBox(height: 10),
            Text(
              'No images selected',
              style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
            ),
            SizedBox(height: 4),
            Text(
              'Add training images from your gallery.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _tag,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${images.length} image${images.length == 1 ? '' : 's'} selected',
                style: const TextStyle(
                  color: _tagText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: images.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            return _ImageTile(
              file: images[index],
              onRemove: isProcessing ? null : () => onRemove(index),
            );
          },
        ),
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  final File file;
  final VoidCallback? onRemove;

  const _ImageTile({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(file, fit: BoxFit.cover),
        ),
        if (onRemove != null)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProcessingState extends StatelessWidget {
  const _ProcessingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Processing upload and training trigger...',
              style: TextStyle(fontSize: 13, color: _ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final String message;

  const _StatusMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: _ink, height: 1.4),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final int imageCount;
  final bool canAdd;
  final bool canSubmit;
  final bool isProcessing;
  final VoidCallback onAdd;
  final VoidCallback onSubmit;

  const _ActionBar({
    required this.imageCount,
    required this.canAdd,
    required this.canSubmit,
    required this.isProcessing,
    required this.onAdd,
    required this.onSubmit,
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
            child: _Button(
              icon: Icons.add_photo_alternate_outlined,
              label: 'Add Images',
              onTap: canAdd ? onAdd : null,
              primary: false,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Button(
              icon: Icons.cloud_upload_outlined,
              label: isProcessing
                  ? 'Processing...'
                  : imageCount == 0
                  ? 'Upload and Train'
                  : 'Upload and Train ($imageCount)',
              onTap: canSubmit ? onSubmit : null,
              primary: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  const _Button({
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
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primary ? Colors.white : _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
