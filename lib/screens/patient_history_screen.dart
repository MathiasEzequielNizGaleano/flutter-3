import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/diagnosis_card.dart';
import '../widgets/filter_chips.dart';
import '../widgets/screen_title.dart';
import '../widgets/state_views.dart';
import 'diagnosis_edit_screen.dart';

const _all = 'Todos';

/// Historial clínico del paciente: sus diagnósticos, solo para consultar.
class PatientHistoryScreen extends StatefulWidget {
  const PatientHistoryScreen({
    super.key,
    required this.navItems,
    required this.currentIndex,
  });

  final List<AppNavItem> navItems;
  final int currentIndex;

  @override
  State<PatientHistoryScreen> createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen> {
  late Stream<List<Diagnosis>> _diagnoses = _watch();
  String _filter = _all;

  Stream<List<Diagnosis>> _watch() => RecordsService.instance.watchDiagnoses(
    AuthService.instance.currentUid ?? '',
  );

  void _open(Diagnosis diagnosis) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiagnosisEditScreen(
          diagnosis: diagnosis,
          patientName: AuthService.instance.current?.fullName ?? 'Yo',
          readOnly: true,
          navItems: widget.navItems,
          currentIndex: widget.currentIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: StreamBuilder<List<Diagnosis>>(
          stream: _diagnoses,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(
                onRetry: () => setState(() => _diagnoses = _watch()),
                message: AuthService.describeError(snapshot.error!),
              );
            }
            if (!snapshot.hasData) return const LoadingView();
            return _buildList(snapshot.data!);
          },
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: widget.navItems,
        currentIndex: widget.currentIndex,
      ),
    );
  }

  Widget _buildList(List<Diagnosis> diagnoses) {
    final valid = diagnoses.where((d) => !d.anulado);
    final shown = valid
        .where((d) => _filter == _all || d.tipo.label == _filter)
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenTitle('Historial clínico'),
          const SizedBox(height: 16),
          FilterChips(
            options: [_all, for (final t in DiagnosisType.values) t.label],
            selected: _filter,
            onChanged: (chip) => setState(() => _filter = chip),
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            EmptyState(
              title: 'Sin registros',
              message: valid.isEmpty
                  ? 'Tu cuidador todavía no registró diagnósticos.'
                  : 'No hay entradas de este tipo en tu historial.',
              icon: Icons.history,
            ),
          for (final d in shown)
            DiagnosisCard(diagnosis: d, onTap: () => _open(d)),
        ],
      ),
    );
  }
}
