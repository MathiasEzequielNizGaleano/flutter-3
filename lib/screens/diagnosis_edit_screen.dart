import 'package:flutter/material.dart';

import '../services/attachment_service.dart';
import '../services/auth_service.dart';
import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/attachments_section.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/diagnosis_card.dart';
import '../widgets/form_fields.dart';
import '../widgets/gradient_button.dart';
import '../widgets/info_card.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/option_grid.dart';
import '../widgets/status_badge.dart';
import '../widgets/unsaved_changes_guard.dart';

/// Registrar (diagnóstico sin id), corregir o anular un diagnóstico. Con
/// [readOnly], o si está anulado, solo lo muestra. Al guardar vuelve con el
/// mensaje a mostrar.
class DiagnosisEditScreen extends StatefulWidget {
  const DiagnosisEditScreen({
    super.key,
    required this.diagnosis,
    required this.patientName,
    this.readOnly = false,
    this.navItems,
    this.currentIndex = 0,
  });

  final Diagnosis diagnosis;
  final String patientName;
  final bool readOnly;

  /// Barra inferior de la sección desde la que se abrió (opcional).
  final List<AppNavItem>? navItems;
  final int currentIndex;

  @override
  State<DiagnosisEditScreen> createState() => _DiagnosisEditScreenState();
}

