import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/care_service.dart';
import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/profile_parts.dart';
import '../widgets/record_sections.dart';
import '../widgets/screen_title.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';
import 'caregiver_data_form_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';

class CaregiverProfileScreen extends StatefulWidget {
  const CaregiverProfileScreen({super.key});

  @override
  State<CaregiverProfileScreen> createState() => _CaregiverProfileScreenState();
}

class _CaregiverProfileScreenState extends State<CaregiverProfileScreen> {
  final String _uid = AuthService.instance.currentUid ?? '';
  late Stream<CaregiverRecord> _record;
  late Stream<ManagedUser> _account;
  late Stream<List<CareAssignment>> _patients;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  void _watch() {
    _record = RecordsService.instance.watchCaregiver(_uid);
    _account = RecordsService.instance.watchAccount(_uid);
    _patients = CareService.instance.watchForCaregiver(_uid);
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Future<void> _edit(CaregiverRecord record, String name) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CaregiverDataFormScreen(
          caregiverUid: _uid,
          caregiverName: name,
          record: record,
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
        child: StreamBuilder<CaregiverRecord>(
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
      bottomNavigationBar: AppBottomNav(
        items: caregiverNavItems(),
        currentIndex: 4,
      ),
    );
  }

  Widget _buildBody(CaregiverRecord record) {
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
                    const StatusBadge(
                      text: 'Cuidador / tutor',
                      tone: StatusBadgeTone.warn,
                    ),
                  ],
                ),
              ),
              CaregiverRecordSections(record: record, account: account),
              const ProfileSectionTitle('Pacientes a cargo'),
              _PatientsList(stream: _patients),
              if (account != null) AccountSection(account: account),
              const SecuritySection(),
              const SizedBox(height: 16),
              GhostButton(
                'Editar datos personales',
                onPressed: () => _edit(record, name),
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

class _PatientsList extends StatelessWidget {
  const _PatientsList({required this.stream});

  final Stream<List<CareAssignment>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CareAssignment>>(
      stream: stream,
      builder: (context, snapshot) {
        final patients = snapshot.data;
        if (patients == null || patients.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: glassCardDecoration(radius: 14),
            child: Text(
              snapshot.hasError
                  ? AuthService.describeError(snapshot.error!)
                  : patients == null
                  ? 'Cargando…'
                  : 'Todavía no tenés pacientes asignados.',
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.textMute,
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final a in patients)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: glassCardDecoration(radius: 14),
                child: Row(
                  spacing: 12,
                  children: [
                    InitialsAvatar(initialsOf(a.nombrePaciente)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text(
                            a.nombrePaciente,
                            style: AppTextStyles.body(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${a.relation} · ${a.permisos.summary}',
                            style: AppTextStyles.body(
                              fontSize: 11,
                              color: AppColors.textMute,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
