import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/info_card.dart';
import '../widgets/profile_parts.dart';
import '../widgets/status_badge.dart';

class CaregiverInfo {
  const CaregiverInfo({
    required this.initials,
    required this.name,
    required this.role,
    required this.level,
    required this.since,
    required this.canView,
    required this.canEdit,
    required this.canConfigure,
    required this.canCalibrate,
  });

  final String initials;
  final String name;
  final String role;
  final String level;
  final String since;
  final bool canView;
  final bool canEdit;
  final bool canConfigure;
  final bool canCalibrate;
}

class CaregiverDetailScreen extends StatelessWidget {
  const CaregiverDetailScreen({super.key, required this.caregiver});

  final CaregiverInfo caregiver;

  InfoRow _permission(String label, bool granted) => InfoRow(
    label,
    trailing: StatusBadge(
      text: granted ? 'Sí' : 'No',
      tone: granted ? StatusBadgeTone.ok : StatusBadgeTone.warn,
    ),
  );

  Future<void> _confirmRemoval(BuildContext context) async {
    final firstName = caregiver.name.split(' ').first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.line),
        ),
        title: Text(
          '¿Quitar a ${caregiver.name} como tu cuidador?',
          style: AppTextStyles.display(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '$firstName perderá acceso a tus datos y ya no podrá configurar ni '
          'calibrar tu dispositivo. Esta acción no elimina su cuenta, solo '
          'termina su asignación como tu cuidador.',
          style: AppTextStyles.body(
            fontSize: 11.5,
            color: AppColors.textMute,
          ).copyWith(height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, true),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: AppColors.coral.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Sí, quitar acceso',
                style: AppTextStyles.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.coral,
                ),
              ),
            ),
          ),
          GhostButton('Cancelar', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${caregiver.name} quitado (demo, sin backend)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text('Cuidador', style: AppTextStyles.display(fontSize: 18)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  spacing: 8,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.violet, AppColors.cyan],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Text(
                        caregiver.initials,
                        style: AppTextStyles.display(
                          fontSize: 18,
                          color: AppColors.bgPanel2,
                        ),
                      ),
                    ),
                    Text(
                      caregiver.name,
                      style: AppTextStyles.display(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    StatusBadge(
                      text: '${caregiver.role} · ${caregiver.level}',
                      tone: StatusBadgeTone.warn,
                    ),
                  ],
                ),
              ),
              const ProfileSectionTitle('Permisos otorgados'),
              InfoCard(
                rows: [
                  _permission('Ver mis datos', caregiver.canView),
                  _permission('Editar mis datos', caregiver.canEdit),
                  _permission('Configurar dispositivo', caregiver.canConfigure),
                  _permission('Calibrar dispositivo', caregiver.canCalibrate),
                ],
              ),
              const ProfileSectionTitle('Asignación'),
              InfoCard(
                rows: [
                  InfoRow('Parentesco', value: caregiver.role),
                  InfoRow('Asignado desde', value: caregiver.since),
                  const InfoRow(
                    'Estado',
                    trailing: StatusBadge(text: 'Activo'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _confirmRemoval(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: AppColors.coral.withValues(alpha: 0.6),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Quitar cuidador',
                    style: AppTextStyles.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.coral,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: patientCaregiversNavItems(),
        currentIndex: 1,
      ),
    );
  }
}
