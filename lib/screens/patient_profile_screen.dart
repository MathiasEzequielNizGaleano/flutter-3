import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/profile_parts.dart';
import '../widgets/record_sections.dart';
import '../widgets/screen_title.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';
import 'patient_data_form_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final String _uid = AuthService.instance.currentUid ?? '';
  late Stream<PatientRecord> _record;
  late Stream<ManagedUser> _account;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  void _watch() {
    _record = RecordsService.instance.watchPatient(_uid);
    _account = RecordsService.instance.watchAccount(_uid);
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Future<void> _editContact(PatientRecord record, String name) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PatientDataFormScreen(
          patientUid: _uid,
          patientName: name,
          record: record,
          selfEdit: true,
        ),
      ),
    );
    if (message != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: StreamBuilder<PatientRecord>(
          stream: _record,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(
                onRetry: () => setState(_watch),
                message: AuthService.describeError(snapshot.error!),
              );
            }
            if (!snapshot.hasData) return const LoadingView();
            return _buildBody(snapshot.data!);
          },
        ),
      ),
      bottomNavigationBar: patientBottomNav(PatientTab.perfil),
    );
  }

  Widget _buildBody(PatientRecord record) {
    return StreamBuilder<ManagedUser>(
      stream: _account,
      builder: (context, snapshot) {
        final account = snapshot.data;
        final name =
            account?.fullName ?? AuthService.instance.current?.fullName ?? '';
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenTitle('Mi perfil'),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  spacing: 8,
                  children: [
                    InitialsAvatar(initialsOf(name), size: 64),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.display(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const StatusBadge(text: 'Paciente'),
                  ],
                ),
              ),
              PatientRecordSections(record: record, account: account),
              const SizedBox(height: 8),
              Text(
                'Tu estado funcional y tus diagnósticos los registra tu '
                'cuidador. Vos podés actualizar tu teléfono, dirección y '
                'contacto de emergencia.',
                style: AppTextStyles.body(
                  fontSize: 10.5,
                  color: AppColors.textMute,
                ),
              ),
              if (account != null) AccountSection(account: account),
              const SecuritySection(),
              const SizedBox(height: 16),
              GhostButton(
                'Editar mis datos de contacto',
                onPressed: () => _editContact(record, name),
              ),
              const ChangePasswordButton(),
              GhostButton(
                'Política de privacidad',
                onPressed: () => _push(const PrivacyPolicyScreen()),
              ),
              GhostButton(
                'Términos y Condiciones',
                onPressed: () => _push(const TermsScreen()),
              ),
              const ThemeToggleTile(),
              const LogoutButton(),
            ],
          ),
        );
      },
    );
  }
}
