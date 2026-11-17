import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_input_decoration.dart';
import '../theme/app_text_styles.dart';
import '../utils/validators.dart';
import '../widgets/gradient_button.dart';
import '../widgets/password_strength_meter.dart';
import '../widgets/role_selector.dart';

const _roleIcons = {
  UserRole.paciente: Icons.accessibility_new,
  UserRole.cuidador: Icons.favorite_border_outlined,
  UserRole.admin: Icons.admin_panel_settings_outlined,
};

/// Alta de una cuenta nueva ([user] = null) o edición de sus datos.
/// Al guardar vuelve con el mensaje a mostrar.
class AdminUserFormScreen extends StatefulWidget {
  const AdminUserFormScreen({super.key, this.user});

  final ManagedUser? user;

  @override
  State<AdminUserFormScreen> createState() => _AdminUserFormScreenState();
}

class _AdminUserFormScreenState extends State<AdminUserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nombres = TextEditingController(text: widget.user?.nombres);
  late final _apellidos = TextEditingController(text: widget.user?.apellidos);
  late final _documento = TextEditingController(text: widget.user?.documento);
  final _email = TextEditingController();
  final _password = TextEditingController();

  UserRole _role = UserRole.paciente;
  bool _obscure = true;
  bool _saving = false;

  bool get _isNew => widget.user == null;

  @override
  void dispose() {
    _nombres.dispose();
    _apellidos.dispose();
    _documento.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final documento = Validators.normalizeDocument(_documento.text);
    try {
      final String message;
      if (_isNew) {
        final created = await AdminService.instance.createUser(
          NewUser(
            nombres: _nombres.text,
            apellidos: _apellidos.text,
            email: _email.text,
            documento: documento,
            password: _password.text,
            role: _role,
          ),
        );
        message =
            'Cuenta creada: ${created.fullName} (${_role.label}). Ya puede '
            'entrar con ${created.email}.';
      } else {
        await AdminService.instance.updateUser(
          widget.user!,
          nombres: _nombres.text,
          apellidos: _apellidos.text,
          documento: documento,
        );
        message = 'Datos de ${_nombres.text.trim()} actualizados.';
      }
      if (mounted) Navigator.pop(context, message);
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
          _isNew ? 'Dar de alta' : 'Editar datos',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isNew) ...[
                  RoleSelector(
                    label: 'Tipo de cuenta',
                    roles: [
                      for (final role in UserRole.values)
                        RoleOption(label: role.label, icon: _roleIcons[role]!),
                    ],
                    selectedRole: _role.label,
                    onChanged: (label) => setState(
                      () => _role = UserRole.values.firstWhere(
                        (role) => role.label == label,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Text(
                    widget.user!.email,
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.textMute,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nombres,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        validator: Validators.personName,
                        style: AppTextStyles.body(fontSize: 13),
                        decoration: appFieldDecoration(
                          hintText: AppStrings.nameHint,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _apellidos,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        validator: Validators.personName,
                        style: AppTextStyles.body(fontSize: 13),
                        decoration: appFieldDecoration(
                          hintText: AppStrings.lastNameHint,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isNew) ...[
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: Validators.email,
                    style: AppTextStyles.body(fontSize: 13),
                    decoration: appFieldDecoration(
                      hintText: AppStrings.emailHint,
                      icon: Icons.mail_outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _documento,
                  textInputAction: _isNew
                      ? TextInputAction.next
                      : TextInputAction.done,
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
                if (_isNew) ...[
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 12),
                  _Note(
                    _role == UserRole.admin
                        ? 'Esta cuenta va a tener acceso total al sistema: '
                              'puede dar de alta y de baja a cualquier usuario.'
                        : 'Pasale al usuario su correo y esta contraseña por '
                              'un medio seguro. Con eso ya puede iniciar '
                              'sesión.',
                    warn: _role == UserRole.admin,
                  ),
                ],
                const SizedBox(height: 20),
                GradientButton(
                  label: _saving
                      ? 'Guardando…'
                      : (_isNew ? 'Crear cuenta' : 'Guardar cambios'),
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.warn = false});

  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = warn ? AppColors.amber : AppColors.line;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warn
            ? AppColors.amber.withValues(alpha: 0.06)
            : AppColors.overlay,
        border: Border.all(color: warn ? color.withValues(alpha: 0.4) : color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: AppTextStyles.body(
          fontSize: 11.5,
          color: AppColors.textMute,
        ).copyWith(height: 1.45),
      ),
    );
  }
}
