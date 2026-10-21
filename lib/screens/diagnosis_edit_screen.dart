import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_input_decoration.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/gradient_button.dart';
import '../widgets/option_grid.dart';
import '../widgets/unsaved_changes_guard.dart';

const diagnosisTypes = ['Principal', 'Secundario', 'Antecedente'];

const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

class Diagnosis {
  const Diagnosis({
    required this.patient,
    required this.type,
    required this.title,
    this.description = '',
    this.date = '',
    this.professional = '',
    this.institution = '',
    this.specialty = '',
    this.current = true,
    this.lastEdit,
  });

  final String patient;
  final String type;
  final String title;
  final String description;
  final String date;
  final String professional;
  final String institution;
  final String specialty;
  final bool current;

  final String? lastEdit;
}

class DiagnosisEditScreen extends StatefulWidget {
  const DiagnosisEditScreen({
    super.key,
    required this.diagnosis,
    required this.navItems,
    required this.currentIndex,
    this.isNew = false,
  });

  final Diagnosis diagnosis;
  final List<AppNavItem> navItems;
  final int currentIndex;

  final bool isNew;

  @override
  State<DiagnosisEditScreen> createState() => _DiagnosisEditScreenState();
}

class _DiagnosisEditScreenState extends State<DiagnosisEditScreen> {
  late String _type = widget.diagnosis.type;
  late bool _current = widget.diagnosis.current;
  late final _titleController = TextEditingController(
    text: widget.diagnosis.title,
  );
  late final _descriptionController = TextEditingController(
    text: widget.diagnosis.description,
  );
  late final _dateController = TextEditingController(
    text: widget.diagnosis.date,
  );
  late final _professionalController = TextEditingController(
    text: widget.diagnosis.professional,
  );
  late final _institutionController = TextEditingController(
    text: widget.diagnosis.institution,
  );
  late final _specialtyController = TextEditingController(
    text: widget.diagnosis.specialty,
  );

  bool _closing = false;

  bool get _hasUnsavedChanges {
    if (_closing) return false;
    final original = widget.diagnosis;
    return _type != original.type ||
        _current != original.current ||
        _titleController.text != original.title ||
        _descriptionController.text != original.description ||
        _dateController.text != original.date ||
        _professionalController.text != original.professional ||
        _institutionController.text != original.institution ||
        _specialtyController.text != original.specialty;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _professionalController.dispose();
    _institutionController.dispose();
    _specialtyController.dispose();
    super.dispose();
  }

  String get _initials => widget.diagnosis.patient
      .split(' ')
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word[0].toUpperCase())
      .join();

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (picked == null) return;
    _dateController.text =
        '${picked.day.toString().padLeft(2, '0')} '
        '${_months[picked.month - 1]} ${picked.year}';
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa el diagnóstico.')));
      return;
    }
    _closing = true;
    Navigator.pop(context);
    final message = widget.isNew ? 'Diagnóstico guardado' : 'Cambios guardados';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$message (demo, sin backend)')));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgPanel,
        title: Text(
          'Eliminar diagnóstico',
          style: AppTextStyles.display(fontSize: 16),
        ),
        content: Text(
          '¿Quieres eliminar este diagnóstico? Esta acción no se puede '
          'deshacer.',
          style: AppTextStyles.body(fontSize: 13, color: AppColors.textMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: AppTextStyles.body(color: AppColors.textMute),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Eliminar',
              style: AppTextStyles.body(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _closing = true;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnóstico eliminado (demo, sin backend)'),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: AppTextStyles.mono(fontSize: 11, letterSpacing: 0.8),
    ),
  );

  Widget _textField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: AppTextStyles.body(fontSize: 13),
      decoration: appFieldDecoration(hintText: hint, icon: icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      hasChanges: () => _hasUnsavedChanges,
      listenable: Listenable.merge([
        _titleController,
        _descriptionController,
        _dateController,
        _professionalController,
        _institutionController,
        _specialtyController,
      ]),
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final lastEdit = widget.diagnosis.lastEdit;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          widget.isNew ? 'Nuevo diagnóstico' : 'Editar diagnóstico',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Paciente'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.overlay,
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        spacing: 12,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.violet.withValues(
                              alpha: 0.3,
                            ),
                            child: Text(
                              _initials,
                              style: AppTextStyles.body(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            widget.diagnosis.patient,
                            style: AppTextStyles.body(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _sectionTitle('Tipo de diagnóstico'),
                    OptionGrid(
                      label: 'Tipo',
                      options: diagnosisTypes,
                      selected: _type,
                      onChanged: (type) => setState(() => _type = type),
                    ),
                    _sectionTitle('Datos clínicos'),
                    _textField(
                      _titleController,
                      'Diagnóstico (ej. Contractura cervical)',
                      Icons.medical_services_outlined,
                    ),
                    const SizedBox(height: 12),
                    _textField(
                      _descriptionController,
                      'Descripción / observaciones',
                      Icons.notes,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _dateController,
                      readOnly: true,
                      onTap: _pickDate,
                      style: AppTextStyles.body(fontSize: 13),
                      decoration: appFieldDecoration(
                        hintText: 'Fecha del diagnóstico',
                        icon: Icons.calendar_today_outlined,
                      ),
                    ),
                    _sectionTitle('Profesional informante'),
                    _textField(
                      _professionalController,
                      'Nombre del profesional',
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      spacing: 10,
                      children: [
                        Expanded(
                          child: _textField(
                            _institutionController,
                            'Institución',
                            Icons.local_hospital_outlined,
                          ),
                        ),
                        Expanded(
                          child: _textField(
                            _specialtyController,
                            'Especialidad',
                            Icons.bookmark_border,
                          ),
                        ),
                      ],
                    ),
                    _sectionTitle('Vigencia'),
                    OptionGrid(
                      label: 'Estado',
                      options: const ['Vigente', 'No vigente'],
                      selected: _current ? 'Vigente' : 'No vigente',
                      onChanged: (state) =>
                          setState(() => _current = state == 'Vigente'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: GradientButton(
                            label: widget.isNew
                                ? 'Guardar diagnóstico'
                                : 'Guardar cambios',
                            onPressed: _save,
                          ),
                        ),
                        if (!widget.isNew)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _delete,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(0),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                side: BorderSide(
                                  color: AppColors.coral.withValues(alpha: 0.6),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Eliminar',
                                style: AppTextStyles.body(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.coral,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppColors.line),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: AppTextStyles.body(
                            fontSize: 14,
                            color: AppColors.textMute,
                          ),
                        ),
                      ),
                    ),
                    if (widget.isNew || lastEdit != null) ...[
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          widget.isNew
                              ? 'Se registrará como registrado_por: '
                                    'María González'
                              : 'Última edición por $lastEdit',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body(
                            fontSize: 11,
                            color: AppColors.textMute,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: widget.navItems,
        currentIndex: widget.currentIndex,
      ),
    );
  }
}
