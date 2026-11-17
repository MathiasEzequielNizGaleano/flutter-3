import 'package:flutter/material.dart';

import '../screens/admin_audit_screen.dart';
import '../screens/admin_diagnoses_screen.dart';
import '../screens/admin_panel_screen.dart';
import '../screens/admin_profile_screen.dart';
import '../screens/admin_users_screen.dart';
import '../screens/billing_screen.dart';
import '../screens/caregiver_diagnoses_screen.dart';
import '../screens/caregiver_history_screen.dart';
import '../screens/caregiver_patients_screen.dart';
import '../screens/caregiver_profile_screen.dart';
import '../screens/device_settings_screen.dart';
import '../screens/patient_caregivers_screen.dart';
import '../screens/patient_history_screen.dart';
import '../screens/patient_home_screen.dart';
import '../screens/patient_profile_screen.dart';
import '../services/auth_service.dart';
import '../widgets/app_bottom_nav.dart';

enum PatientTab {
  inicio,
  cuidadores,
  dispositivo,
  historial,
  facturacion,
  perfil,
}

/// El diseño tiene dos barras para el paciente: si tiene cuidadores
/// asignados aparece "Cuidadores" en lugar de "Facturación".
List<PatientTab> _patientTabs() =>
    (AuthService.instance.current?.hasCaregivers ?? false)
    ? const [
        PatientTab.inicio,
        PatientTab.cuidadores,
        PatientTab.dispositivo,
        PatientTab.historial,
        PatientTab.perfil,
      ]
    : const [
        PatientTab.inicio,
        PatientTab.dispositivo,
        PatientTab.historial,
        PatientTab.facturacion,
        PatientTab.perfil,
      ];

AppNavItem _patientItem(PatientTab tab) => switch (tab) {
  PatientTab.inicio => AppNavItem(
    icon: Icons.home,
    label: 'Inicio',
    builder: (_) => const PatientHomeScreen(),
  ),
  PatientTab.cuidadores => AppNavItem(
    icon: Icons.people,
    label: 'Cuidadores',
    builder: (_) => const PatientCaregiversScreen(),
  ),
  PatientTab.dispositivo => AppNavItem(
    icon: Icons.devices,
    label: 'Dispositivo',
    builder: (_) => const DeviceSettingsScreen(),
  ),
  PatientTab.historial => AppNavItem(
    icon: Icons.history,
    label: 'Historial',
    builder: (_) => PatientHistoryScreen(
      navItems: patientNavItems(),
      currentIndex: patientTabIndex(PatientTab.historial),
    ),
  ),
  PatientTab.facturacion => AppNavItem(
    icon: Icons.receipt,
    label: 'Facturación',
    builder: (_) => const BillingScreen(),
  ),
  PatientTab.perfil => AppNavItem(
    icon: Icons.person,
    label: 'Perfil',
    builder: (_) => const PatientProfileScreen(),
  ),
};

List<AppNavItem> patientNavItems() => [
  for (final tab in _patientTabs()) _patientItem(tab),
];

/// Posición de [tab] en la barra actual (0 si esa barra no la tiene).
int patientTabIndex(PatientTab tab) {
  final index = _patientTabs().indexOf(tab);
  return index < 0 ? 0 : index;
}

AppBottomNav patientBottomNav(PatientTab tab) =>
    AppBottomNav(items: patientNavItems(), currentIndex: patientTabIndex(tab));

List<AppNavItem> caregiverNavItems() => [
  AppNavItem(
    icon: Icons.people,
    label: 'Pacientes',
    builder: (_) => const CaregiverPatientsScreen(),
  ),
  AppNavItem(
    icon: Icons.medical_information_outlined,
    label: 'Diagnósticos',
    builder: (_) => const CaregiverDiagnosesScreen(),
  ),
  AppNavItem(
    icon: Icons.history,
    label: 'Historial',
    builder: (_) => const CaregiverHistoryScreen(),
  ),
  AppNavItem(
    icon: Icons.receipt,
    label: 'Facturación',
    builder: (_) => const BillingScreen(caregiverNav: true),
  ),
  AppNavItem(
    icon: Icons.person,
    label: 'Perfil',
    builder: (_) => const CaregiverProfileScreen(),
  ),
];

List<AppNavItem> adminNavItems() => [
  AppNavItem(
    icon: Icons.dashboard_outlined,
    label: 'Panel',
    builder: (_) => const AdminPanelScreen(),
  ),
  AppNavItem(
    icon: Icons.group_outlined,
    label: 'Usuarios',
    builder: (_) => const AdminUsersScreen(),
  ),
  AppNavItem(
    icon: Icons.medical_information_outlined,
    label: 'Diagnósticos',
    builder: (_) => const AdminDiagnosesScreen(),
  ),
  AppNavItem(
    icon: Icons.fact_check_outlined,
    label: 'Auditoría',
    builder: (_) => const AdminAuditScreen(),
  ),
  AppNavItem(
    icon: Icons.person,
    label: 'Perfil',
    builder: (_) => const AdminProfileScreen(),
  ),
];
