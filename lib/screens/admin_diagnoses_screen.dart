import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/diagnosis_card.dart';
import '../widgets/filter_chips.dart';
import '../widgets/state_views.dart';
import 'diagnosis_edit_screen.dart';

const _filters = ['Todos', 'Vigentes', 'No vigentes', 'Anulados'];

/// Todos los diagnósticos, para supervisar quién cargó qué. Los anulados
/// también se ven: nunca se borran.
class AdminDiagnosesScreen extends StatefulWidget {
  const AdminDiagnosesScreen({super.key});

  @override
  State<AdminDiagnosesScreen> createState() => _AdminDiagnosesScreenState();
}

class _AdminDiagnosesScreenState extends State<AdminDiagnosesScreen> {
  late Stream<List<Diagnosis>> _diagnoses;
  late Stream<List<ManagedUser>> _users;
  String _filter = _filters.first;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  void _watch() {
    _diagnoses = RecordsService.instance.watchAllDiagnoses();
    _users = AdminService.instance.watchUsers();
  }

  bool _matches(Diagnosis d) => switch (_filter) {
    'Vigentes' => d.isCurrent,
    'No vigentes' => !d.esActual && !d.anulado,
    'Anulados' => d.anulado,
    _ => true,
  };

  Future<void> _open(Diagnosis diagnosis, String patientName) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => DiagnosisEditScreen(
          diagnosis: diagnosis,
          patientName: patientName,
          navItems: adminNavItems(),
          currentIndex: 2,
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
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text('Diagnósticos', style: AppTextStyles.display(fontSize: 18)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Diagnosis>>(
          stream: _diagnoses,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(
                onRetry: () => setState(_watch),
                message: AuthService.describeError(snapshot.error!),
              );
            }
            if (!snapshot.hasData) return const LoadingView();
            final diagnoses = snapshot.data!;
            return StreamBuilder<List<ManagedUser>>(
              stream: _users,
              builder: (context, usersSnap) {
                final names = {
                  for (final u in usersSnap.data ?? const <ManagedUser>[])
                    u.uid: u.fullName,
                };
                return _buildList(diagnoses, names);
              },
            );
          },
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: adminNavItems(),
        currentIndex: 2,
      ),
    );
  }

  Widget _buildList(List<Diagnosis> diagnoses, Map<String, String> names) {
    final shown = diagnoses.where(_matches).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilterChips(
            options: _filters,
            selected: _filter,
            onChanged: (chip) => setState(() => _filter = chip),
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            EmptyState(
              title: 'Sin diagnósticos',
              message: diagnoses.isEmpty
                  ? 'Los cuidadores todavía no registraron diagnósticos.'
                  : 'Ningún diagnóstico coincide con el filtro.',
              icon: Icons.medical_information_outlined,
            ),
          for (final d in shown)
            DiagnosisCard(
              diagnosis: d,
              patientName: names[d.idPaciente] ?? 'Paciente',
              onTap: () => _open(d, names[d.idPaciente] ?? 'Paciente'),
            ),
        ],
      ),
    );
  }
}
