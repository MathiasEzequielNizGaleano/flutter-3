import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/screen_title.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/filter_chips.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';

class _HistoryEntry {
  const _HistoryEntry({
    required this.title,
    required this.type,
    required this.description,
    required this.dateLabel,
    required this.date,
    required this.current,
    required this.author,
    required this.authorDetail,
  });

  final String title;
  final String type;
  final String description;
  final String dateLabel;
  final String date;
  final bool current;
  final String author;
  final String authorDetail;
}

const _entries = [
  _HistoryEntry(
    title: 'Parálisis cerebral espástica',
    type: 'Principal',
    description:
        'Afecta el control motor fino de manos y cuello; dificulta sostener '
        'un mouse convencional.',
    dateLabel: 'Diagnosticado',
    date: '14 mar 2022',
    current: true,
    author: 'Dr. Marcos Insfrán',
    authorDetail: 'Neurología · Hospital de Clínicas',
  ),
  _HistoryEntry(
    title: 'Contractura cervical crónica',
    type: 'Secundario',
    description:
        'Limita el rango de movimiento lateral de cabeza usado para el '
        'control del cursor.',
    dateLabel: 'Diagnosticado',
    date: '02 ago 2023',
    current: true,
    author: 'Lic. Carlos Herrera',
    authorDetail: 'Fisioterapia · CDT UNIDA',
  ),
  _HistoryEntry(
    title: 'Evaluación funcional actualizada',
    type: 'Secundario',
    description:
        'Se registró mejora en el control de la inclinación lateral tras 3 '
        'meses de uso.',
    dateLabel: 'Diagnosticado',
    date: '10 jun 2026',
    current: true,
    author: 'Lic. Carlos Herrera',
    authorDetail: 'Fisioterapia · CDT UNIDA',
  ),
  _HistoryEntry(
    title: 'Cirugía de columna cervical',
    type: 'Antecedente',
    description:
        'Antecedente quirúrgico registrado por el cuidador; sin seguimiento '
        'activo.',
    dateLabel: 'Fecha',
    date: '27 nov 2019',
    current: false,
    author: 'Registrado por: María González',
    authorDetail: 'Cuidadora principal',
  ),
];

const _typeFilters = ['Todos', 'Principal', 'Secundario', 'Antecedente'];

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
  String _filter = 'Todos';

  StatusBadgeTone _toneFor(String type) => switch (type) {
    'Principal' => StatusBadgeTone.ok,
    'Antecedente' => StatusBadgeTone.warn,
    _ => StatusBadgeTone.violet,
  };

  Widget _metaLine(String left, String right, {String? boldLeft}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      Flexible(
        child: Text.rich(
          TextSpan(
            text: boldLeft == null ? left : '$left: ',
            children: [
              if (boldLeft != null)
                TextSpan(
                  text: boldLeft,
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          style: AppTextStyles.body(fontSize: 10.5, color: AppColors.textMute),
        ),
      ),
      Flexible(
        child: Text(
          right,
          textAlign: TextAlign.right,
          style: AppTextStyles.body(fontSize: 10.5, color: AppColors.textMute),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final visible = _entries.where(
      (entry) => _filter == 'Todos' || entry.type == _filter,
    );

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: AsyncBody(
          loader: simulateFetch,
          builder: (context) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenTitle('Historial clínico'),
                const SizedBox(height: 16),
                FilterChips(
                  options: _typeFilters,
                  selected: _filter,
                  onChanged: (chip) => setState(() => _filter = chip),
                ),
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  const EmptyState(
                    title: 'Sin registros',
                    message: 'No hay entradas de este tipo en tu historial.',
                    icon: Icons.history,
                  ),
                for (final entry in visible)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.overlay,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          spacing: 8,
                          children: [
                            Flexible(
                              child: Text(
                                entry.title,
                                style: AppTextStyles.body(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            StatusBadge(
                              text: entry.type,
                              tone: _toneFor(entry.type),
                            ),
                          ],
                        ),
                        Text(
                          entry.description,
                          style: AppTextStyles.body(fontSize: 12),
                        ),
                        _metaLine(
                          entry.dateLabel,
                          entry.current ? 'Vigente' : 'No vigente',
                          boldLeft: entry.date,
                        ),
                        _metaLine(entry.author, entry.authorDetail),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: widget.navItems,
        currentIndex: widget.currentIndex,
      ),
    );
  }
}
