import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/screen_title.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/filter_chips.dart';
import '../widgets/gradient_button.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';
import 'diagnosis_edit_screen.dart';

const _diagnoses = [
  Diagnosis(
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
  Diagnosis(
    patient: 'Marcos Rojas',
    type: 'Secundario',
    title: 'Evaluación funcional actualizada — mejora en inclinación lateral',
    date: '10 jun 2026',
  ),
  Diagnosis(
    patient: 'Lucía Fernández',
    type: 'Antecedente',
    title: 'Cirugía de columna cervical',
    date: '27 nov 2019',
    current: false,
  ),
];

const _patientFilters = [
  'Todos',
  'Marcos Rojas',
  'Lucía Fernández',
  'Juan Paredes',
];

class CaregiverDiagnosesScreen extends StatefulWidget {
  const CaregiverDiagnosesScreen({super.key});

  @override
  State<CaregiverDiagnosesScreen> createState() =>
      _CaregiverDiagnosesScreenState();
}

class _CaregiverDiagnosesScreenState extends State<CaregiverDiagnosesScreen> {
  String _filter = 'Todos';

  StatusBadgeTone _toneFor(String type) => switch (type) {
    'Principal' => StatusBadgeTone.ok,
    'Antecedente' => StatusBadgeTone.warn,
    _ => StatusBadgeTone.violet,
  };

  void _open(Diagnosis diagnosis, {bool isNew = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiagnosisEditScreen(
          diagnosis: diagnosis,
          navItems: caregiverNavItems(),
          currentIndex: 1,
          isNew: isNew,
        ),
      ),
    );
  }

  void _addNew() {
    _open(
      Diagnosis(
        patient: _filter == 'Todos' ? 'Marcos Rojas' : _filter,
        type: 'Principal',
        title: '',
      ),
      isNew: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _diagnoses.where(
      (diagnosis) => _filter == 'Todos' || diagnosis.patient == _filter,
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
                ScreenTitle('Diagnósticos'),
                const SizedBox(height: 16),
                GradientButton(
                  label: '+ Nuevo diagnóstico',
                  onPressed: _addNew,
                ),
                const SizedBox(height: 14),
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
                        'No hay diagnósticos para el paciente seleccionado.',
                    icon: Icons.medical_information_outlined,
                  ),
                for (final diagnosis in visible)
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
                          children: [
                            Flexible(
                              child: Text(
                                diagnosis.patient,
                                style: AppTextStyles.body(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            StatusBadge(
                              text: diagnosis.type,
                              tone: _toneFor(diagnosis.type),
                            ),
                          ],
                        ),
                        Text(
                          diagnosis.title,
                          style: AppTextStyles.body(fontSize: 12),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          spacing: 12,
                          children: [
                            Flexible(
                              child: Text.rich(
                                TextSpan(
                                  text: diagnosis.type == 'Antecedente'
                                      ? 'Fecha: '
                                      : 'Diagnosticado: ',
                                  children: [
                                    TextSpan(
                                      text: diagnosis.date,
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
                              diagnosis.current ? 'Vigente' : 'No vigente',
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
                            onTap: () => _open(diagnosis),
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
        items: caregiverNavItems(),
        currentIndex: 1,
      ),
    );
  }
}
