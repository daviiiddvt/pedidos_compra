import 'dart:typed_data';

import 'package:flutter/material.dart';

class PedidoFotoTab extends StatelessWidget {
  const PedidoFotoTab({
    super.key,
    required this.imageBytes,
    required this.uploading,
    required this.onCamera,
    required this.onGallery,
  });

  final Uint8List? imageBytes;
  final bool uploading;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 220, maxHeight: 420),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline),
            ),
            alignment: Alignment.center,
            child: imageBytes == null
                ? Icon(
                    Icons.photo_camera_back_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.memory(
                      imageBytes!,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (uploading)
            const Center(child: CircularProgressIndicator())
          else
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: onCamera,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('CÁMARA'),
                ),
                ElevatedButton.icon(
                  onPressed: onGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('FOTOTECA'),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            imageBytes == null
                ? 'No hay una foto adjunta.'
                : 'La foto se enviará al pulsar Guardar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
