import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/validators.dart';
import '../widgets/form_fields.dart';
import '../widgets/gradient_button.dart';
import '../widgets/unsaved_changes_guard.dart';

/// Datos personales del paciente. Con [selfEdit] lo abre el propio paciente
/// y solo cambia su teléfono, dirección y contacto de emergencia. Al guardar
/// vuelve con el mensaje a mostrar.
class PatientDataFormScreen extends StatefulWidget {
  const PatientDataFormScreen({
    super.key,
    required this.patientUid,
    required this.patientName,
    required this.record,
    this.selfEdit = false,
  });

  final String patientUid;
  final String patientName;
  final PatientRecord record;
  final bool selfEdit;

  @override
  State<PatientDataFormScreen> createState() => _PatientDataFormScreenState();
}

class _PatientDataFormScreenState extends State<PatientDataFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final PatientRecord _original = widget.record;
  late DateTime? _birth = _original.fechaNacimiento;
  late Sex? _sex = _original.sexo;
  late final _phone = TextEditingController(text: _original.telefono);
  late final _address = TextEditingController(text: _original.direccion);
  late final _senadis = TextEditingController(text: _original.registroSenadis);
  late final _contact = TextEditingController(
    text: _original.contactoEmergencia,
  );
  late final _contactPhone = TextEditingController(
    text: _original.telefonoEmergencia,
  );
  bool _saving = false;

  PatientRecord get _edited => PatientRecord(
    fechaNacimiento: _birth,
    sexo: _sex,
    telefono: _phone.text,
    direccion: _address.text,
    registroSenadis: _senadis.text,
    contactoEmergencia: _contact.text,
    telefonoEmergencia: _contactPhone.text,
    estadoFuncional: _original.estadoFuncional,
  );

  bool get _hasChanges {
    if (_saving) return false;
    final a = _edited.toPersonalMap();
    final b = _original.toPersonalMap();
    return a.keys.any((key) => a[key] != b[key]);
  }

  @override
  void dispose() {
    for (final c in [_phone, _address, _senadis, _contact, _contactPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await RecordsService.instance.savePatient(
        widget.patientUid,
        _edited,
        nombre: widget.patientName,
        selfEdit: widget.selfEdit,
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
    final full = !widget.selfEdit;
    return UnsavedChangesGuard(
      hasChanges: () => _hasChanges,
      listenable: Listenable.merge([
        _phone,
        _address,
        _senadis,
        _contact,
        _contactPhone,
      ]),
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: AppBar(
          backgroundColor: AppColors.bgDeep,
          foregroundColor: AppColors.text,
          title: Text(
            full ? 'Datos del paciente' : 'Mis datos de contacto',
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
                    widget.patientName,
                    style: AppTextStyles.display(fontSize: 15),
                  ),
                  if (full) ...[
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
                  ] else
                    const FormSectionLabel('Contacto'),
                  AppTextField(
                    controller: _phone,
                    hint: 'Teléfono',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: Validators.optionalPhone,
                  ),
                  AppTextField(
                    controller: _address,
                    hint: 'Dirección',
                    icon: Icons.home_outlined,
                    keyboardType: TextInputType.streetAddress,
                  ),
                  if (full) ...[
                    const FormSectionLabel('Registro SENADIS'),
                    AppTextField(
                      controller: _senadis,
                      hint: 'Número o referencia de registro',
                      icon: Icons.badge_outlined,
                      capitalization: TextCapitalization.characters,
                    ),
                  ],
                  const FormSectionLabel('Contacto de emergencia'),
                  AppTextField(
                    controller: _contact,
                    hint: 'Nombre de la persona',
                    icon: Icons.person_outline,
                    capitalization: TextCapitalization.words,
                  ),
                  AppTextField(
                    controller: _contactPhone,
                    hint: 'Teléfono de emergencia',
                    icon: Icons.phone_in_talk_outlined,
                    keyboardType: TextInputType.phone,
                    validator: Validators.optionalPhone,
                  ),
                  const SizedBox(height: 8),
                  GradientButton(
                    label: _saving ? 'Guardando…' : 'Guardar',
                    onPressed: _saving ? null : _save,
                  ),
                  if (!full)
                    const FormFootnote(
                      'Tu documento, fecha de nacimiento y registro SENADIS '
                      'los actualiza tu cuidador o el administrador.',
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
