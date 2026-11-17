import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headmouse_pro/main.dart';
import 'package:headmouse_pro/navigation/nav_items.dart';
import 'package:headmouse_pro/screens/access_history_screen.dart';
import 'package:headmouse_pro/screens/admin_assignments_screen.dart';
import 'package:headmouse_pro/screens/admin_audit_screen.dart';
import 'package:headmouse_pro/screens/admin_devices_screen.dart';
import 'package:headmouse_pro/screens/admin_diagnoses_screen.dart';
import 'package:headmouse_pro/screens/admin_panel_screen.dart';
import 'package:headmouse_pro/screens/admin_plans_screen.dart';
import 'package:headmouse_pro/screens/admin_profile_screen.dart';
import 'package:headmouse_pro/screens/admin_reports_screen.dart';
import 'package:headmouse_pro/screens/admin_user_form_screen.dart';
import 'package:headmouse_pro/screens/admin_users_screen.dart';
import 'package:headmouse_pro/screens/assignment_form_screen.dart';
import 'package:headmouse_pro/screens/attachment_viewer_screen.dart';
import 'package:headmouse_pro/screens/billing_screen.dart';
import 'package:headmouse_pro/screens/caregiver_data_form_screen.dart';
import 'package:headmouse_pro/screens/caregiver_detail_screen.dart';
import 'package:headmouse_pro/screens/caregiver_diagnoses_screen.dart';
import 'package:headmouse_pro/screens/caregiver_history_screen.dart';
import 'package:headmouse_pro/screens/caregiver_patients_screen.dart';
import 'package:headmouse_pro/screens/caregiver_profile_screen.dart';
import 'package:headmouse_pro/screens/caregiver_record_screen.dart';
import 'package:headmouse_pro/screens/checkout_screen.dart';
import 'package:headmouse_pro/screens/device_calibration_screen.dart';
import 'package:headmouse_pro/screens/device_form_screen.dart';
import 'package:headmouse_pro/screens/device_history_screen.dart';
import 'package:headmouse_pro/screens/device_pause_cursor_screen.dart';
import 'package:headmouse_pro/screens/device_settings_screen.dart';
import 'package:headmouse_pro/screens/diagnosis_edit_screen.dart';
import 'package:headmouse_pro/screens/evaluation_history_screen.dart';
import 'package:headmouse_pro/screens/functional_state_form_screen.dart';
import 'package:headmouse_pro/screens/login_screen.dart';
import 'package:headmouse_pro/screens/patient_caregivers_screen.dart';
import 'package:headmouse_pro/screens/patient_data_form_screen.dart';
import 'package:headmouse_pro/screens/patient_home_screen.dart';
import 'package:headmouse_pro/screens/patient_profile_screen.dart';
import 'package:headmouse_pro/screens/patient_record_screen.dart';
import 'package:headmouse_pro/screens/patient_register_screen.dart';
import 'package:headmouse_pro/screens/payment_register_screen.dart';
import 'package:headmouse_pro/screens/privacy_policy_screen.dart';
import 'package:headmouse_pro/screens/receipt_screen.dart';
import 'package:headmouse_pro/screens/register_screen.dart';
import 'package:headmouse_pro/screens/terms_screen.dart';
import 'package:headmouse_pro/screens/two_factor_screen.dart';
import 'package:headmouse_pro/screens/two_factor_settings_screen.dart';
import 'package:headmouse_pro/services/admin_service.dart';
import 'package:headmouse_pro/services/attachment_service.dart';
import 'package:headmouse_pro/services/auth_service.dart';
import 'package:headmouse_pro/services/billing_service.dart';
import 'package:headmouse_pro/services/care_service.dart';
import 'package:headmouse_pro/services/device_service.dart';
import 'package:headmouse_pro/services/records_service.dart';
import 'package:headmouse_pro/services/session_service.dart';
import 'package:headmouse_pro/services/two_factor_service.dart';
import 'package:headmouse_pro/theme/app_theme.dart';

import 'fake_admin_service.dart';
import 'fake_attachment_service.dart';
import 'fake_billing_service.dart';
import 'fake_care_service.dart';
import 'fake_device_service.dart';
import 'fake_records_service.dart';
import 'fake_session_service.dart';
import 'fake_two_factor_service.dart';

const _user = AppUser(
  uid: 'c1',
  email: 'maria.gonzalez@correo.com',
  role: UserRole.cuidador,
  nombres: 'María',
  apellidos: 'González',
);

const _smsUser = AppUser(
  uid: 'c1',
  email: 'maria.gonzalez@correo.com',
  role: UserRole.cuidador,
  nombres: 'María',
  apellidos: 'González',
  twoFactor: TwoFactorSettings(
    channel: TwoFactorChannel.sms,
    telefono: '0982 111 222',
  ),
);

