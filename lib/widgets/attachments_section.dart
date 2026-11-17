import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../screens/attachment_viewer_screen.dart';
import '../services/attachment_service.dart';
import '../services/auth_service.dart';
import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import 'confirm_dialog.dart';
import 'form_fields.dart';
import 'status_badge.dart';

/// Documentación de respaldo de un diagnóstico (informes, estudios, fotos).
///
/// Si el diagnóstico ya está guardado, cada archivo se sube en el momento.
/// Si es nuevo, los archivos quedan en [staged] y la pantalla los sube al
/// guardar.
class AttachmentsSection extends StatefulWidget {
  const AttachmentsSection({
    super.key,
    required this.diagnosis,
    required this.patientName,
    required this.canEdit,
    this.staged = const [],
    this.onStagedChanged,
  });

  final Diagnosis diagnosis;
  final String patientName;
  final bool canEdit;

  /// Archivos elegidos para un diagnóstico que todavía no se guardó.
  final List<PickedFile> staged;
  final ValueChanged<List<PickedFile>>? onStagedChanged;

  @override
  State<AttachmentsSection> createState() => _AttachmentsSectionState();
}

class _AttachmentsSectionState extends State<AttachmentsSection> {
  Stream<List<Attachment>>? _attachments;

  /// Nombre del archivo que se está subiendo.
  String? _uploading;

  /// Id del adjunto que se está descargando o quitando.
  String? _busy;

  bool get _isNew => widget.diagnosis.id.isEmpty;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  void _watch() {
    _attachments = _isNew
        ? null
        : AttachmentService.instance.watch(widget.diagnosis);
  }

