import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/diagnosis_card.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/profile_parts.dart';
import '../widgets/record_sections.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';
import 'device_history_screen.dart';
import 'diagnosis_edit_screen.dart';
import 'evaluation_history_screen.dart';
import 'functional_state_form_screen.dart';
import 'patient_data_form_screen.dart';

/// Ficha completa de un paciente: datos personales, estado funcional,
/// diagnósticos y cuenta. La abren su cuidador y el administrador; con
/// [canEdit] (permiso "editar datos") también se puede cargar información.
class PatientRecordScreen extends StatefulWidget {
  const PatientRecordScreen({
    super.key,
    required this.patientUid,
    required this.patientName,
    required this.canEdit,
    this.subtitle,
    this.navItems,
    this.currentIndex = 0,
  });

  final String patientUid;
  final String patientName;
  final bool canEdit;

  /// Por ejemplo, la relación con el cuidador ("Madre · Principal").
  final String? subtitle;
  final List<AppNavItem>? navItems;
  final int currentIndex;

  @override
  State<PatientRecordScreen> createState() => _PatientRecordScreenState();
}

class _PatientRecordScreenState extends State<PatientRecordScreen> {
  RecordsService get _service => RecordsService.instance;
  late Stream<PatientRecord> _record;
  late Stream<ManagedUser> _account;
  late Stream<List<Diagnosis>> _diagnoses;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  void _watch() {
    _record = _service.watchPatient(widget.patientUid);
    _account = _service.watchAccount(widget.patientUid);
    _diagnoses = _service.watchDiagnoses(widget.patientUid);
  }

  Future<void> _open(Widget screen) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (message != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _openDiagnosis(Diagnosis diagnosis) => _open(
    DiagnosisEditScreen(
      diagnosis: diagnosis,
      patientName: widget.patientName,
      readOnly: !widget.canEdit,
      navItems: widget.navItems,
      currentIndex: widget.currentIndex,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final nav = widget.navItems;
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          'Ficha del paciente',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<PatientRecord>(
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
      bottomNavigationBar: nav == null
          ? null
          : AppBottomNav(items: nav, currentIndex: widget.currentIndex),
    );
  }

  Widget _buildBody(PatientRecord record) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: StreamBuilder<ManagedUser>(
        stream: _account,
        builder: (context, accountSnap) {
          final account = accountSnap.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  spacing: 8,
                  children: [
                    InitialsAvatar(initialsOf(widget.patientName), size: 56),
                    Text(
                      widget.patientName,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.display(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.subtitle != null)
                      StatusBadge(
                        text: widget.subtitle!,
                        tone: StatusBadgeTone.warn,
                      ),
                  ],
                ),
              ),
              if (widget.canEdit) ...[
                const SizedBox(height: 16),
                GhostButton(
                  'Editar datos personales',
                  onPressed: () => _open(
                    PatientDataFormScreen(
                      patientUid: widget.patientUid,
                      patientName: widget.patientName,
                      record: record,
                    ),
                  ),
                ),
                GhostButton(
                  record.estadoFuncional == null
                      ? 'Registrar estado funcional'
                      : 'Actualizar estado funcional',
                  onPressed: () => _open(
                    FunctionalStateFormScreen(
                      patientUid: widget.patientUid,
                      patientName: widget.patientName,
                      current: record.estadoFuncional,
                    ),
                  ),
                ),
              ],
              PatientRecordSections(record: record, account: account),
              if (record.estadoFuncional != null) ...[
                const SizedBox(height: 10),
                GhostButton(
                  'Evaluaciones anteriores',
                  onPressed: () => _open(
                    EvaluationHistoryScreen(
                      patientUid: widget.patientUid,
                      patientName: widget.patientName,
                    ),
                  ),
                ),
              ],
              const ProfileSectionTitle('HeadMouse Pro'),
              GhostButton(
                'Configuraciones y calibraciones',
                onPressed: () => _open(
                  DeviceHistoryScreen(
                    patientUid: widget.patientUid,
                    patientName: widget.patientName,
                  ),
                ),
              ),
              _DiagnosesSection(
                stream: _diagnoses,
                canEdit: widget.canEdit,
                onOpen: _openDiagnosis,
                onAdd: () => _openDiagnosis(
                  Diagnosis(
                    idPaciente: widget.patientUid,
                    tipo: DiagnosisType.principal,
                    diagnostico: '',
                  ),
                ),
              ),
              if (account != null)
                AccountSection(account: account, title: 'Cuenta del paciente'),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

class _DiagnosesSection extends StatelessWidget {
  const _DiagnosesSection({
    required this.stream,
    required this.canEdit,
    required this.onOpen,
    required this.onAdd,
  });

  final Stream<List<Diagnosis>> stream;
  final bool canEdit;
  final ValueChanged<Diagnosis> onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProfileSectionTitle('Diagnósticos'),
        StreamBuilder<List<Diagnosis>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                AuthService.describeError(snapshot.error!),
                style: AppTextStyles.body(fontSize: 12, color: AppColors.coral),
              );
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final list = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (list.isEmpty)
                  const EmptyState(
                    title: 'Sin diagnósticos',
                    message: 'Todavía no se registró ningún diagnóstico.',
                    icon: Icons.medical_information_outlined,
                  ),
                for (final d in list)
                  DiagnosisCard(diagnosis: d, onTap: () => onOpen(d)),
              ],
            );
          },
        ),
        if (canEdit) GhostButton('+ Registrar diagnóstico', onPressed: onAdd),
      ],
    );
  }
}
