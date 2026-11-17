import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_input_decoration.dart';
import '../theme/app_text_styles.dart';
import '../utils/validators.dart';
import '../widgets/recaptcha_check.dart';
import '../widgets/terms_acceptance.dart';
import 'admin_panel_screen.dart';
import 'caregiver_patients_screen.dart';
import 'patient_home_screen.dart';
import 'privacy_policy_screen.dart';
import 'register_screen.dart';
import 'terms_screen.dart';
import 'two_factor_screen.dart';

/// Pantalla de inicio según el rol guardado en la cuenta (no lo elige el
/// usuario al entrar).
Widget homeFor(UserRole role) => switch (role) {
  UserRole.cuidador => const CaregiverPatientsScreen(),
  UserRole.admin => const AdminPanelScreen(),
  UserRole.paciente => const PatientHomeScreen(),
};

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.notice});

  /// Aviso al volver al login (por ejemplo, sesión cerrada desde otro
  /// dispositivo).
  final String? notice;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoggingIn = false;
  bool _acceptedTerms = false;
  bool _notRobot = false;

  bool get _canLogin => _acceptedTerms && _notRobot && !_isLoggingIn;

  @override
  void initState() {
    super.initState();
    final notice = widget.notice;
    if (notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(notice), duration: const Duration(seconds: 8)),
        );
      });
    }
  }

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
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

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoggingIn = true;
    });

    final AppUser user;
    try {
      user = await AuthService.instance.signIn(
        email: _userController.text,
        password: _passwordController.text,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      // Como el reCAPTCHA real: después de un intento fallido hay que
      // volver a marcar la casilla.
      setState(() {
        _isLoggingIn = false;
        _notRobot = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoggingIn = false;
    });

    // Segundo paso: el código de verificación.
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppColors.cyan, AppColors.violet],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.cyan.withValues(alpha: 0.5),
                                blurRadius: 30,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(7),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/headmouse-logo.jpeg',
                                fit: BoxFit.cover,
                                semanticLabel: 'Logotipo de HeadMouse Pro',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          header: true,
                          child: Text(
                            AppStrings.appName,
                            style: AppTextStyles.display(),
                          ),
                        ),
                        Text(
                          AppStrings.tagline,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body(
                            fontSize: 11.5,
                            color: AppColors.textMute,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _userController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          validator: Validators.email,
                          style: AppTextStyles.body(fontSize: 13),
                          decoration: appFieldDecoration(
                            hintText: AppStrings.userHint,
                            icon: Icons.person_outline,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          validator: Validators.loginPassword,
                          onFieldSubmitted: (_) {
                            if (_canLogin) _handleLogin();
                          },
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
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TermsAcceptance(
                          includeTerms: true,
                          value: _acceptedTerms,
                          onChanged: (accepted) {
                            setState(() => _acceptedTerms = accepted ?? false);
                          },
                          onPolicyTap: _openPrivacyPolicy,
                          onTermsTap: _openTerms,
                        ),
                        const SizedBox(height: 16),
                        RecaptchaCheck(
                          value: _notRobot,
                          onChanged: (value) =>
                              setState(() => _notRobot = value),
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
                            boxShadow: _canLogin
                                ? [
                                    BoxShadow(
                                      color: AppColors.cyan.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 30,
                                    ),
                                  ]
                                : [],
                          ),
                          child: ElevatedButton(
                            onPressed: _canLogin ? _handleLogin : null,
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
                            child: Center(
                              child: _isLoggingIn
                                  ? SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.bgPanel2,
                                        semanticsLabel: AppStrings.loggingIn,
                                      ),
                                    )
                                  : Text(
                                      AppStrings.login,
                                      style: AppTextStyles.body(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: _canLogin
                                            ? AppColors.bgPanel2
                                            : AppColors.textMute,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Text(
                              AppStrings.noAccount,
                              style: AppTextStyles.body(
                                fontSize: 12,
                                color: AppColors.textMute,
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const RegisterScreen(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.cyan),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                AppStrings.register,
                                style: AppTextStyles.body(
                                  color: AppColors.cyan,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'HeadMouse Pro · Acceso seguro e inclusivo',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.mono(fontSize: 10),
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
