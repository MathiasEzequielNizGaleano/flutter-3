import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/validators.dart';
import '../theme/app_text_styles.dart';
import '../widgets/password_strength_meter.dart';
import '../widgets/role_selector.dart';
import '../widgets/recaptcha_check.dart';
import '../widgets/consent_checkbox.dart';
import '../theme/app_input_decoration.dart';
import 'login_screen.dart' show homeFor;
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';
import 'two_factor_screen.dart';

const _registerRoles = [
  RoleOption(label: 'Paciente', icon: Icons.accessibility_new),
  RoleOption(label: 'Cuidador / tutor', icon: Icons.favorite_border_outlined),
];

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String _selectedRole = _registerRoles.first.label;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _notRobot = false;

  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _documentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isRegistering = false;

  bool get _canSubmit => _acceptedTerms && _acceptedPrivacy && _notRobot;

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _documentController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _openPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
    );
  }

  void _openTerms() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TermsScreen()),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isRegistering = true);

    final role = _selectedRole == 'Cuidador / tutor'
        ? UserRole.cuidador
        : UserRole.paciente;
    final AppUser user;
    try {
      user = await AuthService.instance.register(
        nombres: _nameController.text,
        apellidos: _lastNameController.text,
        email: _emailController.text,
        documento: Validators.normalizeDocument(_documentController.text),
        password: _passwordController.text,
        role: role,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isRegistering = false;
        _notRobot = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    if (!mounted) return;
    setState(() => _isRegistering = false);

    // Antes de entrar se verifica el correo con un código (simulado).
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TwoFactorScreen(user: user, destination: (_) => homeFor(user.role)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          AppStrings.createAccount,
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  RoleSelector(
                    label: AppStrings.registerAs,
                    roles: _registerRoles,
                    selectedRole: _selectedRole,
                    onChanged: (role) {
                      setState(() => _selectedRole = role);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.givenName],
                          validator: Validators.personName,
                          style: AppTextStyles.body(fontSize: 13),
                          decoration: appFieldDecoration(
                            hintText: AppStrings.nameHint,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.familyName],
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
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: Validators.email,
                    style: AppTextStyles.body(fontSize: 13),
                    decoration: appFieldDecoration(
                      hintText: AppStrings.emailHint,
                      icon: Icons.mail_outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _documentController,
                    textInputAction: TextInputAction.next,
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: Validators.newPassword,
                    onChanged: (_) => setState(() {}),
                    style: AppTextStyles.body(fontSize: 13),
                    decoration: appFieldDecoration(
                      hintText: AppStrings.passwordHint,
                      icon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? AppStrings.showPassword
                            : AppStrings.hidePassword,
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.cyan,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                  ),
                  PasswordStrengthMeter(password: _passwordController.text),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: Validators.confirmPassword(
                      () => _passwordController.text,
                    ),
                    style: AppTextStyles.body(fontSize: 13),
                    decoration: appFieldDecoration(
                      hintText: AppStrings.confirmPasswordHint,
                      icon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        tooltip: _obscureConfirmPassword
                            ? AppStrings.showPassword
                            : AppStrings.hidePassword,
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.cyan,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.overlay,
                      border: Border.all(color: AppColors.line, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text.rich(
                      TextSpan(
                        style: AppTextStyles.body(
                          fontSize: 11,
                          color: AppColors.textMute,
                        ),
                        children: [
                          TextSpan(
                            text: 'Aviso de privacidad: ',
                            style: TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const TextSpan(
                            text:
                                'los datos que proporciones serán tratados '
                                'conforme a la Ley N.º 7593/2025 y utilizados '
                                'exclusivamente para crear tu cuenta, vincular '
                                'pacientes con cuidadores y configurar el '
                                'dispositivo. El suministro de la información '
                                'es voluntario. Para más información consulta '
                                'la ',
                          ),
                          TextSpan(
                            text: 'Política de privacidad',
                            style: TextStyle(
                              color: AppColors.cyan,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = _openPrivacyPolicy,
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConsentCheckbox(
                    value: _acceptedTerms,
                    onChanged: (accepted) {
                      setState(() => _acceptedTerms = accepted ?? false);
                    },
                    prefix: 'He leído y acepto los ',
                    linkText: 'Términos y Condiciones de uso',
                    onLinkTap: _openTerms,
                    suffix: '.',
                  ),
                  ConsentCheckbox(
                    value: _acceptedPrivacy,
                    onChanged: (accepted) {
                      setState(() => _acceptedPrivacy = accepted ?? false);
                    },
                    prefix:
                        'Declaro haber leído el Aviso de privacidad y consiento '
                        'el tratamiento de mis datos personales, incluidos mis '
                        'datos de salud, para las finalidades descritas.',
                  ),
                  const SizedBox(height: 8),
                  RecaptchaCheck(
                    value: _notRobot,
                    onChanged: (value) => setState(() => _notRobot = value),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [AppColors.cyanAccent, AppColors.cyan],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: _canSubmit
                          ? [
                              BoxShadow(
                                color: AppColors.cyan.withValues(alpha: 0.5),
                                blurRadius: 30,
                              ),
                            ]
                          : [],
                    ),
                    child: ElevatedButton(
                      onPressed: _canSubmit && !_isRegistering
                          ? _handleRegister
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isRegistering
                          ? SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.bgPanel2,
                                semanticsLabel: AppStrings.creatingAccount,
                              ),
                            )
                          : Text(
                              AppStrings.createAccount,
                              style: AppTextStyles.body(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _canSubmit
                                    ? AppColors.bgPanel2
                                    : AppColors.textMute,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Los administradores se crean desde la base de datos',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      fontSize: 11,
                      color: AppColors.textMute,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