class _DiagnosisEditScreenState extends State<DiagnosisEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Diagnosis _original = widget.diagnosis;
  late DiagnosisType _type = _original.tipo;
  late bool _current = _original.esActual;
  late DateTime? _date = _original.fechaDiagnostico;
  late final _title = TextEditingController(text: _original.diagnostico);
  late final _description = TextEditingController(text: _original.descripcion);
  late final _professional = TextEditingController(text: _original.profesional);
  late final _institution = TextEditingController(text: _original.institucion);
  late final _specialty = TextEditingController(text: _original.especialidad);
  bool _saving = false;

  /// Documentos elegidos para un diagnóstico nuevo: se suben al guardar.
  List<PickedFile> _staged = const [];

  bool get _isNew => _original.id.isEmpty;
  bool get _editable => !widget.readOnly && !_original.anulado;

  Diagnosis get _edited => _original.copyWith(
    tipo: _type,
    diagnostico: _title.text,
    descripcion: _description.text,
    fechaDiagnostico: () => _date,
    profesional: _professional.text,
    institucion: _institution.text,
    especialidad: _specialty.text,
    esActual: _current,
  );

  bool get _hasChanges =>
      _editable &&
      !_saving &&
      (!_edited.sameContentAs(_original) || _staged.isNotEmpty);

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _professional,
      _institution,
      _specialty,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Ejecuta [action] y vuelve con el mensaje que devuelve.
  Future<void> _run(Future<String> Function() action) async {
    setState(() => _saving = true);
    try {
      final message = await action();
      if (mounted) Navigator.pop(context, message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AuthService.describeError(e))));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final edited = _edited;
    final service = RecordsService.instance;
    if (_isNew) {
      await _run(() async {
        final id = await service.addDiagnosis(
          edited,
          paciente: widget.patientName,
        );
        return _uploadStaged(edited.copyWith(id: id));
      });
    } else {
      await _run(() async {
        await service.updateDiagnosis(
          _original,
          edited,
          paciente: widget.patientName,
        );
        return 'Cambios guardados.';
      });
    }
  }

  /// Sube los documentos elegidos antes de guardar. Si alguno falla, el
  /// diagnóstico ya quedó registrado: se avisa para adjuntarlo después.
  Future<String> _uploadStaged(Diagnosis saved) async {
    final failed = <String>[];
    for (final file in _staged) {
      try {
        await AttachmentService.instance.upload(
          saved,
          file,
          paciente: widget.patientName,
        );
      } catch (_) {
        failed.add(file.name);
      }
    }
    if (failed.isNotEmpty) {
      return 'Diagnóstico registrado, pero no se pudo subir '
          '${failed.join(', ')}. Podés adjuntarlo desde el diagnóstico.';
    }
    return switch (_staged.length) {
      0 => 'Diagnóstico registrado.',
      1 => 'Diagnóstico registrado con 1 documento.',
      final n => 'Diagnóstico registrado con $n documentos.',
    };
  }

  Widget _attachments() => AttachmentsSection(
    diagnosis: _original,
    patientName: widget.patientName,
    canEdit: _editable,
    staged: _staged,
    onStagedChanged: (files) => setState(() => _staged = files),
  );

  Future<void> _annul() async {
    final confirmed = await confirmAction(
      context,
      title: '¿Anular el diagnóstico?',
      message:
          'Deja de figurar como vigente, pero no se borra: queda en el '
          'historial marcado como anulado y no se puede volver a editar.',
      confirmLabel: 'Sí, anular',
    );
    if (!confirmed) return;
    await _run(() async {
      await RecordsService.instance.annulDiagnosis(
        _original,
        paciente: widget.patientName,
      );
      return 'Diagnóstico anulado.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final nav = widget.navItems;
    return UnsavedChangesGuard(
      hasChanges: () => _hasChanges,
      listenable: Listenable.merge([
        _title,
        _description,
        _professional,
        _institution,
        _specialty,
      ]),
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: AppBar(
          backgroundColor: AppColors.bgDeep,
          foregroundColor: AppColors.text,
          title: Text(
            _isNew
                ? 'Nuevo diagnóstico'
                : (_editable ? 'Editar diagnóstico' : 'Diagnóstico'),
            style: AppTextStyles.display(fontSize: 18),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FormSectionLabel('Paciente'),
                _PatientRow(name: widget.patientName),
                if (_editable) _buildForm() else _buildDetail(),
                ..._footer(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        bottomNavigationBar: nav == null
            ? null
            : AppBottomNav(items: nav, currentIndex: widget.currentIndex),
      ),
    );
  }

  Widget _buildForm() {
    final supersedes = _type == DiagnosisType.principal && _current;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FormSectionLabel('Tipo de diagnóstico'),
          OptionGrid(
            label: 'Tipo',
            options: [for (final t in DiagnosisType.values) t.label],
            selected: _type.label,
            onChanged: (label) => setState(
              () => _type = DiagnosisType.values.firstWhere(
                (t) => t.label == label,
              ),
            ),
          ),
          const FormSectionLabel('Datos clínicos'),
          AppTextField(
            controller: _title,
            hint: 'Diagnóstico (ej. Parálisis cerebral)',
            icon: Icons.medical_services_outlined,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Escribe el diagnóstico.'
                : null,
          ),
          AppTextField(
            controller: _description,
            hint: 'Descripción / observaciones',
            icon: Icons.notes,
            maxLines: 3,
          ),
          DatePickerField(
            value: _date,
            hint: 'Fecha del diagnóstico',
            onChanged: (date) => setState(() => _date = date),
          ),
          const FormSectionLabel('Profesional informante'),
          AppTextField(
            controller: _professional,
            hint: 'Nombre del profesional',
            icon: Icons.person_outline,
            capitalization: TextCapitalization.words,
          ),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _institution,
                  hint: 'Institución',
                  icon: Icons.local_hospital_outlined,
                  capitalization: TextCapitalization.words,
                ),
              ),
              Expanded(
                child: AppTextField(
                  controller: _specialty,
                  hint: 'Especialidad',
                  icon: Icons.bookmark_border,
                  capitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),
          const FormSectionLabel('Vigencia'),
          OptionGrid(
            label: 'Estado',
            options: const ['Vigente', 'No vigente'],
            selected: _current ? 'Vigente' : 'No vigente',
            onChanged: (state) => setState(() => _current = state == 'Vigente'),
          ),
          if (supersedes)
            FormFootnote(
              'Si ${widget.patientName} ya tiene otro diagnóstico principal '
              'vigente, pasa a "No vigente". No se borra.',
            ),
          _attachments(),
          const SizedBox(height: 16),
          GradientButton(
            label: _saving
                ? 'Guardando…'
                : (_isNew ? 'Guardar diagnóstico' : 'Guardar cambios'),
            onPressed: _saving ? null : _save,
          ),
          if (!_isNew) ...[
            const SizedBox(height: 10),
            OutlineActionButton(
              label: 'Anular diagnóstico',
              onPressed: _saving ? null : _annul,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetail() {
    final d = _original;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FormSectionLabel('Diagnóstico'),
        InfoCard(
          rows: [
            InfoRow('Diagnóstico', value: d.diagnostico, stacked: true),
            if (d.descripcion.isNotEmpty)
              InfoRow('Descripción', value: d.descripcion, stacked: true),
            InfoRow(
              'Tipo',
              trailing: StatusBadge(
                text: d.tipo.label,
                tone: diagnosisTone(d.tipo),
              ),
            ),
            InfoRow(
              'Fecha',
              value: d.fechaDiagnostico == null
                  ? 'Sin fecha'
                  : formatLongDate(d.fechaDiagnostico!),
            ),
            InfoRow(
              'Estado',
              trailing: StatusBadge(
                text: diagnosisStatus(d),
                tone: d.isCurrent ? StatusBadgeTone.ok : StatusBadgeTone.mute,
              ),
            ),
            if (d.profesional.isNotEmpty)
              InfoRow('Profesional', value: d.profesional),
            if (d.source.isNotEmpty) InfoRow('Institución', value: d.source),
          ],
        ),
        _attachments(),
      ],
    );
  }

  List<Widget> _footer() {
    final d = _original;
    if (_isNew) {
      final author = AuthService.instance.current?.fullName;
      return [
        if (author != null) FormFootnote('Se registrará a nombre de $author.'),
      ];
    }
    String when(DateTime? time) =>
        time == null ? '' : ' · ${formatEventTime(time)}';
    return [
      if (d.nombreRegistrador.isNotEmpty)
        FormFootnote(
          'Registrado por ${d.nombreRegistrador}${when(d.fechaRegistro)}',
        ),
      if (d.nombreModificador.isNotEmpty)
        FormFootnote(
          '${d.anulado ? 'Anulado' : 'Última edición'} por '
          '${d.nombreModificador}${when(d.fechaModificacion)}',
        ),
    ];
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.overlay,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        spacing: 12,
        children: [
          InitialsAvatar(initialsOf(name), size: 36),
          Expanded(
            child: Text(
              name,
              style: AppTextStyles.body(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
