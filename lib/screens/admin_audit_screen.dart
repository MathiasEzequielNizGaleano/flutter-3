import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/filter_chips.dart';
import '../widgets/state_views.dart';

class _AuditEntry {
  const _AuditEntry({
    required this.category,
    required this.user,
    required this.time,
    required this.action,
    required this.metaLeft,
    required this.metaRight,
    this.warn = false,
  });

  final String category;
  final String user;
  final String time;
  final String action;
  final String metaLeft;
  final String metaRight;
  final bool warn;
}

const _auditLog = [
  _AuditEntry(
    category: 'Planes y pagos',
    user: 'admin_root',
    time: 'Hoy 10:20',
    action: 'Renovó el Plan Premium de Juan Paredes (#0231) hasta el 30 oct',
    metaLeft: 'Rol: Administrador',
    metaRight: 'Pago: Transferencia',
  ),
  _AuditEntry(
    category: 'Planes y pagos',
    user: 'admin_root',
    time: 'Hoy 09:40',
    action: 'Modificó la tarifa Premium B2C: Gs. 180.000 → Gs. 200.000',
    metaLeft: 'Rol: Administrador',
    metaRight: 'Sección: Tarifas',
  ),
  _AuditEntry(
    category: 'Planes y pagos',
    user: 'Sistema',
    time: '12 sep 00:00',
    action:
        'Plan Premium vencido de Ana Torres (#0045): personalización y soporte '
        'prioritario deshabilitados',
    metaLeft: 'Resultado: Plan básico',
    metaRight: 'Automático',
    warn: true,
  ),
  _AuditEntry(
    category: 'Login',
    user: 'María González',
    time: 'Hoy 09:12',
    action: 'Inició sesión (login exitoso)',
    metaLeft: 'Rol: Cuidador',
    metaRight: 'IP: 190.x.x.24',
  ),
  _AuditEntry(
    category: 'Calibración',
    user: 'Marcos Rojas',
    time: 'Hoy 09:15',
    action: 'Calibración manual registrada — motivo: recolocación',
    metaLeft: 'Rol: Paciente',
    metaRight: 'Dispositivo: AA:BB:CC:DD:EE:FF',
  ),
  _AuditEntry(
    category: 'Fallidos',
    user: 'usuario_desconocido',
    time: 'Hoy 08:47',
    action: 'Intento fallido de inicio de sesión (MFA incorrecto)',
    metaLeft: 'Resultado: Fallido',
    metaRight: 'IP: 201.x.x.88',
    warn: true,
  ),
  _AuditEntry(
    category: 'Cambios de datos',
    user: 'Ana Duarte',
    time: 'Ayer 18:30',
    action: 'Actualizó datos personales de Lucía Fernández',
    metaLeft: 'Rol: Cuidador',
    metaRight: 'Campo: teléfono',
  ),
  _AuditEntry(
    category: 'Cambios de datos',
    user: 'admin_root',
    time: 'Ayer 14:02',
    action: 'Asignó dispositivo HeadMouse Pro a Juan Paredes',
    metaLeft: 'Rol: Administrador',
    metaRight: 'Dispositivo: 11:22:33:44:55:66',
  ),
  _AuditEntry(
    category: 'Fallidos',
    user: 'Marcos Rojas',
    time: 'Ayer 10:05',
    action: 'Bloqueo automático tras 5 intentos fallidos',
    metaLeft: 'Resultado: Cuenta bloqueada',
    metaRight: 'Reactivada por admin',
    warn: true,
  ),
];

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
        child: AsyncBody(
          loader: simulateFetch,
          builder: (context) => SingleChildScrollView(
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
                if (!_auditLog.any(
                  (entry) => _filter == 'Todos' || entry.category == _filter,
                ))
                  const EmptyState(
                    title: 'Sin registros',
                    message: 'No hay eventos de auditoría para este filtro.',
                    icon: Icons.fact_check_outlined,
                  ),
                for (final entry in _auditLog.where(
                  (entry) => _filter == 'Todos' || entry.category == _filter,
                ))
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: entry.warn
                          ? AppColors.amber.withValues(alpha: 0.06)
                          : AppColors.overlay,
                      border: Border.all(
                        color: entry.warn
                            ? AppColors.amber.withValues(alpha: 0.4)
                            : AppColors.line,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 12,
                          children: [
                            Flexible(
                              child: Text(
                                entry.user,
                                style: AppTextStyles.body(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                entry.time,
                                textAlign: TextAlign.right,
                                style: AppTextStyles.mono(
                                  fontSize: 10,
                                  color: AppColors.textMute,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          entry.action,
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: AppColors.text,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 12,
                          children: [
                            Flexible(
                              child: Text(
                                entry.metaLeft,
                                style: AppTextStyles.body(
                                  fontSize: 10.5,
                                  color: AppColors.textMute,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                entry.metaRight,
                                textAlign: TextAlign.right,
                                style: AppTextStyles.body(
                                  fontSize: 10.5,
                                  color: AppColors.textMute,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: adminNavItems(),
        currentIndex: 3,
      ),
    );
  }
}
