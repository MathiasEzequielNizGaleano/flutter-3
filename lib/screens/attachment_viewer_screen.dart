import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/attachment_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/state_views.dart';

/// Muestra una foto adjunta, con zoom. También se puede abrir con otra app
/// (galería) para guardarla o compartirla.
class AttachmentViewerScreen extends StatelessWidget {
  const AttachmentViewerScreen({
    super.key,
    required this.name,
    required this.bytes,
  });

  final String name;
  final Uint8List bytes;

  Future<void> _openOutside(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final problem = await FileAccess.instance.open(name, bytes);
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          name,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.display(fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Abrir con otra app',
            onPressed: () => _openOutside(context),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: SafeArea(
        child: InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.memory(
              bytes,
              semanticLabel: name,
              errorBuilder: (context, error, stack) => const EmptyState(
                title: 'No se puede mostrar',
                message:
                    'La imagen está dañada o en un formato que el teléfono '
                    'no reconoce.',
                icon: Icons.broken_image_outlined,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
