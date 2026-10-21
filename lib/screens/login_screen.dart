import 'package:flutter/material.dart';
import 'package:headmouse_pro/theme/app_text_styles.dart';
import 'package:headmouse_pro/theme/app_colors.dart';
import 'package:headmouse_pro/screens/admin_panel_screen.dart';
import 'package:headmouse_pro/screens/caregiver_patients_screen.dart';
import 'package:headmouse_pro/screens/patient_home_screen.dart';
import 'package:headmouse_pro/screens/privacy_policy_screen.dart';
import 'package:headmouse_pro/screens/terms_screen.dart';
import 'package:headmouse_pro/widgets/terms_acceptance.dart';
import 'package:headmouse_pro/screens/register_screen.dart';
import 'package:headmouse_pro/widgets/role_selector.dart';
import 'package:headmouse_pro/widgets/recaptcha_placeholder.dart';
import 'package:headmouse_pro/theme/app_input_decoration.dart';
import 'package:headmouse_pro/l10n/app_strings.dart';
import 'package:headmouse_pro/utils/validators.dart';

const _loginRoles = [
  RoleOption(label: 'Paciente', icon: Icons.accessibility_new),
  RoleOption(label: 'Cuidador / tutor', icon: Icons.favorite_border_outlined),
  RoleOption(label: 'Administrador', icon: Icons.shield_outlined),
];

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
  String _selectedRole = _loginRoles.first.label;

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

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() {
      _isLoggingIn = false;
    });

    final Widget destination = switch (_selectedRole) {
      'Cuidador / tutor' => const CaregiverPatientsScreen(),
      'Administrador' => const AdminPanelScreen(),
      _ => const PatientHomeScreen(),
    };

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => destination),
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
                        RoleSelector(
                          label: AppStrings.loginAs,
                          roles: _loginRoles,
                          selectedRole: _selectedRole,
                          onChanged: (role) {
                            setState(() => _selectedRole = role);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _userController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          validator: Validators.userOrEmail,
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
                            if (_acceptedTerms && !_isLoggingIn) _handleLogin();
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
                        const RecaptchaPlaceholder(),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [AppColors.cyanAccent, AppColors.cyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: _acceptedTerms
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
                            onPressed: _acceptedTerms && !_isLoggingIn
                                ? _handleLogin
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
                                        color: _acceptedTerms
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
