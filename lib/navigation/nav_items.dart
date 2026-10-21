import 'package:flutter/material.dart';

import '../screens/admin_panel_screen.dart';
import '../screens/admin_audit_screen.dart';
import '../screens/admin_diagnoses_screen.dart';
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
import '../widgets/app_bottom_nav.dart';

List<AppNavItem> patientHomeNavItems() => [
  AppNavItem(
    icon: Icons.home,
    label: 'Inicio',
    builder: (_) => const PatientHomeScreen(),
  ),
  AppNavItem(
    icon: Icons.devices,
    label: 'Dispositivo',
    builder: (_) => const DeviceSettingsScreen(),
  ),
  AppNavItem(
    icon: Icons.history,
    label: 'Historial',
    builder: (_) =>
        PatientHistoryScreen(navItems: patientHomeNavItems(), currentIndex: 2),
  ),
  AppNavItem(
    icon: Icons.receipt,
    label: 'Facturación',
    builder: (_) => const BillingScreen(),
  ),
  AppNavItem(
    icon: Icons.person,
    label: 'Perfil',
    builder: (_) => const PatientProfileScreen(),
  ),
];

List<AppNavItem> patientCaregiversNavItems() => [
  AppNavItem(
    icon: Icons.home,
    label: 'Inicio',
    builder: (_) => const PatientHomeScreen(),
  ),
  AppNavItem(
    icon: Icons.people,
    label: 'Cuidadores',
    builder: (_) => const PatientCaregiversScreen(),
  ),
  AppNavItem(
    icon: Icons.devices,
    label: 'Dispositivo',
    builder: (_) => const DeviceSettingsScreen(),
  ),
  AppNavItem(
    icon: Icons.history,
    label: 'Historial',
    builder: (_) => PatientHistoryScreen(
      navItems: patientCaregiversNavItems(),
      currentIndex: 3,
    ),
  ),
  AppNavItem(
    icon: Icons.person,
    label: 'Perfil',
    builder: (_) => const PatientProfileScreen(),
  ),
];

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
    builder: (_) => const BillingScreen(),
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
