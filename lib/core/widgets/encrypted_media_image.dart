import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/media_encryption_provider.dart';

class EncryptedMediaImage extends ConsumerStatefulWidget {
  const EncryptedMediaImage({
    required this.filePath,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String filePath;
  final BoxFit fit;

  @override
  ConsumerState<EncryptedMediaImage> createState() =>
      _EncryptedMediaImageState();
}

class _EncryptedMediaImageState extends ConsumerState<EncryptedMediaImage> {
  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EncryptedMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) _load();
  }

  void _load() {
    _bytes = ref
        .read(mediaEncryptionServiceProvider)
        .decryptBytes(widget.filePath);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return Image.memory(bytes, fit: widget.fit, gaplessPlayback: true);
        }
        if (snapshot.hasError) {
          return ColoredBox(
            color: colors.surfaceContainerHighest,
            child: Icon(
              Icons.broken_image_outlined,
              color: colors.onSurfaceVariant,
              size: 36,
            ),
          );
        }
        return ColoredBox(
          color: colors.surfaceContainerLow,
          child: const Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}