final _screens = <String, Widget Function()>{
  'login': () => const LoginScreen(),
  'registro': () => const RegisterScreen(),
  'privacidad': () => const PrivacyPolicyScreen(),
  'términos': () => const TermsScreen(),
  'paciente · inicio': () => const PatientHomeScreen(),
  'paciente · cuidadores': () => const PatientCaregiversScreen(),
  'paciente · perfil': () => const PatientProfileScreen(),
  'paciente · historial': () =>
      patientNavItems()[patientTabIndex(PatientTab.historial)].builder(_ctx),
  'paciente · detalle de cuidador': () =>
      CaregiverDetailScreen(assignment: FakeCareService().links.first),
  'cuidador · pacientes': () => const CaregiverPatientsScreen(),
  'cuidador · diagnósticos': () => const CaregiverDiagnosesScreen(),
  'cuidador · historial': () => const CaregiverHistoryScreen(),
  'cuidador · perfil': () => const CaregiverProfileScreen(),
  'admin · panel': () => const AdminPanelScreen(),
  'admin · usuarios': () => const AdminUsersScreen(),
  'admin · usuarios inactivos': () =>
      const AdminUsersScreen(initialFilter: 'Inactivos'),
  'admin · alta de usuario': () => const AdminUserFormScreen(),
  'admin · editar usuario': () =>
      AdminUserFormScreen(user: FakeAdminService().users.first),
  'admin · cuidadores de un paciente': () =>
      AdminAssignmentsScreen(user: FakeAdminService().users.first),
  'admin · pacientes de un cuidador': () =>
      AdminAssignmentsScreen(user: FakeAdminService().users[2]),
  'admin · asignar cuidador': () =>
      AssignmentFormScreen(fixed: FakeAdminService().users.first),
  'admin · editar vínculo': () => AssignmentFormScreen(
    fixed: FakeAdminService().users.first,
    existing: FakeCareService().links.first,
  ),
  'admin · vínculo terminado': () => AssignmentFormScreen(
    fixed: FakeAdminService().users.first,
    existing: FakeCareService().links.last,
  ),
  'admin · diagnósticos': () => const AdminDiagnosesScreen(),
  'admin · auditoría': () => const AdminAuditScreen(),
  'admin · dispositivos': () => const AdminDevicesScreen(),
  'admin · planes': () => const AdminPlansScreen(),
  'admin · perfil': () => const AdminProfileScreen(),
  'facturación': () => const BillingScreen(),
  'facturación · cuidador': () => const BillingScreen(caregiverNav: true),
  'dispositivo · ajustes': () => const DeviceSettingsScreen(),
  'dispositivo · calibración': () => const DeviceCalibrationScreen(),
  'dispositivo · pausa del cursor': () => const DevicePauseCursorScreen(),
  'ficha del paciente · cuidador que edita': () => PatientRecordScreen(
    patientUid: 'p1',
    patientName: 'Juan Paredes',
    canEdit: true,
    subtitle: 'Madre · Principal',
    navItems: caregiverNavItems(),
  ),
  'ficha del paciente · solo lectura': () => const PatientRecordScreen(
    patientUid: 'p1',
    patientName: 'Juan Paredes',
    canEdit: false,
  ),
  'ficha del paciente · vacía': () => const PatientRecordScreen(
    patientUid: 'p9',
    patientName: 'Paciente Nuevo',
    canEdit: true,
  ),
  'ficha · datos del paciente': () => PatientDataFormScreen(
    patientUid: 'p1',
    patientName: 'Juan Paredes',
    record: FakeRecordsService().patients['p1']!,
  ),
  'paciente · editar contacto': () => PatientDataFormScreen(
    patientUid: 'p1',
    patientName: 'Juan Paredes',
    record: FakeRecordsService().patients['p1']!,
    selfEdit: true,
  ),
  'ficha · estado funcional': () => FunctionalStateFormScreen(
    patientUid: 'p1',
    patientName: 'Juan Paredes',
    current: FakeRecordsService().patients['p1']!.estadoFuncional,
  ),
  'ficha · primera evaluación funcional': () => const FunctionalStateFormScreen(
    patientUid: 'p9',
    patientName: 'Paciente Nuevo',
  ),
  'cuidador · editar datos': () => CaregiverDataFormScreen(
    caregiverUid: 'c1',
    caregiverName: 'María González',
    record: FakeRecordsService().caregivers['c1']!,
  ),
  'admin · ficha del cuidador': () =>
      CaregiverRecordScreen(user: FakeAdminService().users[2]),
  'diagnóstico · nuevo': () => const DiagnosisEditScreen(
    diagnosis: Diagnosis(
      idPaciente: 'p1',
      tipo: DiagnosisType.principal,
      diagnostico: '',
    ),
    patientName: 'Juan Paredes',
  ),
  'diagnóstico · editar': () => DiagnosisEditScreen(
    diagnosis: FakeRecordsService().diagnoses.first,
    patientName: 'Juan Paredes',
    navItems: caregiverNavItems(),
    currentIndex: 1,
  ),
  'diagnóstico · solo lectura': () => DiagnosisEditScreen(
    diagnosis: FakeRecordsService().diagnoses.first,
    patientName: 'Juan Paredes',
    readOnly: true,
  ),
  'diagnóstico · anulado': () => DiagnosisEditScreen(
    diagnosis: FakeRecordsService().diagnoses.last,
    patientName: 'Juan Paredes',
  ),
  'ficha · evaluaciones anteriores': () => const EvaluationHistoryScreen(
    patientUid: 'p1',
    patientName: 'Juan Paredes',
  ),
  'dispositivo · historial de configuraciones': () => const DeviceHistoryScreen(
    patientUid: 'p1',
    patientName: 'Juan Paredes',
    canRestore: true,
  ),
  'dispositivo · historial de calibraciones': () => const DeviceHistoryScreen(
    patientUid: 'p1',
    patientName: 'Juan Paredes',
    initialTab: 'Calibraciones',
  ),
  'admin · registrar dispositivo': () => const DeviceFormScreen(),
  'admin · editar dispositivo': () =>
      DeviceFormScreen(device: FakeDeviceService().devices.first),
  'admin · dispositivo sin asignar': () =>
      DeviceFormScreen(device: FakeDeviceService().devices.last),
  'cuidador · registrar paciente': () => const PatientRegisterScreen(),
  'verificación en dos pasos · correo': () =>
      TwoFactorScreen(user: _user, destination: (_) => const Scaffold()),
  'verificación en dos pasos · SMS': () =>
      TwoFactorScreen(user: _smsUser, destination: (_) => const Scaffold()),
  'verificación en dos pasos · ajustes': () =>
      const TwoFactorSettingsScreen(user: _smsUser),
  'pagar · plan premium': () => CheckoutScreen(
    charge: const Charge(
      patientUid: 'p1',
      patientName: 'Juan Paredes',
      concept: PaymentConcept.premium,
      amount: 200000,
    ),
    plan: FakeBillingService().plans['p1']!,
  ),
  'pagar · dispositivo': () => const CheckoutScreen(
    charge: Charge(
      patientUid: 'p9',
      patientName: 'Paciente Nuevo',
      concept: PaymentConcept.dispositivo,
      amount: 1550000,
    ),
    plan: PremiumPlan(idPaciente: 'p9'),
  ),
  'comprobante · pendiente': () =>
      ReceiptScreen(payment: FakeBillingService().payments[0]),
  'comprobante · aprobado': () =>
      ReceiptScreen(payment: FakeBillingService().payments[1]),
  'comprobante · rechazado': () => const ReceiptScreen(
    payment: Payment(
      id: 'pay9',
      idPaciente: 'p1',
      nombrePaciente: 'Juan Paredes',
      concepto: PaymentConcept.premium,
      monto: 200000,
      metodo: PaymentMethod.transferencia,
      estado: PaymentStatus.rechazado,
      numero: 'HM-20261101-PAY09',
      nombreConfirmador: 'Administrador del sistema',
      motivoRechazo: 'No llegó la transferencia al banco.',
    ),
  ),
  'admin · registrar pago': () => PaymentRegisterScreen(
    plan: FakeBillingService().plans['p1']!,
    patientName: 'Juan Paredes',
    tariffs: const Tariffs(),
  ),
  'admin · reportes': () => const AdminReportsScreen(),
  'historial de ingresos · propio': () => const AccessHistoryScreen(uid: 'p1'),
  'historial de ingresos · de un paciente': () =>
      const AccessHistoryScreen(uid: 'p1', name: 'Juan Paredes'),
  'adjunto · foto': () => AttachmentViewerScreen(
    name: 'foto_estudio.jpg',
    bytes: Uint8List.fromList(const [1, 2, 3]),
  ),
};

late BuildContext _ctx;

void main() {
  setUpAll(() {
    AdminService.instance = FakeAdminService();
    CareService.instance = FakeCareService();
    RecordsService.instance = FakeRecordsService();
    DeviceService.instance = FakeDeviceService();
    BillingService.instance = FakeBillingService();
    TwoFactorService.instance = FakeTwoFactorService();
    AttachmentService.instance = FakeAttachmentService();
    FileAccess.instance = FakeFileAccess();
    SessionService.instance = FakeSessionService();
  });
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
