import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/filter_chips.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';
import 'diagnosis_edit_screen.dart';

class _DiagnosisEntry {
  const _DiagnosisEntry({
    required this.diagnosis,
    required this.loadedBy,
    required this.time,
  });

  final Diagnosis diagnosis;
  final String loadedBy;
  final String time;
}

const _entries = [
  _DiagnosisEntry(
    diagnosis: Diagnosis(
      patient: 'Marcos Rojas',
      type: 'Secundario',
      title: 'Contractura cervical crónica',
      description:
          'Limita el rango de movimiento lateral de cabeza usado para el '
          'control del cursor.',
      date: '02 ago 2023',
      professional: 'Lic. Carlos Herrera',
      institution: 'CDT UNIDA',
      specialty: 'Fisioterapia',
      lastEdit: 'María González · Hoy, 09:40',
    ),
    loadedBy: 'Lic. Carlos Herrera',
    time: 'Hoy, 08:20',
  ),
  _DiagnosisEntry(
    diagnosis: Diagnosis(
      patient: 'Juan Paredes',
      type: 'Principal',
      title: 'Parálisis cerebral espástica',
    ),
    loadedBy: 'María González',
    time: 'Ayer, 16:45',
  ),
  _DiagnosisEntry(
    diagnosis: Diagnosis(
      patient: 'Lucía Fernández',
      type: 'Antecedente',
      title: 'Cirugía de columna cervical',
      date: '27 nov 2019',
      current: false,
    ),
    loadedBy: 'Ana Duarte',
    time: 'Ayer, 11:10',
  ),
];

const _patientFilters = [
  'Todos',
  'Marcos Rojas',
  'Juan Paredes',
  'Lucía Fernández',
];

class AdminDiagnosesScreen extends StatefulWidget {
  const AdminDiagnosesScreen({super.key});

  @override
  State<AdminDiagnosesScreen> createState() => _AdminDiagnosesScreenState();
}

class _AdminDiagnosesScreenState extends State<AdminDiagnosesScreen> {
  String _filter = 'Todos';

  StatusBadgeTone _toneFor(String type) =>
      type == 'Principal' ? StatusBadgeTone.ok : StatusBadgeTone.warn;

  void _edit(Diagnosis diagnosis) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiagnosisEditScreen(
          diagnosis: diagnosis,
          navItems: adminNavItems(),
          currentIndex: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _entries.where(
      (entry) => _filter == 'Todos' || entry.diagnosis.patient == _filter,
    );

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text('Diagnósticos', style: AppTextStyles.display(fontSize: 18)),
      ),
      body: SafeArea(
        child: AsyncBody(
          loader: simulateFetch,
          builder: (context) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilterChips(
                  options: _patientFilters,
                  selected: _filter,
                  onChanged: (chip) => setState(() => _filter = chip),
                ),
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  const EmptyState(
                    title: 'Sin diagnósticos',
                    message:
                        'Ningún diagnóstico coincide con el filtro seleccionado.',
                    icon: Icons.medical_information_outlined,
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
                      border: Border.all(color: AppColors.line, width: 1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.diagnosis.patient,
                              style: AppTextStyles.body(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            StatusBadge(
                              text: entry.diagnosis.type,
                              tone: _toneFor(entry.diagnosis.type),
                            ),
                          ],
                        ),
                        Text(
                          entry.diagnosis.title,
                          style: AppTextStyles.body(fontSize: 12),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text.rich(
                                TextSpan(
                                  text: 'Cargado por: ',
                                  children: [
                                    TextSpan(
                                      text: entry.loadedBy,
                                      style: TextStyle(
                                        color: AppColors.text,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                style: AppTextStyles.body(
                                  fontSize: 10.5,
                                  color: AppColors.textMute,
                                ),
                              ),
                            ),
                            Text(
                              entry.time,
                              style: AppTextStyles.body(
                                fontSize: 10.5,
                                color: AppColors.textMute,
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => _edit(entry.diagnosis),
                            child: const StatusBadge(text: '✎ Editar'),
                          ),
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
        items: adminNavItems(),
        currentIndex: 2,
      ),
    );
  }
}
