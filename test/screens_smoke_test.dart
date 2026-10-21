import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headmouse_pro/main.dart';
import 'package:headmouse_pro/navigation/nav_items.dart';
import 'package:headmouse_pro/screens/admin_audit_screen.dart';
import 'package:headmouse_pro/screens/admin_devices_screen.dart';
import 'package:headmouse_pro/screens/admin_diagnoses_screen.dart';
import 'package:headmouse_pro/screens/admin_panel_screen.dart';
import 'package:headmouse_pro/screens/admin_plans_screen.dart';
import 'package:headmouse_pro/screens/admin_profile_screen.dart';
import 'package:headmouse_pro/screens/admin_users_screen.dart';
import 'package:headmouse_pro/screens/billing_screen.dart';
import 'package:headmouse_pro/screens/caregiver_diagnoses_screen.dart';
import 'package:headmouse_pro/screens/caregiver_history_screen.dart';
import 'package:headmouse_pro/screens/caregiver_patients_screen.dart';
import 'package:headmouse_pro/screens/caregiver_profile_screen.dart';
import 'package:headmouse_pro/screens/device_calibration_screen.dart';
import 'package:headmouse_pro/screens/device_pause_cursor_screen.dart';
import 'package:headmouse_pro/screens/device_settings_screen.dart';
import 'package:headmouse_pro/screens/login_screen.dart';
import 'package:headmouse_pro/screens/patient_caregivers_screen.dart';
import 'package:headmouse_pro/screens/patient_home_screen.dart';
import 'package:headmouse_pro/screens/patient_profile_screen.dart';
import 'package:headmouse_pro/screens/privacy_policy_screen.dart';
import 'package:headmouse_pro/screens/register_screen.dart';
import 'package:headmouse_pro/screens/terms_screen.dart';
import 'package:headmouse_pro/theme/app_theme.dart';

final _screens = <String, Widget Function()>{
  'login': () => const LoginScreen(),
  'registro': () => const RegisterScreen(),
  'privacidad': () => const PrivacyPolicyScreen(),
  'términos': () => const TermsScreen(),
  'paciente · inicio': () => const PatientHomeScreen(),
  'paciente · cuidadores': () => const PatientCaregiversScreen(),
  'paciente · perfil': () => const PatientProfileScreen(),
  'paciente · historial': () => patientHomeNavItems()[2].builder(_ctx),
  'cuidador · pacientes': () => const CaregiverPatientsScreen(),
  'cuidador · diagnósticos': () => const CaregiverDiagnosesScreen(),
  'cuidador · historial': () => const CaregiverHistoryScreen(),
  'cuidador · perfil': () => const CaregiverProfileScreen(),
  'admin · panel': () => const AdminPanelScreen(),
  'admin · usuarios': () => const AdminUsersScreen(),
  'admin · diagnósticos': () => const AdminDiagnosesScreen(),
  'admin · auditoría': () => const AdminAuditScreen(),
  'admin · dispositivos': () => const AdminDevicesScreen(),
  'admin · planes': () => const AdminPlansScreen(),
  'admin · perfil': () => const AdminProfileScreen(),
  'facturación': () => const BillingScreen(),
  'dispositivo · ajustes': () => const DeviceSettingsScreen(),
  'dispositivo · calibración': () => const DeviceCalibrationScreen(),
  'dispositivo · pausa del cursor': () => const DevicePauseCursorScreen(),
};

late BuildContext _ctx;

void main() {
  tearDown(() => AppTheme.instance.setMode(ThemeMode.dark));

  for (final scale in [1.0, 1.5]) {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      for (final entry in _screens.entries) {
        testWidgets('${entry.key} · $mode · texto ${(scale * 100).round()} %', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(360 * 3, 740 * 3);
          tester.view.devicePixelRatio = 3;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() {
            tester.view.reset();
            tester.platformDispatcher.clearAllTestValues();
          });
          AppTheme.instance.setMode(mode);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.instance.themeData,
              builder: (context, child) => MediaQuery.withClampedTextScaling(
                minScaleFactor: 1.0,
                maxScaleFactor: 1.5,
                child: child!,
              ),
              home: Builder(
                builder: (context) {
                  _ctx = context;
                  return entry.value();
                },
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));

          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets('la app entera arranca (MyApp)', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
