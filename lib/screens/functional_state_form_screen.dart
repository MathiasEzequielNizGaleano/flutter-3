import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/form_fields.dart';
import '../widgets/gradient_button.dart';
import '../widgets/option_grid.dart';
import '../widgets/unsaved_changes_guard.dart';

/// Registro del estado funcional del paciente (cuidador o administrador).
/// Cada vez que se guarda queda con la fecha y el nombre de quien evaluó.
class FunctionalStateFormScreen extends StatefulWidget {
  const FunctionalStateFormScreen({
    super.key,
    required this.patientUid,
    required this.patientName,
    this.current,
  });

  final String patientUid;
  final String patientName;

  /// Última evaluación, para partir de ella.
  final FunctionalState? current;

  @override
  State<FunctionalStateFormScreen> createState() =>
      _FunctionalStateFormScreenState();
}

class _FunctionalStateFormScreenState extends State<FunctionalStateFormScreen> {
  late final FunctionalState _start = widget.current ?? const FunctionalState();
  late Mobility? _cervical = _start.movilidadCervical;
  late Mobility? _miofacial = _start.movilidadMiofacial;
  late HeadControl? _head = _start.controlCefalico;
  late Assistance? _assistance = _start.nivelAsistencia;
  late bool _upperLimbs = _start.limitacionMiembrosSuperiores;
  late bool _involuntary = _start.movimientosInvoluntarios;
  late bool _leftClip = _start.puedeClipIzquierdo;
  late bool _rightClip = _start.puedeClipDerecho;
  late final _notes = TextEditingController(text: _start.observaciones);
  bool _saving = false;

  FunctionalState get _edited => FunctionalState(
    movilidadCervical: _cervical,
    movilidadMiofacial: _miofacial,
    controlCefalico: _head,
    nivelAsistencia: _assistance,
    limitacionMiembrosSuperiores: _upperLimbs,
    movimientosInvoluntarios: _involuntary,
    puedeClipIzquierdo: _leftClip,
    puedeClipDerecho: _rightClip,
    observaciones: _notes.text,
  );

  bool get _hasChanges {
    if (_saving) return false;
    final a = _edited.toMap();
    final b = _start.toMap();
    return a.keys.any((key) => a[key] != b[key]);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final missing = [
      if (_cervical == null) 'movilidad cervical',
      if (_miofacial == null) 'movilidad miofacial',
      if (_head == null) 'control cefálico',
      if (_assistance == null) 'nivel de asistencia',
    ];
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falta indicar: ${missing.join(', ')}.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await RecordsService.instance.saveFunctionalState(
        widget.patientUid,
        _edited,
        nombre: widget.patientName,
      );
      if (mounted) Navigator.pop(context, 'Estado funcional registrado.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AuthService.describeError(e))));
    }
  }

  Widget _grid<T extends Choice>(
    String label,
    List<T> values,
    T? selected,
    ValueChanged<T> onChanged,
  ) => OptionGrid(
    label: label,
    options: [for (final v in values) v.label],
    selected: selected?.label ?? '',
    onChanged: (text) =>
        setState(() => onChanged(values.firstWhere((v) => v.label == text))),
  );

  @override
  Widget build(BuildContext context) {
    final evaluator = AuthService.instance.current?.fullName;
    return UnsavedChangesGuard(
      hasChanges: () => _hasChanges,
      listenable: _notes,
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: AppBar(
          backgroundColor: AppColors.bgDeep,
          foregroundColor: AppColors.text,
          title: Text(
            'Estado funcional',
            style: AppTextStyles.display(fontSize: 18),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.patientName,
                  style: AppTextStyles.display(fontSize: 15),
                ),
                const FormSectionLabel('Movilidad cervical'),
                _grid(
                  'Cervical',
                  Mobility.values,
                  _cervical,
                  (v) => _cervical = v,
                ),
                const FormSectionLabel('Movilidad miofacial'),
                _grid(
                  'Miofacial',
                  Mobility.values,
                  _miofacial,
                  (v) => _miofacial = v,
                ),
                const FormSectionLabel('Control cefálico'),
                _grid('Control', HeadControl.values, _head, (v) => _head = v),
                const FormSectionLabel('Nivel de asistencia'),
                _grid(
                  'Asistencia',
                  Assistance.values,
                  _assistance,
                  (v) => _assistance = v,
                ),
                const FormSectionLabel('Capacidades'),
                Container(
                  decoration: glassCardDecoration(radius: 14),
                  // Material propio para que se vea el efecto al tocar.
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      children: [
                        YesNoSwitch(
                          'Movimientos involuntarios',
                          _involuntary,
                          (v) => setState(() => _involuntary = v),
                        ),
                        YesNoSwitch(
                          'Limitación en miembros superiores',
                          _upperLimbs,
                          (v) => setState(() => _upperLimbs = v),
                        ),
                        YesNoSwitch(
                          'Puede activar el clip izquierdo',
                          _leftClip,
                          (v) => setState(() => _leftClip = v),
                        ),
                        YesNoSwitch(
                          'Puede activar el clip derecho',
                          _rightClip,
                          (v) => setState(() => _rightClip = v),
                        ),
                      ],
                    ),
                  ),
                ),
                const FormSectionLabel('Observaciones'),
                AppTextField(
                  controller: _notes,
                  hint: 'Por ejemplo: se fatiga después de 40 min de uso',
                  icon: Icons.notes,
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                GradientButton(
                  label: _saving ? 'Guardando…' : 'Guardar evaluación',
                  onPressed: _saving ? null : _save,
                ),
                if (evaluator != null)
                  FormFootnote(
                    'Queda registrada como evaluada hoy por $evaluator.',
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
