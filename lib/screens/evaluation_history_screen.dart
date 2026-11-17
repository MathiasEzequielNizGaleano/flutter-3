import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import '../widgets/profile_parts.dart';
import '../widgets/record_sections.dart';
import '../widgets/state_views.dart';

/// Todas las evaluaciones funcionales de un paciente, la más reciente
/// primero. Ninguna se borra: así se ve cómo evolucionó.
class EvaluationHistoryScreen extends StatefulWidget {
  const EvaluationHistoryScreen({
    super.key,
    required this.patientUid,
    required this.patientName,
  });

  final String patientUid;
  final String patientName;

  @override
  State<EvaluationHistoryScreen> createState() =>
      _EvaluationHistoryScreenState();
}

class _EvaluationHistoryScreenState extends State<EvaluationHistoryScreen> {
  late Stream<List<FunctionalState>> _evaluations = _watch();

  Stream<List<FunctionalState>> _watch() =>
      RecordsService.instance.watchEvaluations(widget.patientUid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          'Evaluaciones funcionales',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<FunctionalState>>(
          stream: _evaluations,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(
                onRetry: () => setState(() => _evaluations = _watch()),
                message: AuthService.describeError(snapshot.error!),
              );
            }
            if (!snapshot.hasData) return const LoadingView();
            final list = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.patientName,
                    style: AppTextStyles.display(fontSize: 15),
                  ),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: EmptyState(
                        title: 'Sin evaluaciones',
                        message:
                            'Todavía no se registró ninguna evaluación '
                            'funcional.',
                        icon: Icons.accessibility_new,
                      ),
                    ),
                  for (var i = 0; i < list.length; i++) ...[
                    ProfileSectionTitle(_title(list[i], i == 0)),
                    FunctionalStateCard(state: list[i]),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _title(FunctionalState s, bool latest) {
    final date = s.fechaEvaluacion == null
        ? 'Recién guardada'
        : formatLongDate(s.fechaEvaluacion!);
    return latest ? '$date · actual' : date;
  }
}
