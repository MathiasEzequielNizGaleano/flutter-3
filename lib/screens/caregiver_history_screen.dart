import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../services/auth_service.dart';
import '../services/care_service.dart';
import '../services/device_service.dart';
import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import '../utils/streams.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/filter_chips.dart';
import '../widgets/screen_title.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';

const _all = 'Todos';
const _types = ['Todo', 'Calibración', 'Configuración', 'Diagnóstico'];

/// Algo que pasó con un paciente: una calibración, una configuración o un
/// diagnóstico.
@immutable
class _Activity {
  const _Activity({
    required this.patient,
    required this.type,
    required this.title,
    required this.detail,
    required this.author,
    required this.date,
  });

  final String patient;
  final String type;
  final String title;
  final String detail;
  final String author;
  final DateTime? date;

  static int byDate(_Activity a, _Activity b) => newestFirst(a.date, b.date);
}

/// Actividad reciente de los pacientes del cuidador, armada con los
/// historiales de cada uno.
class CaregiverHistoryScreen extends StatefulWidget {
  const CaregiverHistoryScreen({super.key});

  @override
  State<CaregiverHistoryScreen> createState() => _CaregiverHistoryScreenState();
}

class _CaregiverHistoryScreenState extends State<CaregiverHistoryScreen> {
  late Stream<List<CareAssignment>> _links = _watchLinks();
  Stream<List<_Activity>>? _activity;
  List<String> _watchedKey = const [];
  String _patient = _all;
  String _type = _types.first;

  Stream<List<CareAssignment>> _watchLinks() => CareService.instance
      .watchForCaregiver(AuthService.instance.currentUid ?? '');

  void _retry() => setState(() {
    _links = _watchLinks();
    _activity = null;
  });

  /// Vuelve a escuchar solo si cambian los pacientes o sus permisos.
  Stream<List<_Activity>> _activityOf(List<CareAssignment> links) {
    final key = [
      for (final l in links)
        '${l.idPaciente}:${l.permisos.verDatos}:${l.permisos.configurar}'
            ':${l.permisos.calibrar}',
    ];
    if (_activity == null || !listEquals(key, _watchedKey)) {
      _watchedKey = key;
      _activity = mergeLatest([
        for (final l in links) ..._streamsFor(l),
      ], compare: _Activity.byDate);
    }
    return _activity!;
  }

  List<Stream<List<_Activity>>> _streamsFor(CareAssignment link) {
    final name = link.nombrePaciente;
    final uid = link.idPaciente;
    final devices = DeviceService.instance;
    return [
      devices
          .watchCalibrations(uid)
          .map(
            (list) => [
              for (final c in list)
                _Activity(
                  patient: name,
                  type: 'Calibración',
                  title: c.exitosa
                      ? 'Calibración completada'
                      : 'No se pudo calibrar',
                  detail: [
                    if (c.motivo.isNotEmpty) 'Motivo: ${c.motivo}',
                    if (c.exitosa) c.center,
                  ].join(' · '),
                  author: c.nombreAutor,
                  date: c.fecha,
                ),
            ],
          ),
      devices
          .watchConfigs(uid)
          .map(
            (list) => [
              for (final c in list)
                _Activity(
                  patient: name,
                  type: 'Configuración',
                  title: c.pendiente
                      ? 'Restablecimiento pedido por el administrador'
                      : c.origen == ConfigOrigin.app
                      ? 'Configuración guardada'
                      : c.origen.label,
                  detail: '${c.summary}\n${c.buttons}',
                  author: c.nombreAutor,
                  date: c.fecha,
                ),
            ],
          ),
      if (link.permisos.verDatos)
        RecordsService.instance
            .watchDiagnoses(uid)
            .map(
              (list) => [
                for (final d in list)
                  _Activity(
                    patient: name,
                    type: 'Diagnóstico',
                    title: d.anulado
                        ? 'Diagnóstico anulado'
                        : 'Diagnóstico ${d.tipo.label.toLowerCase()}',
                    detail: d.diagnostico,
                    author: d.nombreRegistrador,
                    date: d.fechaRegistro,
                  ),
              ],
            ),
    ];
  }

  StatusBadgeTone _toneFor(String type) => switch (type) {
    'Calibración' => StatusBadgeTone.ok,
    'Configuración' => StatusBadgeTone.warn,
    _ => StatusBadgeTone.violet,
  };

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
            final links = snapshot.data!
                .where(
                  (l) =>
                      l.permisos.verDatos ||
                      l.permisos.configurar ||
                      l.permisos.calibrar,
                )
                .toList();
            if (links.isEmpty) return _frame(links, const []);
            return StreamBuilder<List<_Activity>>(
              stream: _activityOf(links),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorView(
                    onRetry: _retry,
                    message: AuthService.describeError(snapshot.error!),
                  );
                }
                if (!snapshot.hasData) return const LoadingView();
                return _frame(links, snapshot.data!);
              },
            );
          },
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: caregiverNavItems(),
        currentIndex: 2,
      ),
    );
  }

  Widget _frame(List<CareAssignment> links, List<_Activity> activity) {
    final names = {for (final l in links) l.nombrePaciente}.toList();
    final patient = names.contains(_patient) ? _patient : _all;
    final shown = activity
        .where(
          (a) =>
              (patient == _all || a.patient == patient) &&
              (_type == _types.first || a.type == _type),
        )
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenTitle('Historial de actividad'),
          const SizedBox(height: 16),
          if (names.length > 1) ...[
            FilterChips(
              options: [_all, ...names],
              selected: patient,
              onChanged: (chip) => setState(() => _patient = chip),
            ),
            const SizedBox(height: 10),
          ],
          FilterChips(
            options: _types,
            selected: _type,
            onChanged: (chip) => setState(() => _type = chip),
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            EmptyState(
              title: 'Sin actividad',
              message: links.isEmpty
                  ? 'Cuando tengas pacientes asignados, acá vas a ver sus '
                        'calibraciones, configuraciones y diagnósticos.'
                  : 'Todavía no hay actividad registrada.',
              icon: Icons.history,
            ),
          for (final a in shown) _ActivityCard(a, tone: _toneFor(a.type)),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard(this.activity, {required this.tone});

  final _Activity activity;
  final StatusBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final when = a.date == null ? 'Ahora' : formatEventTime(a.date!);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: glassCardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Flexible(
                child: Text(
                  a.title,
                  style: AppTextStyles.body(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusBadge(text: a.type, tone: tone),
            ],
          ),
          if (a.detail.isNotEmpty)
            Text(a.detail, style: AppTextStyles.body(fontSize: 12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Flexible(
                child: Text(
                  a.patient,
                  style: AppTextStyles.body(
                    fontSize: 10.5,
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  a.author.isEmpty ? when : '$when · ${a.author}',
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
    );
  }
}
