import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/info_card.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/profile_parts.dart';
import '../widgets/record_sections.dart';
import '../widgets/screen_title.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';
import 'admin_user_form_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  late Stream<ManagedUser> _account = _watch();

  Stream<ManagedUser> _watch() => RecordsService.instance.watchAccount(
    AuthService.instance.currentUid ?? '',
  );

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Future<void> _edit(ManagedUser account) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => AdminUserFormScreen(user: account)),
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
        child: StreamBuilder<ManagedUser>(
          stream: _account,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(
                onRetry: () => setState(() => _account = _watch()),
                message: AuthService.describeError(snapshot.error!),
              );
            }
            if (!snapshot.hasData) return const LoadingView();
            return _buildBody(snapshot.data!);
          },
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: adminNavItems(),
        currentIndex: 4,
      ),
    );
  }

  Widget _buildBody(ManagedUser account) {
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
                InitialsAvatar(account.initials, size: 64),
                Text(
                  account.fullName,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.display(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const StatusBadge(
                  text: 'Administrador',
                  tone: StatusBadgeTone.warn,
                ),
              ],
            ),
          ),
          const ProfileSectionTitle('Datos personales'),
          InfoCard(
            rows: [
              InfoRow('Nombre', value: orDash(account.fullName)),
              InfoRow('Documento', value: orDash(account.documento)),
            ],
          ),
          AccountSection(account: account),
          const SecuritySection(
            extraRows: [InfoRow('Rol', value: 'ADMINISTRADOR')],
          ),
          const SizedBox(height: 16),
          GhostButton(
            'Editar datos personales',
            onPressed: () => _edit(account),
          ),
          const ChangePasswordButton(),
          GhostButton(
            'Ir a Diagnósticos',
            onPressed: () => _push(adminNavItems()[2].builder(context)),
          ),
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
  }
}
