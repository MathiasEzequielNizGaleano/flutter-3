import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headmouse_pro/ble/headmouse_ble.dart';
import 'package:headmouse_pro/screens/admin_devices_screen.dart';
import 'package:headmouse_pro/screens/caregiver_history_screen.dart';
import 'package:headmouse_pro/screens/caregiver_patients_screen.dart';
import 'package:headmouse_pro/screens/device_calibration_screen.dart';
import 'package:headmouse_pro/screens/device_form_screen.dart';
import 'package:headmouse_pro/screens/device_history_screen.dart';
import 'package:headmouse_pro/screens/device_settings_screen.dart';
import 'package:headmouse_pro/screens/evaluation_history_screen.dart';
import 'package:headmouse_pro/screens/patient_register_screen.dart';
import 'package:headmouse_pro/services/admin_service.dart';
import 'package:headmouse_pro/services/auth_service.dart';
import 'package:headmouse_pro/services/billing_service.dart';
import 'package:headmouse_pro/services/care_service.dart';
import 'package:headmouse_pro/services/device_service.dart';
import 'package:headmouse_pro/services/records_service.dart';
import 'package:headmouse_pro/utils/streams.dart';
import 'package:headmouse_pro/widgets/gradient_button.dart';

import 'fake_admin_service.dart';
import 'fake_billing_service.dart';
import 'fake_care_service.dart';
import 'fake_device_service.dart';
import 'fake_records_service.dart';

AppUser _user(String uid, UserRole role) => AppUser(
  uid: uid,
  email: '$uid@correo.com',
  role: role,
  nombres: role == UserRole.paciente ? 'Juan' : 'María',
  apellidos: role == UserRole.paciente ? 'Paredes' : 'González',
);