  /// Un aviso nuevo reemplaza al anterior en lugar de quedar en cola.
  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add() async {
    final PickedFile? file;
    try {
      file = await FileAccess.instance.pick();
    } catch (e) {
      _show('No se pudo abrir el selector de archivos.');
      return;
    }
    if (file == null || !mounted) return;
    final problem = file.problem;
    if (problem != null) {
      _show(problem);
      return;
    }
    if (_isNew) {
      widget.onStagedChanged?.call([...widget.staged, file]);
      return;
    }
    setState(() => _uploading = file!.name);
    try {
      await AttachmentService.instance.upload(
        widget.diagnosis,
        file,
        paciente: widget.patientName,
      );
      if (mounted) _show('Documento adjuntado.');
    } catch (e) {
      if (mounted) _show(AuthService.describeError(e));
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<void> _open(Attachment attachment) async {
    setState(() => _busy = attachment.id);
    try {
      final bytes = await AttachmentService.instance.download(attachment);
      if (!mounted) return;
      await _openBytes(attachment.nombre, bytes, isImage: attachment.isImage);
    } catch (e) {
      if (mounted) _show(AuthService.describeError(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _openBytes(
    String name,
    Uint8List bytes, {
    required bool isImage,
  }) async {
    if (isImage) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AttachmentViewerScreen(name: name, bytes: bytes),
        ),
      );
      return;
    }
    final problem = await FileAccess.instance.open(name, bytes);
    if (problem != null && mounted) _show(problem);
  }

  Future<void> _remove(Attachment attachment) async {
    final confirmed = await confirmAction(
      context,
      title: '¿Quitar el documento?',
      message:
          'Deja de figurar en el diagnóstico, pero no se borra: queda en el '
          'historial marcado como quitado.',
      confirmLabel: 'Sí, quitar',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = attachment.id);
    try {
      await AttachmentService.instance.remove(
        attachment,
        paciente: widget.patientName,
      );
      if (mounted) _show('Documento quitado.');
    } catch (e) {
      if (mounted) _show(AuthService.describeError(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FormSectionLabel('Documentación de respaldo'),
        if (_isNew) ..._stagedRows() else _savedRows(),
        if (_uploading != null)
          _AttachmentRow(
            name: _uploading!,
            detail: 'Subiendo…',
            isImage: mimeTypeFor(_uploading!)?.startsWith('image/') ?? false,
            busy: true,
          ),
        if (widget.canEdit) ...[
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _uploading == null ? _add : null,
            icon: Icon(Icons.attach_file, color: AppColors.cyan, size: 18),
            label: Text(
              'Adjuntar documento',
              style: AppTextStyles.body(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _isNew
                  ? 'PDF, JPG o PNG de hasta ${formatBytes(maxAttachmentBytes)}. '
                        'Se suben al guardar el diagnóstico.'
                  : 'PDF, JPG o PNG de hasta '
                        '${formatBytes(maxAttachmentBytes)}.',
              style: AppTextStyles.body(
                fontSize: 11,
                color: AppColors.textMute,
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _stagedRows() {
    if (widget.staged.isEmpty && !widget.canEdit) return [_empty()];
    return [
      for (final file in widget.staged)
        _AttachmentRow(
          name: file.name,
          detail: '${formatBytes(file.size)} · se sube al guardar',
          isImage: file.mimeType?.startsWith('image/') ?? false,
          onTap: () => _openBytes(
            file.name,
            file.bytes,
            isImage: file.mimeType?.startsWith('image/') ?? false,
          ),
          onRemove: () => widget.onStagedChanged?.call([
            for (final f in widget.staged)
              if (!identical(f, file)) f,
          ]),
        ),
    ];
  }

  Widget _empty() => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      'No hay documentos adjuntos.',
      style: AppTextStyles.body(fontSize: 12, color: AppColors.textMute),
    ),
  );

  Widget _savedRows() {
    return StreamBuilder<List<Attachment>>(
      stream: _attachments,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Row(
            children: [
              Expanded(
                child: Text(
                  'No se pudieron cargar los documentos.',
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textMute,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(_watch),
                child: const Text('Reintentar'),
              ),
            ],
          );
        }
        final list = snapshot.data;
        if (list == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (list.isEmpty) {
          return widget.canEdit ? const SizedBox.shrink() : _empty();
        }
        return Column(
          children: [
            for (final a in list)
              _AttachmentRow(
                name: a.nombre,
                detail: _detail(a),
                isImage: a.isImage,
                removed: !a.activo,
                busy: _busy == a.id,
                onTap: _busy == null ? () => _open(a) : null,
                onRemove: widget.canEdit && a.activo && _busy == null
                    ? () => _remove(a)
                    : null,
              ),
          ],
        );
      },
    );
  }

  String _detail(Attachment a) {
    final parts = [
      formatBytes(a.tamano),
      if (a.nombreSubidor.isNotEmpty) a.nombreSubidor,
      if (a.fechaSubida != null) formatShortDate(a.fechaSubida!),
    ];
    if (!a.activo && a.nombreQuitador.isNotEmpty) {
      parts.add('quitado por ${a.nombreQuitador}');
    }
    return parts.join(' · ');
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({
    required this.name,
    required this.detail,
    required this.isImage,
    this.removed = false,
    this.busy = false,
    this.onTap,
    this.onRemove,
  });

  final String name;
  final String detail;
  final bool isImage;
  final bool removed;
  final bool busy;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final muted = removed ? AppColors.textMute : AppColors.text;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.overlay,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              spacing: 10,
              children: [
                Icon(
                  isImage
                      ? Icons.image_outlined
                      : Icons.picture_as_pdf_outlined,
                  color: removed ? AppColors.textMute : AppColors.cyan,
                  size: 22,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppTextStyles.body(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: muted,
                            ).copyWith(
                              decoration: removed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      Text(
                        detail,
                        style: AppTextStyles.body(
                          fontSize: 10.5,
                          color: AppColors.textMute,
                        ),
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (removed)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: StatusBadge(
                      text: 'Quitado',
                      tone: StatusBadgeTone.mute,
                    ),
                  )
                else if (onRemove != null)
                  IconButton(
                    tooltip: 'Quitar $name',
                    onPressed: onRemove,
                    icon: Icon(
                      Icons.close,
                      color: AppColors.textMute,
                      size: 18,
                    ),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
