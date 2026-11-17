import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../services/auth_service.dart';
import '../services/care_service.dart';
import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/diagnosis_card.dart';
import '../widgets/filter_chips.dart';
import '../widgets/gradient_button.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/screen_title.dart';
import '../widgets/state_views.dart';
import 'diagnosis_edit_screen.dart';

const _all = 'Todos';

/// Diagnósticos de los pacientes del cuidador. Solo aparecen los pacientes
/// que le dan permiso para ver sus datos; solo carga o corrige donde tiene
/// permiso para editarlos.
class CaregiverDiagnosesScreen extends StatefulWidget {
  const CaregiverDiagnosesScreen({super.key});

  @override
  State<CaregiverDiagnosesScreen> createState() =>
      _CaregiverDiagnosesScreenState();
}

class _CaregiverDiagnosesScreenState extends State<CaregiverDiagnosesScreen> {
  late Stream<List<CareAssignment>> _links = _watchLinks();
  Stream<List<Diagnosis>>? _diagnoses;
  List<String> _watchedUids = const [];
  String _filter = _all;

  Stream<List<CareAssignment>> _watchLinks() => CareService.instance
      .watchForCaregiver(AuthService.instance.currentUid ?? '');

  /// Vuelve a escuchar los diagnósticos solo si cambian los pacientes.
  Stream<List<Diagnosis>> _diagnosesOf(List<String> uids) {
    if (_diagnoses == null || !listEquals(uids, _watchedUids)) {
      _watchedUids = uids;
      _diagnoses = RecordsService.instance.watchDiagnosesFor(uids);
    }
    return _diagnoses!;
  }

  void _retry() => setState(() {
    _links = _watchLinks();
    _diagnoses = null;
  });

  Future<void> _open(Diagnosis diagnosis, CareAssignment link) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => DiagnosisEditScreen(
          diagnosis: diagnosis,
          patientName: link.nombrePaciente,
          readOnly: !link.permisos.editarDatos,
          navItems: caregiverNavItems(),
          currentIndex: 1,
        ),
      ),
    );
    if (message != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _addNew(List<CareAssignment> editable) async {
    CareAssignment? link;
    final selected = editable.where((l) => l.nombrePaciente == _filter);
    if (selected.isNotEmpty) {
      link = selected.first;
    } else if (editable.length == 1) {
      link = editable.single;
    } else {
      link = await _choosePatient(editable);
    }
    if (link == null || !mounted) return;
    await _open(
      Diagnosis(
        idPaciente: link.idPaciente,
        tipo: DiagnosisType.principal,
        diagnostico: '',
      ),
      link,
    );
  }

  Future<CareAssignment?> _choosePatient(List<CareAssignment> editable) {
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
                '¿A qué paciente?',
                style: AppTextStyles.display(fontSize: 16),
              ),
            ),
            for (final link in editable)
              ListTile(
                leading: InitialsAvatar(
                  initialsOf(link.nombrePaciente),
                  size: 36,
                ),
                title: Text(
                  link.nombrePaciente,
                  style: AppTextStyles.body(fontSize: 13.5),
                ),
                onTap: () => Navigator.pop(context, link),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: StreamBuilder<List<CareAssignment>>(
          stream: _links,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(
                onRetry: _retry,
                message: AuthService.describeError(snapshot.error!),
              );
            }
            if (!snapshot.hasData) return const LoadingView();
            return _buildForLinks(snapshot.data!);
          },
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: caregiverNavItems(),
        currentIndex: 1,
      ),
    );
  }

  Widget _buildForLinks(List<CareAssignment> links) {
    final visible = links.where((l) => l.permisos.verDatos).toList();
    if (visible.isEmpty) {
      return _Frame(
        children: [
          EmptyState(
            title: links.isEmpty
                ? 'Todavía no tenés pacientes'
                : 'Sin permiso para ver datos',
            message: links.isEmpty
                ? 'Cuando el administrador te asigne un paciente, vas a ver '
                      'sus diagnósticos acá.'
                : 'Ninguno de tus pacientes te dio permiso para ver sus '
                      'datos. Pedíselo al administrador.',
            icon: Icons.medical_information_outlined,
          ),
        ],
      );
    }
    return StreamBuilder<List<Diagnosis>>(
      stream: _diagnosesOf([for (final l in visible) l.idPaciente]),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(
            onRetry: _retry,
            message: AuthService.describeError(snapshot.error!),
          );
        }
        if (!snapshot.hasData) return const LoadingView();
        return _buildList(visible, snapshot.data!);
      },
    );
  }

  Widget _buildList(List<CareAssignment> links, List<Diagnosis> diagnoses) {
    final byPatient = {for (final l in links) l.idPaciente: l};
    final editable = links.where((l) => l.permisos.editarDatos).toList();
    final names = [for (final l in links) l.nombrePaciente];
    final filter = names.contains(_filter) ? _filter : _all;
    final shown = diagnoses.where((d) {
      if (d.anulado) return false;
      return filter == _all ||
          byPatient[d.idPaciente]?.nombrePaciente == filter;
    }).toList();

    return _Frame(
      children: [
        GradientButton(
          label: '+ Nuevo diagnóstico',
          onPressed: editable.isEmpty ? null : () => _addNew(editable),
        ),
        if (editable.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Para registrar diagnósticos necesitás el permiso "editar '
              'datos" del paciente. Lo otorga el administrador.',
              style: AppTextStyles.body(
                fontSize: 11,
                color: AppColors.textMute,
              ),
            ),
          ),
        const SizedBox(height: 14),
        if (links.length > 1) ...[
          FilterChips(
            options: [_all, ...names],
            selected: filter,
            onChanged: (chip) => setState(() => _filter = chip),
          ),
          const SizedBox(height: 14),
        ],
        if (shown.isEmpty)
          const EmptyState(
            title: 'Sin diagnósticos',
            message: 'Todavía no hay diagnósticos registrados.',
            icon: Icons.medical_information_outlined,
          ),
        for (final d in shown)
          DiagnosisCard(
            diagnosis: d,
            patientName: byPatient[d.idPaciente]?.nombrePaciente,
            onTap: () => _open(d, byPatient[d.idPaciente]!),
          ),
      ],
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenTitle('Diagnósticos'),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}
