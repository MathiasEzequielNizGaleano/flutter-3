import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/screen_title.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/filter_chips.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';

class _ActivityEntry {
  const _ActivityEntry({
    required this.patient,
    required this.type,
    required this.title,
    required this.detail,
    required this.date,
  });

  final String patient;
  final String type;
  final String title;
  final String detail;
  final String date;
}

const _activity = [
  _ActivityEntry(
    patient: 'Marcos Rojas',
    type: 'Calibración',
    title: 'Calibración completada',
    detail: 'Sensibilidad 62% · zona muerta 8%',
    date: 'Hoy, 09:12',
  ),
  _ActivityEntry(
    patient: 'Juan Paredes',
    type: 'Diagnóstico',
    title: 'Evaluación funcional actualizada',
    detail: 'Mejora en el control de la inclinación lateral.',
    date: 'Ayer, 18:40',
  ),
  _ActivityEntry(
    patient: 'Lucía Fernández',
    type: 'Conexión',
    title: 'Dispositivo desconectado',
    detail: 'HeadMouse Pro · #0087 perdió la conexión Bluetooth.',
    date: '12 sep, 11:05',
  ),
  _ActivityEntry(
    patient: 'Marcos Rojas',
    type: 'Diagnóstico',
    title: 'Nuevo diagnóstico secundario',
    detail: 'Contractura cervical crónica.',
    date: '02 sep, 15:30',
  ),
  _ActivityEntry(
    patient: 'Juan Paredes',
    type: 'Calibración',
    title: 'Calibración completada',
    detail: 'Sensibilidad 55% · zona muerta 10%',
    date: '28 ago, 10:20',
  ),
];

const _patientFilters = [
  'Todos',
  'Marcos Rojas',
  'Lucía Fernández',
  'Juan Paredes',
];

class CaregiverHistoryScreen extends StatefulWidget {
  const CaregiverHistoryScreen({super.key});

  @override
  State<CaregiverHistoryScreen> createState() => _CaregiverHistoryScreenState();
}

class _CaregiverHistoryScreenState extends State<CaregiverHistoryScreen> {
  String _filter = 'Todos';

  StatusBadgeTone _toneFor(String type) => switch (type) {
    'Calibración' => StatusBadgeTone.ok,
    'Conexión' => StatusBadgeTone.warn,
    _ => StatusBadgeTone.violet,
  };

  @override
  Widget build(BuildContext context) {
    final visible = _activity.where(
      (entry) => _filter == 'Todos' || entry.patient == _filter,
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
                ScreenTitle('Historial de actividad'),
                const SizedBox(height: 16),
                FilterChips(
                  options: _patientFilters,
                  selected: _filter,
                  onChanged: (chip) => setState(() => _filter = chip),
                ),
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  const EmptyState(
                    title: 'Sin actividad',
                    message: 'No hay actividad registrada para este paciente.',
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
                    decoration: glassCardDecoration(radius: 14),
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
                          entry.detail,
                          style: AppTextStyles.body(fontSize: 12),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          spacing: 12,
                          children: [
                            Flexible(
                              child: Text(
                                entry.patient,
                                style: AppTextStyles.body(
                                  fontSize: 10.5,
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              entry.date,
                              style: AppTextStyles.body(
                                fontSize: 10.5,
                                color: AppColors.textMute,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: caregiverNavItems(),
        currentIndex: 2,
      ),
    );
  }
}
