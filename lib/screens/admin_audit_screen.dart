import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/audit_event_card.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/filter_chips.dart';
import '../widgets/state_views.dart';

const _auditFilters = [
  'Todos',
  'Login',
  'Cambios de datos',
  'Calibración',
  'Planes y pagos',
  'Fallidos',
];

class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<AdminAuditScreen> {
  String _filter = 'Todos';
  late Stream<List<AuditEvent>> _log = AdminService.instance.watchAuditLog();

  bool _matches(AuditEvent entry) => switch (_filter) {
    'Todos' => true,
    'Fallidos' => entry.failed,
    _ => entry.category == _filter,
  };

  void _retry() {
    setState(() => _log = AdminService.instance.watchAuditLog());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          'Registros de auditoría',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<AuditEvent>>(
          stream: _log,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(
                onRetry: _retry,
                message: AuthService.describeError(snapshot.error!),
              );
            }
            if (!snapshot.hasData) return const LoadingView();
            final visible = snapshot.data!.where(_matches).toList();
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilterChips(
                    options: _auditFilters,
                    selected: _filter,
                    onChanged: (chip) => setState(() => _filter = chip),
                  ),
                  const SizedBox(height: 14),
                  if (visible.isEmpty)
                    const EmptyState(
                      title: 'Sin registros',
                      message: 'No hay eventos de auditoría para este filtro.',
                      icon: Icons.fact_check_outlined,
                    ),
                  for (final entry in visible) AuditEventCard(entry),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: adminNavItems(),
        currentIndex: 3,
      ),
    );
  }
}