void main() {
  group('datos', () {
    test('la MAC se normaliza para usarla como id', () {
      expect(deviceIdFor('aa:bb:cc:dd:ee:ff'), 'AABBCCDDEEFF');
      expect(formatMac('aabbccddeeff'), 'AA:BB:CC:DD:EE:FF');
      expect(isValidMac('AA:BB:CC:DD:EE:FF'), isTrue);
      expect(isValidMac('aa-bb-cc-dd-ee-ff'), isTrue);
      expect(isValidMac('AA:BB:CC'), isFalse);
      expect(isValidMac('GG:BB:CC:DD:EE:FF'), isFalse);
    });

    test('una configuración se lee con los códigos del firmware', () {
      final entry = ConfigEntry.fromMap('x', {
        'idPaciente': 'p1',
        ...const DeviceConfig(
          umbralMovimiento: 4,
          velocidadMax: 15,
          delayMovimiento: 12,
          boton1: ButtonAction.mouseLeft,
          boton2: ButtonAction.mouseBack,
        ).toFirestore(),
        'vigente': true,
        'origen': 'recuperada',
      })!;
      expect(entry.config.boton2, ButtonAction.mouseBack);
      expect(entry.vigente, isTrue);
      expect(entry.origen, ConfigOrigin.recuperada);
      expect(entry.summary, 'Umbral 4 · Velocidad 15 · Delay 12 ms');
      expect(entry.buttons, 'Botón 1: Clic izquierdo · Botón 2: Atrás');
    });

    test('una configuración con valores raros se descarta', () {
      expect(
        ConfigEntry.fromMap('x', const {
          'umbralMovimiento': 4,
          'velocidadMax': 15,
          'delayMovimiento': 12,
          'boton1': 3,
          'boton2': 2,
        }),
        isNull,
      );
    });

    test('la calibración guarda el centro calculado', () {
      final c = CalibrationEntry.fromMap('x', const {
        'estadoResultado': 'exitosa',
        'centroAX': 120,
        'centroAY': -340,
        'motivo': 'Recolocación',
      });
      expect(c.exitosa, isTrue);
      expect(c.center, 'Centro AX 120 · AY -340');
      expect(
        CalibrationEntry.fromMap('y', const {
          'estadoResultado': 'error',
        }).exitosa,
        isFalse,
      );
    });

    test('la última calibración exitosa sale del historial', () {
      final history = FakeDeviceService().calibrations;
      expect(lastSuccessfulCalibration(history), DateTime(2026, 11, 12, 9, 15));
      expect(lastSuccessfulCalibration([history.last]), isNull);
    });

    test('juntar listas espera a que lleguen todas y ordena', () async {
      final merged = await mergeLatest([
        Stream.value([3, 1]),
        Stream.value([2]),
      ], compare: (a, b) => a.compareTo(b)).first;
      expect(merged, [1, 2, 3]);
      expect(await mergeLatest<int>(const []).first, isEmpty);
    });

    test('el paciente usa su propio HeadMouse con todos los permisos', () {
      addTearDown(() => AuthService.instance.current = null);
      expect(DeviceService.activePatient, isNull);

      AuthService.instance.current = _user('p1', UserRole.paciente);
      final self = DeviceService.activePatient!;
      expect(self.uid, 'p1');
      expect(self.puedeConfigurar && self.puedeCalibrar, isTrue);

      // La elección de un cuidador no vale para otra sesión.
      AuthService.instance.current = _user('c1', UserRole.cuidador);
      DeviceService.selectPatient(
        const DevicePatient(uid: 'p1', nombre: 'Juan', puedeCalibrar: false),
      );
      expect(DeviceService.activePatient!.puedeCalibrar, isFalse);
      AuthService.instance.current = _user('c2', UserRole.cuidador);
      expect(DeviceService.activePatient, isNull);
    });
  });

  group('pantallas', () {
    late FakeDeviceService devices;
    late FakeCareService care;

    setUp(() {
      devices = FakeDeviceService();
      care = FakeCareService();
      DeviceService.instance = devices;
      CareService.instance = care;
      RecordsService.instance = FakeRecordsService();
      AdminService.instance = FakeAdminService();
      BillingService.instance = FakeBillingService();
    });
    tearDown(() {
      AuthService.instance.current = null;
      DeviceService.selectPatient(null);
    });

    Future<void> show(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('el cuidador elige con qué paciente usar el HeadMouse', (
      tester,
    ) async {
      AuthService.instance.current = _user('c1', UserRole.cuidador);
      care.links.add(
        const CareAssignment(
          idCuidador: 'c1',
          idPaciente: 'p2',
          nombreCuidador: 'María González',
          nombrePaciente: 'Lucía Fernández',
          parentesco: 'Tutor/a',
          responsabilidad: Responsibility.secundario,
          permisos: CarePermissions(configurar: false),
        ),
      );
      await show(tester, const CaregiverPatientsScreen());
      await tap(tester, find.text('Conectar HeadMouse Pro'));

      expect(
        find.text('¿Con qué paciente vas a usar el HeadMouse?'),
        findsOneWidget,
      );
      // Abre la búsqueda Bluetooth (con animación): no se espera a que
      // termine.
      await tester.tap(find.text('Lucía Fernández').last);
      await tester.pump();
      final chosen = DeviceService.activePatient!;
      expect(chosen.uid, 'p2');
      expect(chosen.puedeConfigurar, isFalse);
      expect(chosen.puedeCalibrar, isTrue);
    });

    testWidgets('sin permisos de dispositivo no se puede conectar', (
      tester,
    ) async {
      AuthService.instance.current = _user('c1', UserRole.cuidador);
      care.links
        ..clear()
        ..add(
          const CareAssignment(
            idCuidador: 'c1',
            idPaciente: 'p1',
            nombreCuidador: 'María González',
            nombrePaciente: 'Juan Paredes',
            parentesco: 'Madre',
            responsabilidad: Responsibility.principal,
            permisos: CarePermissions(configurar: false, calibrar: false),
          ),
        );
      await show(tester, const CaregiverPatientsScreen());
      await tap(tester, find.text('Conectar HeadMouse Pro'));
      expect(
        find.textContaining('No tenés permiso para configurar'),
        findsOneWidget,
      );
      expect(DeviceService.activePatient, isNull);
    });

    testWidgets('sin permiso para configurar, todo queda deshabilitado', (
      tester,
    ) async {
      AuthService.instance.current = _user('c1', UserRole.cuidador);
      DeviceService.selectPatient(
        const DevicePatient(
          uid: 'p1',
          nombre: 'Juan Paredes',
          puedeConfigurar: false,
          puedeCalibrar: false,
        ),
      );
      await show(tester, const DeviceSettingsScreen(showPatientNav: false));
      expect(find.text('Paciente: Juan Paredes'), findsOneWidget);
      expect(
        find.textContaining('No tenés permiso para configurar el HeadMouse'),
        findsOneWidget,
      );
      final calibrate = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Calibración manual'),
      );
      expect(calibrate.onPressed, isNull);
    });

    testWidgets('avisa el restablecimiento pedido por el administrador', (
      tester,
    ) async {
      AuthService.instance.current = _user('p1', UserRole.paciente);
      await show(tester, const DeviceSettingsScreen(showPatientNav: false));
      expect(
        find.textContaining('El administrador pidió restablecer'),
        findsOneWidget,
      );
      expect(find.text('Historial de configuraciones'), findsOneWidget);
    });

    testWidgets('sin permiso para calibrar no se puede calibrar', (
      tester,
    ) async {
      AuthService.instance.current = _user('c1', UserRole.cuidador);
      DeviceService.selectPatient(
        const DevicePatient(
          uid: 'p1',
          nombre: 'Juan Paredes',
          puedeCalibrar: false,
        ),
      );
      await show(tester, const DeviceCalibrationScreen(showPatientNav: false));
      expect(
        find.textContaining('No tenés permiso para calibrar'),
        findsOneWidget,
      );
      final button = tester.widget<GradientButton>(find.byType(GradientButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('se recupera una configuración anterior del historial', (
      tester,
    ) async {
      DeviceConfig? restored;
      await show(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              restored = await Navigator.push<DeviceConfig>(
                context,
                MaterialPageRoute(
                  builder: (_) => const DeviceHistoryScreen(
                    patientUid: 'p1',
                    patientName: 'Juan Paredes',
                    canRestore: true,
                  ),
                ),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      );
      await tap(tester, find.text('abrir'));

      expect(find.text('Vigente'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      // La vigente no se ofrece: ya es la que tiene el equipo.
      expect(find.text('Usar esta configuración'), findsNWidgets(2));

      await tap(tester, find.text('Usar esta configuración').last);
      await tap(tester, find.text('Cargar'));
      expect(restored, devices.configs.last.config);
    });

    testWidgets('el historial muestra las calibraciones con su resultado', (
      tester,
    ) async {
      await show(
        tester,
        const DeviceHistoryScreen(
          patientUid: 'p1',
          patientName: 'Juan Paredes',
          initialTab: 'Calibraciones',
        ),
      );
      expect(find.text('Centro AX 120 · AY -340'), findsOneWidget);
      expect(find.text('No se pudo calibrar'), findsOneWidget);
      expect(find.text('Usar esta configuración'), findsNothing);
    });

    testWidgets('el administrador ve los equipos y filtra los sin asignar', (
      tester,
    ) async {
      await show(tester, const AdminDevicesScreen());
      expect(find.text('HeadMouse Pro · #0231'), findsOneWidget);
      expect(find.text('Paciente: Juan Paredes'), findsOneWidget);
      expect(find.textContaining('82 %'), findsOneWidget);

      await tap(tester, find.text('Sin asignar'));
      expect(find.text('HeadMouse Pro · #0231'), findsNothing);
      expect(find.text('HeadMouse Pro · #0045'), findsOneWidget);
    });

    testWidgets('registrar un equipo valida la MAC', (tester) async {
      await show(tester, const DeviceFormScreen());
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Código interno (ej. 0231)'),
        '0300',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'MAC Bluetooth (AA:BB:CC:DD:EE:FF)'),
        'AA:BB',
      );
      await tap(tester, find.text('Registrar'));
      expect(find.textContaining('MAC inválida'), findsOneWidget);
      expect(devices.calls, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'AA:BB'),
        'a1:b2:c3:d4:e5:f6',
      );
      await tap(tester, find.text('Registrar'));
      expect(devices.calls, [
        'alta 0300 A1:B2:C3:D4:E5:F6 sin paciente activo=true',
      ]);
    });

    testWidgets('el administrador pide restablecer valores de fábrica', (
      tester,
    ) async {
      await show(tester, DeviceFormScreen(device: devices.devices.first));
      await tap(tester, find.text('Restablecer valores de fábrica'));
      await tap(tester, find.text('Sí, restablecer'));
      expect(devices.calls, ['restablecer AABBCCDDEEFF']);
    });

    testWidgets('el historial del cuidador junta toda la actividad', (
      tester,
    ) async {
      AuthService.instance.current = _user('c1', UserRole.cuidador);
      await show(tester, const CaregiverHistoryScreen());
      expect(find.text('Calibración completada'), findsOneWidget);
      expect(find.text('Configuración guardada'), findsWidgets);
      expect(find.text('Diagnóstico principal'), findsOneWidget);

      await tap(tester, find.text('Calibración').first);
      expect(find.text('Configuración guardada'), findsNothing);
      expect(find.text('No se pudo calibrar'), findsOneWidget);
    });

    testWidgets('el cuidador registra un paciente nuevo', (tester) async {
      AuthService.instance.current = _user('c1', UserRole.cuidador);
      await show(tester, const PatientRegisterScreen());
      Future<void> type(String hint, String text) async {
        final field = find.widgetWithText(TextFormField, hint);
        await tester.ensureVisible(field);
        await tester.enterText(field, text);
      }

      await type('Nombres', 'Pedro');
      await type('Apellidos', 'Benítez');
      await type('Documento (cédula o pasaporte)', '4.123.456');
      await type('Correo electrónico', 'pedro@correo.com');
      await type('Contraseña inicial', 'Clave-Segura-2026');
      await tap(tester, find.text('Parentesco o relación'));
      await tester.tap(find.text('Hijo/a').last);
      await tester.pumpAndSettle();
      await tap(
        tester,
        find.widgetWithText(GradientButton, 'Registrar paciente'),
      );

      expect(care.calls, [
        'registrar Pedro Benítez pedro@correo.com 4123456 Hijo/a principal',
      ]);
    });

    testWidgets('se ven las evaluaciones funcionales anteriores', (
      tester,
    ) async {
      await show(
        tester,
        const EvaluationHistoryScreen(
          patientUid: 'p1',
          patientName: 'Juan Paredes',
        ),
      );
      expect(find.text('2 OCT 2026 · ACTUAL'), findsOneWidget);
      expect(find.text('20 ABR 2026'), findsOneWidget);
    });
  });
}
