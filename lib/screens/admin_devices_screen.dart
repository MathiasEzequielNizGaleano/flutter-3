import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/filter_chips.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';
import 'admin_plans_screen.dart';
import 'device_form_screen.dart';

const _filters = ['Todos', 'Activos', 'Inactivos', 'Sin asignar'];

/// Equipos HeadMouse Pro: a qué paciente está asignado cada uno, su última
/// conexión, batería, sensor y calibración.
class AdminDevicesScreen extends StatefulWidget {
  const AdminDevicesScreen({super.key});

  @override
  State<AdminDevicesScreen> createState() => _AdminDevicesScreenState();
}

class _AdminDevicesScreenState extends State<AdminDevicesScreen> {
  late Stream<List<HeadMouseDevice>> _devices = _watch();
  String _filter = _filters.first;

  Stream<List<HeadMouseDevice>> _watch() =>
      DeviceService.instance.watchDevices();

  bool _matches(HeadMouseDevice d) => switch (_filter) {
    'Activos' => d.activo,
    'Inactivos' => !d.activo,
    'Sin asignar' => d.idPaciente == null,
    _ => true,
  };

  Future<void> _open([HeadMouseDevice? device]) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => DeviceFormScreen(device: device)),
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
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          'Estado de dispositivos',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        backgroundColor: AppColors.cyan,
        foregroundColor: AppColors.bgPanel2,
        icon: const Icon(Icons.add),
        label: Text(
          'Registrar',
          style: AppTextStyles.body(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.bgPanel2,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<HeadMouseDevice>>(
          stream: _devices,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(
                onRetry: () => setState(() => _devices = _watch()),
                message: AuthService.describeError(snapshot.error!),
              );
            }
            if (!snapshot.hasData) return const LoadingView();
            return _buildList(snapshot.data!);
          },
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: adminNavItems(),
        currentIndex: 0,
      ),
    );
  }

  Widget _buildList(List<HeadMouseDevice> devices) {
    final active = devices.where((d) => d.activo).length;
    final shown = devices.where(_matches).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
      child: Column(
        children: [
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: _StatCard(num: '${devices.length}', label: 'Total'),
              ),
              Expanded(
                child: _StatCard(num: '$active', label: 'Activos'),
              ),
              Expanded(
                child: _StatCard(
                  num: '${devices.length - active}',
                  label: 'Inactivos',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: glassCardDecoration(radius: 14),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminPlansScreen(),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Gestionar planes y tarifas',
                        style: AppTextStyles.body(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.cyan),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilterChips(
            options: _filters,
            selected: _filter,
            onChanged: (chip) => setState(() => _filter = chip),
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            EmptyState(
              title: 'No hay dispositivos',
              message: devices.isEmpty
                  ? 'Registrá cada HeadMouse Pro con su MAC para asignarlo a '
                        'un paciente y ver su estado.'
                  : 'Ningún dispositivo coincide con el filtro.',
              icon: Icons.memory,
            ),
          for (final device in shown)
            _DeviceTile(device: device, onTap: () => _open(device)),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onTap});

  final HeadMouseDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = device;
    final mute = AppTextStyles.body(fontSize: 11, color: AppColors.textMute);
    final last = d.ultimaConexion;
    final connection = last == null
        ? 'Nunca se conectó desde la app'
        : [
            '${d.conectado ? 'Conectado' : 'Última conexión'}: '
                '${formatEventTime(last)}',
            if (d.bateria != null) '${d.bateria} %',
            if (d.estadoSensor.isNotEmpty) 'MPU6050 ${d.estadoSensor}',
          ].join(' · ');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: glassCardDecoration(radius: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Icon(
                  Icons.memory,
                  color: d.activo ? AppColors.cyan : AppColors.textMute,
                  size: 18,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Row(
                        spacing: 8,
                        children: [
                          Expanded(
                            child: Text(
                              d.title,
                              style: AppTextStyles.body(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          StatusBadge(
                            text: d.activo ? 'Activo' : 'Inactivo',
                            tone: d.activo
                                ? StatusBadgeTone.ok
                                : StatusBadgeTone.warn,
                          ),
                        ],
                      ),
                      Text(
                        d.idPaciente == null
                            ? 'Sin paciente asignado'
                            : 'Paciente: ${d.nombrePaciente}',
                        style: mute,
                      ),
                      Text(
                        [
                          d.mac,
                          if (d.versionFirmware.isNotEmpty)
                            'FW ${d.versionFirmware}',
                        ].join(' · '),
                        style: AppTextStyles.mono(fontSize: 11),
                      ),
                      Text(connection, style: mute),
                      if (d.ultimaCalibracion != null)
                        Text(
                          'Última calibración: '
                          '${formatEventTime(d.ultimaCalibracion!)}',
                          style: mute,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.num, required this.label});

  final String num;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: glassCardDecoration(radius: 14),
      child: Column(
        children: [
          Text(num, style: AppTextStyles.display(fontSize: 20)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              fontSize: 10.5,
              color: AppColors.textMute,
            ),
          ),
        ],
      ),
    );
  }
}
