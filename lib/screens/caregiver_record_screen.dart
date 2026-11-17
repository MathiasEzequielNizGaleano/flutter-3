import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/profile_parts.dart';
import '../widgets/record_sections.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';
import 'caregiver_data_form_screen.dart';

/// Ficha de un cuidador vista por el administrador.
class CaregiverRecordScreen extends StatefulWidget {
  const CaregiverRecordScreen({super.key, required this.user});

  final ManagedUser user;

  @override
  State<CaregiverRecordScreen> createState() => _CaregiverRecordScreenState();
}

class _CaregiverRecordScreenState extends State<CaregiverRecordScreen> {
  late Stream<CaregiverRecord> _record = _watch();

  Stream<CaregiverRecord> _watch() =>
      RecordsService.instance.watchCaregiver(widget.user.uid);

  Future<void> _edit(CaregiverRecord record) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CaregiverDataFormScreen(
          caregiverUid: widget.user.uid,
          caregiverName: widget.user.fullName,
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
    final user = widget.user;
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          'Ficha del cuidador',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<CaregiverRecord>(
          stream: _record,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(
                onRetry: () => setState(() => _record = _watch()),
                message: AuthService.describeError(snapshot.error!),
              );
            }
            if (!snapshot.hasData) return const LoadingView();
            final record = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      spacing: 8,
                      children: [
                        InitialsAvatar(user.initials, size: 56),
                        Text(
                          user.fullName,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.display(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const StatusBadge(
                          text: 'Cuidador',
                          tone: StatusBadgeTone.warn,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GhostButton(
                    'Editar datos personales',
                    onPressed: () => _edit(record),
                  ),
                  CaregiverRecordSections(record: record, account: user),
                  AccountSection(account: user),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
