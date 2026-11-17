import 'dart:async';

import 'package:flutter/material.dart';

import '../ble/headmouse_ble.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../services/device_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/filter_chips.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';
import 'billing_screen.dart';

const _configs = 'Configuraciones';
const _calibrations = 'Calibraciones';

/// Configuraciones y calibraciones de un paciente. Con [canRestore] se
/// puede elegir una configuración anterior: la pantalla vuelve con ella
/// para cargarla en el HeadMouse (función del Plan Premium).
class DeviceHistoryScreen extends StatefulWidget {
  const DeviceHistoryScreen({
    super.key,
    required this.patientUid,
    required this.patientName,
    this.canRestore = false,
    this.initialTab = _configs,
  });

  final String patientUid;
  final String patientName;
  final bool canRestore;
  final String initialTab;

  @override
  State<DeviceHistoryScreen> createState() => _DeviceHistoryScreenState();
}

class _DeviceHistoryScreenState extends State<DeviceHistoryScreen> {
  late String _tab = widget.initialTab;
  late Stream<List<ConfigEntry>> _configStream;
  late Stream<List<CalibrationEntry>> _calibrationStream;
  StreamSubscription<PremiumPlan>? _planSub;

  /// `null` mientras no se sabe si el paciente tiene Plan Premium.
  bool? _premium;

  @override
  void initState() {
    super.initState();
    _watch();
    if (widget.canRestore) {
      _planSub = BillingService.instance
          .watchPlan(widget.patientUid)
          .listen(
            (plan) => setState(() => _premium = plan.isPremium),
            onError: (_) => setState(() => _premium = false),
          );
    }
  }

  @override
  void dispose() {
    _planSub?.cancel();
    super.dispose();
  }

  void _watch() {
    final service = DeviceService.instance;
    _configStream = service.watchConfigs(widget.patientUid);
    _calibrationStream = service.watchCalibrations(widget.patientUid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          'Historial del dispositivo',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.patientName,
                style: AppTextStyles.display(fontSize: 15),
              ),
              const SizedBox(height: 12),
              FilterChips(
                options: const [_configs, _calibrations],
                selected: _tab,
                onChanged: (tab) => setState(() => _tab = tab),
              ),
              const SizedBox(height: 14),
              if (_tab == _configs)
                _list<ConfigEntry>(
                  _configStream,
                  empty: 'Todavía no se guardó ninguna configuración.',
                  item: (e) => _ConfigCard(
                    entry: e,
                    locked: _premium != true,
                    onRestore: widget.canRestore && !e.vigente
                        ? () => _premium == true ? _restore(e) : _premiumOnly()
                        : null,
                  ),
                )
              else
                _list<CalibrationEntry>(
                  _calibrationStream,
                  empty: 'Todavía no se registró ninguna calibración.',
                  item: (e) => _CalibrationCard(entry: e),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list<T>(
    Stream<List<T>> stream, {
    required String empty,
    required Widget Function(T) item,
  }) {
    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(
            onRetry: () => setState(_watch),
            message: AuthService.describeError(snapshot.error!),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final list = snapshot.data!;
        if (list.isEmpty) {
          return EmptyState(
            title: 'Sin registros',
            message: empty,
            icon: Icons.history,
          );
        }
        return Column(children: [for (final e in list) item(e)]);
      },
    );
  }

  Future<void> _premiumOnly() async {
    final go = await confirmAction(
      context,
      title: 'Función del Plan Premium',
      message:
          'Volver a cargar una configuración anterior es parte del Plan '
          'Premium. Se activa desde Facturación.',
      confirmLabel: 'Ir a Facturación',
      danger: false,
    );
    if (!go || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillingScreen(
          caregiverNav: AuthService.instance.current?.role == UserRole.cuidador,
        ),
      ),
    );
  }

  Future<void> _restore(ConfigEntry entry) async {
    final confirmed = await confirmAction(
      context,
      title: '¿Usar esta configuración?',
      message:
          '${entry.summary}\n${entry.buttons}\n\nSe carga en la pantalla de '
          'configuración. Se aplica al HeadMouse cuando la guardes.',
      confirmLabel: 'Cargar',
      danger: false,
    );
    if (confirmed && mounted) Navigator.pop(context, entry.config);
  }
}

String _when(DateTime? time) =>
    time == null ? 'recién guardada' : formatEventTime(time);

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    decoration: glassCardDecoration(radius: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 5,
      children: children,
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.badge);

  final String title;
  final StatusBadge badge;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    spacing: 8,
    children: [
      Flexible(
        child: Text(
          title,
          style: AppTextStyles.body(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      badge,
    ],
  );
}

class _Meta extends StatelessWidget {
  const _Meta(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTextStyles.body(fontSize: 11, color: AppColors.textMute),
  );
}

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({required this.entry, this.onRestore, this.locked = false});

  final ConfigEntry entry;
  final VoidCallback? onRestore;

  /// Sin Plan Premium: el botón avisa en vez de cargarla.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final restore = onRestore;
    return _Card(
      children: [
        _Header(
          e.summary,
          e.vigente
              ? const StatusBadge(text: 'Vigente')
              : e.pendiente
              ? const StatusBadge(text: 'Pendiente', tone: StatusBadgeTone.warn)
              : const StatusBadge(text: 'Anterior', tone: StatusBadgeTone.mute),
        ),
        Text(e.buttons, style: AppTextStyles.body(fontSize: 12)),
        _Meta(e.origen.label),
        _Meta(
          [
            if (e.nombreAutor.isNotEmpty) e.nombreAutor,
            _when(e.fecha),
          ].join(' · '),
        ),
        if (restore != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: restore,
              icon: Icon(
                locked ? Icons.lock_outline : Icons.restore,
                size: 18,
                color: AppColors.cyan,
              ),
              label: Text(
                locked
                    ? 'Usar esta configuración · Premium'
                    : 'Usar esta configuración',
                style: AppTextStyles.body(fontSize: 12, color: AppColors.cyan),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalibrationCard extends StatelessWidget {
  const _CalibrationCard({required this.entry});

  final CalibrationEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return _Card(
      children: [
        _Header(
          e.exitosa ? e.center : 'No se pudo calibrar',
          e.exitosa
              ? StatusBadge(
                  text: e.vigente ? 'Vigente' : 'Exitosa',
                  tone: e.vigente ? StatusBadgeTone.ok : StatusBadgeTone.mute,
                )
              : const StatusBadge(text: 'Error', tone: StatusBadgeTone.warn),
        ),
        Text(
          'Motivo: ${e.motivo.isEmpty ? '—' : e.motivo}',
          style: AppTextStyles.body(fontSize: 12),
        ),
        _Meta(
          [
            if (e.nombreAutor.isNotEmpty) e.nombreAutor,
            _when(e.fecha),
          ].join(' · '),
        ),
      ],
    );
  }
}

/// Fecha de la última calibración exitosa, de Firestore o, si todavía no
/// llegó, de esta sesión.
DateTime? lastSuccessfulCalibration(List<CalibrationEntry>? history) {
  for (final e in history ?? const <CalibrationEntry>[]) {
    if (e.exitosa) return e.fecha ?? DateTime.now();
  }
  return HeadMouseBle.instance.lastCalibration;
}
