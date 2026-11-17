import 'package:flutter/material.dart';

import '../ble/headmouse_ble.dart';
import '../navigation/nav_items.dart';
import '../services/auth_service.dart';
import '../services/care_service.dart';
import '../services/device_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/gradient_button.dart';
import '../widgets/info_card.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/profile_parts.dart';
import '../widgets/screen_title.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';
import 'device_ble_scan_screen.dart';
import 'device_pause_cursor_screen.dart';
import 'device_settings_screen.dart';
import 'patient_record_screen.dart';
import 'patient_register_screen.dart';

class CaregiverPatientsScreen extends StatefulWidget {
  const CaregiverPatientsScreen({super.key});

  @override
  State<CaregiverPatientsScreen> createState() =>
      _CaregiverPatientsScreenState();
}

class _CaregiverPatientsScreenState extends State<CaregiverPatientsScreen> {
  late Stream<List<CareAssignment>> _patients = _watch();

  Stream<List<CareAssignment>> _watch() => CareService.instance
      .watchForCaregiver(AuthService.instance.currentUid ?? '');

  /// Antes de conectar, el cuidador elige con qué paciente trabaja: así
  /// cada configuración y calibración queda en el historial correcto y se
  /// respetan sus permisos.
  Future<void> _openDevice(List<CareAssignment> patients) async {
    final usable = patients
        .where((a) => a.permisos.configurar || a.permisos.calibrar)
        .toList();
    if (usable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No tenés permiso para configurar ni calibrar el HeadMouse de '
            'ningún paciente.',
          ),
        ),
      );
      return;
    }
    final chosen = usable.length == 1
        ? usable.single
        : await _choosePatient(usable);
    if (chosen == null || !mounted) return;
    DeviceService.selectPatient(DevicePatient.fromAssignment(chosen));
    _pushDevice();
  }

  Future<CareAssignment?> _choosePatient(List<CareAssignment> usable) {
    return showModalBottomSheet<CareAssignment>(
      context: context,
      backgroundColor: AppColors.bgPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                '¿Con qué paciente vas a usar el HeadMouse?',
                style: AppTextStyles.display(fontSize: 15),
              ),
            ),
            for (final a in usable)
              ListTile(
                leading: InitialsAvatar(initialsOf(a.nombrePaciente), size: 36),
                title: Text(
                  a.nombrePaciente,
                  style: AppTextStyles.body(fontSize: 13.5),
                ),
                subtitle: Text(
                  a.permisos.summary,
                  style: AppTextStyles.body(
                    fontSize: 11,
                    color: AppColors.textMute,
                  ),
                ),
                onTap: () => Navigator.pop(context, a),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _registerPatient() async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PatientRegisterScreen()),
    );
    if (message != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _pushDevice() {
    final ble = HeadMouseBle.instance;
    final Widget next = !ble.isConnected
        ? const DeviceBleScanScreen(showPatientNav: false)
        : ble.configMode
        ? const DeviceSettingsScreen(showPatientNav: false)
        : const DevicePauseCursorScreen(showPatientNav: false);
    Navigator.push(context, MaterialPageRoute(builder: (context) => next));
  }

  void _showPatient(CareAssignment a) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PatientSheet(assignment: a),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: StreamBuilder<List<CareAssignment>>(
          stream: _patients,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(
                onRetry: () => setState(() => _patients = _watch()),
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
        currentIndex: 0,
      ),
    );
  }

  Widget _buildBody(List<CareAssignment> patients) {
    int count(bool Function(CarePermissions) test) =>
        patients.where((a) => test(a.permisos)).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenTitle('Mis pacientes'),
          const SizedBox(height: 18),
          if (patients.isEmpty)
            const EmptyState(
              title: 'Todavía no tenés pacientes',
              message:
                  'El administrador te vincula con cada paciente, o podés '
                  'registrar uno nuevo con el botón de abajo.',
              icon: Icons.people_outline,
            ),
          for (final a in patients)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: glassCardDecoration(radius: 14),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showPatient(a),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
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
          GhostButton('+ Registrar paciente', onPressed: _registerPatient),
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
                  label: 'Pacientes asignados',
                  value: '${patients.length}',
                ),
                _SummaryRow(
                  label: 'Podés configurar',
                  value: '${count((p) => p.configurar)}',
                ),
                _SummaryRow(
                  label: 'Podés calibrar',
                  value: '${count((p) => p.calibrar)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openDevice(patients),
              icon: Icon(Icons.bluetooth, color: AppColors.cyan),
              label: Text(
                'Conectar HeadMouse Pro',
                style: AppTextStyles.body(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.line, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientSheet extends StatelessWidget {
  const _PatientSheet({required this.assignment});

  final CareAssignment assignment;

  InfoRow _permission(String label, bool granted) => InfoRow(
    label,
    trailing: StatusBadge(
      text: granted ? 'Sí' : 'No',
      tone: granted ? StatusBadgeTone.ok : StatusBadgeTone.mute,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            Row(
              spacing: 12,
              children: [
                InitialsAvatar(initialsOf(a.nombrePaciente), size: 52),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        a.nombrePaciente,
                        style: AppTextStyles.display(fontSize: 16),
                      ),
                      Text(
                        a.relation,
                        style: AppTextStyles.body(
                          fontSize: 11.5,
                          color: AppColors.textMute,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            InfoCard(
              rows: [
                InfoRow(
                  'Parentesco',
                  value: a.parentesco.isEmpty ? '—' : a.parentesco,
                ),
                InfoRow('Responsabilidad', value: a.responsabilidad.label),
                InfoRow(
                  'Asignado desde',
                  value: a.fechaAsignacion == null
                      ? '—'
                      : formatShortDate(a.fechaAsignacion!),
                ),
              ],
            ),
            Text(
              'LO QUE PODÉS HACER',
              style: AppTextStyles.mono(fontSize: 11, letterSpacing: 0.8),
            ),
            InfoCard(
              rows: [
                _permission('Ver sus datos', a.permisos.verDatos),
                _permission('Editar sus datos', a.permisos.editarDatos),
                _permission('Configurar el HeadMouse', a.permisos.configurar),
                _permission('Calibrar el HeadMouse', a.permisos.calibrar),
              ],
            ),
            if (a.permisos.verDatos)
              GradientButton(
                label: 'Ver ficha completa',
                onPressed: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  navigator.push(
                    MaterialPageRoute(
                      builder: (_) => PatientRecordScreen(
                        patientUid: a.idPaciente,
                        patientName: a.nombrePaciente,
                        canEdit: a.permisos.editarDatos,
                        subtitle: a.relation,
                        navItems: caregiverNavItems(),
                      ),
                    ),
                  );
                },
              )
            else
              Text(
                'No tenés permiso para ver la ficha de este paciente. Lo '
                'otorga el administrador.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  fontSize: 11.5,
                  color: AppColors.textMute,
                ),
              ),
          ],
        ),
      ),
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
