import 'package:flutter/material.dart';

import '../ble/headmouse_ble.dart';
import '../navigation/nav_items.dart';
import '../services/auth_service.dart';
import '../services/care_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/screen_title.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';
import 'caregiver_detail_screen.dart';

class PatientCaregiversScreen extends StatefulWidget {
  const PatientCaregiversScreen({super.key});

  @override
  State<PatientCaregiversScreen> createState() =>
      _PatientCaregiversScreenState();
}

class _PatientCaregiversScreenState extends State<PatientCaregiversScreen> {
  late Stream<List<CareAssignment>> _caregivers = _watch();

  Stream<List<CareAssignment>> _watch() => CareService.instance.watchForPatient(
    AuthService.instance.currentUid ?? '',
  );

  Future<void> _open(CareAssignment a) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => CaregiverDetailScreen(assignment: a),
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
        child: StreamBuilder<List<CareAssignment>>(
          stream: _caregivers,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(
                onRetry: () => setState(() => _caregivers = _watch()),
                message: AuthService.describeError(snapshot.error!),
              );
            }
            if (!snapshot.hasData) return const LoadingView();
            return _buildBody(snapshot.data!);
          },
        ),
      ),
      bottomNavigationBar: patientBottomNav(PatientTab.cuidadores),
    );
  }

  Widget _buildBody(List<CareAssignment> caregivers) {
    int count(bool Function(CarePermissions) test) =>
        caregivers.where((a) => test(a.permisos)).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenTitle('Mis cuidadores'),
          const SizedBox(height: 18),
          if (caregivers.isEmpty)
            const EmptyState(
              title: 'No tenés cuidadores asignados',
              message:
                  'El administrador es quien asigna a tus cuidadores y los '
                  'permisos que tiene cada uno.',
              icon: Icons.people_outline,
            ),
          for (final a in caregivers)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: glassCardDecoration(radius: 14),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _open(a),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    child: Row(
                      spacing: 12,
                      children: [
                        InitialsAvatar(initialsOf(a.nombreCuidador)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 2,
                            children: [
                              Text(
                                a.nombreCuidador,
                                style: AppTextStyles.body(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                a.relation,
                                style: AppTextStyles.body(
                                  fontSize: 11,
                                  color: AppColors.textMute,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: AppColors.textMute,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'MI DISPOSITIVO',
            style: AppTextStyles.mono(fontSize: 11, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          const _DeviceCard(),
          const SizedBox(height: 18),
          Text(
            'RESUMEN',
            style: AppTextStyles.mono(fontSize: 11, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: glassCardDecoration(),
            child: Column(
              spacing: 9,
              children: [
                _SummaryRow(
                  label: 'Cuidadores asignados',
                  value: '${caregivers.length}',
                ),
                _SummaryRow(
                  label: 'Pueden configurar',
                  value: '${count((p) => p.configurar)}',
                ),
                _SummaryRow(
                  label: 'Pueden calibrar',
                  value: '${count((p) => p.calibrar)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado real del HeadMouse conectado por Bluetooth en esta sesión.
class _DeviceCard extends StatelessWidget {
  const _DeviceCard();

  @override
  Widget build(BuildContext context) {
    final ble = HeadMouseBle.instance;
    return ListenableBuilder(
      listenable: ble,
      builder: (context, _) {
        final connected = ble.isConnected;
        final last = ble.lastCalibration;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: glassCardDecoration(radius: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Icon(
                Icons.memory,
                color: connected ? AppColors.cyan : AppColors.textMute,
                size: 18,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      spacing: 8,
                      children: [
                        Flexible(
                          child: Text(
                            ble.deviceName ?? headMouseAdvName,
                            style: AppTextStyles.body(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        StatusBadge(
                          text: connected ? 'Conectado' : 'Sin conexión',
                          tone: connected
                              ? StatusBadgeTone.ok
                              : StatusBadgeTone.mute,
                        ),
                      ],
                    ),
                    if (ble.mac != null)
                      Text(ble.mac!, style: AppTextStyles.mono(fontSize: 11)),
                    Text(
                      last == null
                          ? 'Sin calibraciones en esta sesión'
                          : 'Última calibración: ${formatEventTime(last)}',
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
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.body(fontSize: 12, color: AppColors.textMute),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTextStyles.mono(fontSize: 13, color: AppColors.text),
          ),
        ),
      ],
    );
  }
}
