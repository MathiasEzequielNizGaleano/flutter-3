import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/care_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_input_decoration.dart';
import '../theme/app_text_styles.dart';
import '../utils/validators.dart';
import '../widgets/filter_chips.dart';
import '../widgets/form_fields.dart';
import '../widgets/gradient_button.dart';
import '../widgets/password_strength_meter.dart';

/// El cuidador registra a un paciente nuevo: se crea su cuenta y queda
/// vinculado como su cuidador, con todos los permisos. Al terminar vuelve
/// con el mensaje a mostrar.
class PatientRegisterScreen extends StatefulWidget {
  const PatientRegisterScreen({super.key});

  @override
  State<PatientRegisterScreen> createState() => _PatientRegisterScreenState();
}

class _PatientRegisterScreenState extends State<PatientRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _documento = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _parentesco;
  Responsibility _resp = Responsibility.principal;
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_nombres, _apellidos, _documento, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final patient = await CareService.instance.registerPatient(
        NewUser(
          nombres: _nombres.text,
          apellidos: _apellidos.text,
          email: _email.text,
          documento: Validators.normalizeDocument(_documento.text),
          password: _password.text,
          role: UserRole.paciente,
        ),
        parentesco: _parentesco!,
        responsabilidad: _resp,
      );
      if (mounted) {
        Navigator.pop(
          context,
          '${patient.fullName} quedó registrado y ya es tu paciente. '
          'Puede entrar con ${patient.email}.',
        );
      }
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
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          'Registrar paciente',
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
                const FormSectionLabel('Datos del paciente'),
                AppTextField(
                  controller: _nombres,
                  hint: AppStrings.nameHint,
                  capitalization: TextCapitalization.words,
                  validator: Validators.personName,
                ),
                AppTextField(
                  controller: _apellidos,
                  hint: AppStrings.lastNameHint,
                  capitalization: TextCapitalization.words,
                  validator: Validators.personName,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _documento,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9.\- ]'),
                      ),
                      LengthLimitingTextInputFormatter(14),
                    ],
                    validator: Validators.document,
                    style: AppTextStyles.body(fontSize: 13),
                    decoration: appFieldDecoration(
                      hintText: AppStrings.documentHint,
                      icon: Icons.badge_outlined,
                    ),
                  ),
                ),
                const FormSectionLabel('Cuenta del paciente'),
                AppTextField(
                  controller: _email,
                  hint: AppStrings.emailHint,
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  capitalization: TextCapitalization.none,
                  validator: Validators.email,
                ),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  validator: Validators.newPassword,
                  onChanged: (_) => setState(() {}),
                  style: AppTextStyles.body(fontSize: 13),
                  decoration: appFieldDecoration(
                    hintText: 'Contraseña inicial',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      tooltip: _obscure
                          ? AppStrings.showPassword
                          : AppStrings.hidePassword,
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.cyan,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                PasswordStrengthMeter(password: _password.text),
                const FormSectionLabel('Tu relación con el paciente'),
                DropdownButtonFormField<String>(
                  initialValue: _parentesco,
                  isExpanded: true,
                  dropdownColor: AppColors.bgPanel,
                  decoration: appFieldDecoration(
                    hintText: 'Parentesco o relación',
                    icon: Icons.family_restroom,
                  ),
                  style: AppTextStyles.body(fontSize: 13),
                  items: [
                    for (final kinship in kinshipOptions)
                      DropdownMenuItem(value: kinship, child: Text(kinship)),
                  ],
                  validator: (value) =>
                      value == null ? 'Elegí el parentesco.' : null,
                  onChanged: (value) => setState(() => _parentesco = value),
                ),
                const SizedBox(height: 12),
                FilterChips(
                  options: [for (final r in Responsibility.values) r.label],
                  selected: _resp.label,
                  onChanged: (label) => setState(
                    () => _resp = Responsibility.values.firstWhere(
                      (r) => r.label == label,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: _saving ? 'Registrando…' : 'Registrar paciente',
                  onPressed: _saving ? null : _save,
                ),
                const FormFootnote(
                  'Vas a quedar como su cuidador con todos los permisos (ver '
                  'y editar sus datos, configurar y calibrar). El '
                  'administrador puede cambiarlos. Pasale al paciente su '
                  'correo y contraseña por un medio seguro.',
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
