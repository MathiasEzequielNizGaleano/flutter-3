import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/validators.dart';
import '../widgets/form_fields.dart';
import '../widgets/gradient_button.dart';
import '../widgets/unsaved_changes_guard.dart';

/// Datos personales del cuidador (los edita él mismo o el administrador).
/// Al guardar vuelve con el mensaje a mostrar.
class CaregiverDataFormScreen extends StatefulWidget {
  const CaregiverDataFormScreen({
    super.key,
    required this.caregiverUid,
    required this.caregiverName,
    required this.record,
  });

  final String caregiverUid;
  final String caregiverName;
  final CaregiverRecord record;

  @override
  State<CaregiverDataFormScreen> createState() =>
      _CaregiverDataFormScreenState();
}

class _CaregiverDataFormScreenState extends State<CaregiverDataFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final CaregiverRecord _original = widget.record;
  late DateTime? _birth = _original.fechaNacimiento;
  late Sex? _sex = _original.sexo;
  late final _phone = TextEditingController(text: _original.telefono);
  late final _address = TextEditingController(text: _original.direccion);
  late final _altEmail = TextEditingController(
    text: _original.correoAlternativo,
  );
  late final _job = TextEditingController(text: _original.ocupacion);
  late final _notes = TextEditingController(text: _original.observaciones);
  bool _saving = false;

  CaregiverRecord get _edited => CaregiverRecord(
    fechaNacimiento: _birth,
    sexo: _sex,
    telefono: _phone.text,
    direccion: _address.text,
    correoAlternativo: _altEmail.text,
    ocupacion: _job.text,
    observaciones: _notes.text,
  );

  bool get _hasChanges {
    if (_saving) return false;
    final a = _edited.toMap();
    final b = _original.toMap();
    return a.keys.any((key) => a[key] != b[key]);
  }

  @override
  void dispose() {
    for (final c in [_phone, _address, _altEmail, _job, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await RecordsService.instance.saveCaregiver(
        widget.caregiverUid,
        _edited,
        nombre: widget.caregiverName,
      );
      if (mounted) Navigator.pop(context, 'Datos guardados.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AuthService.describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      hasChanges: () => _hasChanges,
      listenable: Listenable.merge([_phone, _address, _altEmail, _job, _notes]),
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: AppBar(
          backgroundColor: AppColors.bgDeep,
          foregroundColor: AppColors.text,
          title: Text(
            'Datos personales',
            style: AppTextStyles.display(fontSize: 18),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.caregiverName,
                    style: AppTextStyles.display(fontSize: 15),
                  ),
                  const FormSectionLabel('Datos personales'),
                  DatePickerField(
                    value: _birth,
                    hint: 'Fecha de nacimiento',
                    onChanged: (date) => setState(() => _birth = date),
                  ),
                  ChoiceDropdown<Sex>(
                    value: _sex,
                    values: Sex.values,
                    hint: 'Sexo',
                    icon: Icons.wc,
                    onChanged: (sex) => setState(() => _sex = sex),
                  ),
                  AppTextField(
                    controller: _job,
                    hint: 'Ocupación (opcional)',
                    icon: Icons.work_outline,
                  ),
                  const FormSectionLabel('Contacto'),
                  AppTextField(
                    controller: _phone,
                    hint: 'Teléfono',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: Validators.optionalPhone,
                  ),
                  AppTextField(
                    controller: _altEmail,
                    hint: 'Correo alternativo (opcional)',
                    icon: Icons.alternate_email,
                    keyboardType: TextInputType.emailAddress,
                    capitalization: TextCapitalization.none,
                    validator: Validators.optionalEmail,
                  ),
                  AppTextField(
                    controller: _address,
                    hint: 'Dirección (opcional)',
                    icon: Icons.home_outlined,
                    keyboardType: TextInputType.streetAddress,
                  ),
                  const FormSectionLabel('Observaciones'),
                  AppTextField(
                    controller: _notes,
                    hint: 'Información relevante',
                    icon: Icons.notes,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  GradientButton(
                    label: _saving ? 'Guardando…' : 'Guardar',
                    onPressed: _saving ? null : _save,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
