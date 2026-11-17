import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/audit_event_card.dart';
import '../widgets/filter_chips.dart';
import '../widgets/state_views.dart';

const _filters = ['Todos', 'Ingresos', 'Fallidos'];

/// Historial de ingresos de una cuenta: inicios y cierres de sesión,
/// códigos de verificación y cierres desde otro dispositivo. Lo ve la
/// persona, su cuidador y el administrador.
class AccessHistoryScreen extends StatefulWidget {
  const AccessHistoryScreen({super.key, required this.uid, this.name});

  final String uid;

  /// Nombre de la cuenta si no es la propia.
  final String? name;

  @override
  State<AccessHistoryScreen> createState() => _AccessHistoryScreenState();
}

class _AccessHistoryScreenState extends State<AccessHistoryScreen> {
  String _filter = _filters.first;
  late Stream<List<AuditEvent>> _events = _watch();

  Stream<List<AuditEvent>> _watch() =>
      SessionService.instance.watchAccesses(widget.uid);

  bool _matches(AuditEvent e) => switch (_filter) {
    'Ingresos' => e.action == 'Inició sesión',
    'Fallidos' => e.failed,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final name = widget.name;
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          'Historial de ingresos',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<AuditEvent>>(
          stream: _events,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(
                onRetry: () => setState(() => _events = _watch()),
                message: AuthService.describeError(snapshot.error!),
              );
            }
            if (!snapshot.hasData) return const LoadingView();
            final all = snapshot.data!;
            final visible = all.where(_matches).toList();
            final failed = all.where((e) => e.failed).length;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        name,
                        style: AppTextStyles.body(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    failed == 0
                        ? 'Últimos ${all.length} registros. Ningún intento '
                              'fallido.'
                        : 'Últimos ${all.length} registros. $failed '
                              '${failed == 1 ? 'intento fallido' : 'intentos fallidos'}.',
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.textMute,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilterChips(
                    options: _filters,
                    selected: _filter,
                    onChanged: (chip) => setState(() => _filter = chip),
                  ),
                  const SizedBox(height: 14),
                  if (visible.isEmpty)
                    const EmptyState(
                      title: 'Sin registros',
                      message: 'No hay ingresos para este filtro.',
                      icon: Icons.history,
                    ),
                  for (final event in visible)
                    AuditEventCard(event, showActor: false),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
