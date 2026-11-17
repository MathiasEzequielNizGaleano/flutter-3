import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headmouse_pro/screens/admin_panel_screen.dart';
import 'package:headmouse_pro/screens/admin_reports_screen.dart';
import 'package:headmouse_pro/services/admin_service.dart';
import 'package:headmouse_pro/services/auth_service.dart';
import 'package:headmouse_pro/services/device_service.dart';
import 'package:headmouse_pro/services/records_service.dart';
import 'package:headmouse_pro/services/reports.dart';

import 'fake_admin_service.dart';
import 'fake_device_service.dart';
import 'fake_records_service.dart';

void main() {
  group('cálculo', () {
    final users = FakeAdminService().users;
    final records = FakeRecordsService().patients;
    final devices = FakeDeviceService().devices;
    final calibrations = FakeDeviceService().calibrations;

    AdminReport build({int days = 30, DateTime? now}) => AdminReport.build(
      users: users,
      records: records,
      devices: devices,
      calibrations: calibrations,
      days: days,
      now: now ?? DateTime(2026, 11, 16),
    );

    test('cuenta pacientes activos, de baja y con HeadMouse', () {
      final r = build();
      expect(r.activePatients, 1);
      expect(r.inactivePatients, 1);
      expect(r.patientsWithDevice, 1);
    });

    test('reparte el estado funcional en el orden de la escala', () {
      final r = build();
      expect(
        [for (final t in r.assistance) '${t.label} ${t.count}'],
        ['Independiente 0', 'Parcial 1', 'Dependiente 0'],
      );
      expect(r.cervical[1].label, 'Parcial');
      expect(r.cervical[1].count, 1);
      expect(r.headControl.first.label, 'Estable');
      expect(r.headControl.first.count, 1);
    });

    test('agrega "Sin evaluar" para los pacientes sin datos', () {
      final r = AdminReport.build(
        users: [
          ...users,
          const ManagedUser(
            uid: 'p9',
            email: 'p9@correo.com',
            role: UserRole.paciente,
          ),
        ],
        records: records,
        devices: devices,
        calibrations: calibrations,
        days: 30,
        now: DateTime(2026, 11, 16),
      );
      expect(r.assistance.last.label, 'Sin evaluar');
      expect(r.assistance.last.count, 1);
    });

    test('resume los dispositivos y las versiones de firmware', () {
      final r = build();
      expect(r.devices, 2);
      expect(r.activeDevices, 1);
      expect(r.connectedDevices, 0);
      expect(r.unassignedDevices, 0);
      expect(r.lowBattery, 0);
      expect([
        for (final t in r.firmware) '${t.label} ${t.count}',
      ], containsAll(['1.2.0 1', 'Sin dato 1']));
    });

    test('cuenta las calibraciones del período', () {
      final r = build();
      expect(r.calibrations, 2);
      expect(r.successfulCalibrations, 1);
      expect(r.failedCalibrations, 1);
      expect(r.uncalibratedPatients, 0);
      final p1 = r.byPatient.single;
      expect(p1.inPeriod, 2);
      expect(p1.failedInPeriod, 1);
      expect(p1.last, DateTime(2026, 11, 12, 9, 15));
    });

    test('fuera del período el paciente queda sin calibrar', () {
      final r = build(days: 7, now: DateTime(2026, 11, 25));
      expect(r.calibrations, 0);
      expect(r.uncalibratedPatients, 1);
      // La última exitosa se sigue mostrando aunque sea vieja.
      expect(r.byPatient.single.last, DateTime(2026, 11, 12, 9, 15));
    });

    test('quien nunca se calibró va primero', () {
      final r = AdminReport.build(
        users: [
          ...users,
          const ManagedUser(
            uid: 'p9',
            email: 'p9@correo.com',
            role: UserRole.paciente,
            nombres: 'Ana',
            apellidos: 'Benítez',
          ),
        ],
        records: records,
        devices: devices,
        calibrations: calibrations,
        days: 30,
        now: DateTime(2026, 11, 16),
      );
      expect([for (final p in r.byPatient) p.uid], ['p9', 'p1']);
      expect(r.uncalibratedPatients, 1);
    });
  });

  group('pantalla', () {
    setUp(() {
      AdminService.instance = FakeAdminService();
      RecordsService.instance = FakeRecordsService();
      DeviceService.instance = FakeDeviceService();
    });

    Future<void> pump(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();
    }

    testWidgets('el panel abre los reportes', (tester) async {
      await pump(tester, const AdminPanelScreen());

      await tester.tap(
        find.text('Reportes de pacientes, dispositivos y calibraciones'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminReportsScreen), findsOneWidget);
    });

    testWidgets('muestra pacientes, dispositivos y calibraciones', (
      tester,
    ) async {
      await pump(tester, const AdminReportsScreen());

      expect(find.text('Nivel de asistencia'), findsOneWidget);
      expect(find.text('Con HeadMouse'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Parcial: 1 de 1 pacientes, 100 por ciento'),
        findsNWidgets(2),
      );
      await tester.scrollUntilVisible(
        find.text('Juan Paredes'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Última exitosa: 12 nov 2026'), findsOneWidget);
    });

    testWidgets('el período cambia las calibraciones contadas', (tester) async {
      await pump(tester, const AdminReportsScreen());

      await tester.scrollUntilVisible(
        find.text('90 días'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('90 días'));
      await tester.pumpAndSettle();

      expect(find.textContaining('últimos 90 días'), findsOneWidget);
    });
  });
}
