import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headmouse_pro/navigation/nav_items.dart';
import 'package:headmouse_pro/screens/assignment_form_screen.dart';
import 'package:headmouse_pro/screens/patient_caregivers_screen.dart';
import 'package:headmouse_pro/services/admin_service.dart';
import 'package:headmouse_pro/services/auth_service.dart';
import 'package:headmouse_pro/services/care_service.dart';

import 'fake_admin_service.dart';
import 'fake_care_service.dart';

void main() {
  group('CareAssignment', () {
    test('lee un documento de asignaciones', () {
      final a = CareAssignment.fromMap({
        'idCuidador': 'c1',
        'idPaciente': 'p1',
        'nombreCuidador': 'María González',
        'nombrePaciente': 'Juan Paredes',
        'parentesco': 'Madre',
        'tipoResponsabilidad': 'principal',
        'puedeVerDatos': true,
        'puedeEditarDatos': false,
        'puedeConfigurar': true,
        'puedeCalibrar': false,
        'activo': true,
        'fechaAsignacion': Timestamp.fromDate(DateTime(2026, 3, 4)),
      });
      expect(a.id, 'c1_p1');
      expect(a.relation, 'Madre · Principal');
      expect(a.permisos.summary, 'Ver, Configurar');
      expect(a.activo, isTrue);
      expect(a.fechaAsignacion, DateTime(2026, 3, 4));
      expect(a.fechaFin, isNull);
    });

    test('sin campos: sin permisos, inactivo y secundario', () {
      final a = CareAssignment.fromMap({});
      expect(a.activo, isFalse);
      expect(a.permisos.summary, 'Sin permisos');
      expect(a.responsabilidad, Responsibility.secundario);
      expect(a.relation, 'Secundario');
    });

    test('los permisos se guardan con los nombres de las reglas', () {
      const p = CarePermissions(editarDatos: true, calibrar: false);
      expect(p.toMap(), {
        'puedeVerDatos': true,
        'puedeEditarDatos': true,
        'puedeConfigurar': true,
        'puedeCalibrar': false,
      });
      expect(CarePermissions.fromMap(p.toMap()), p);
    });

    test('id fijo cuidador_paciente', () {
      expect(CareAssignment.idFor('abc', 'xyz'), 'abc_xyz');
    });
  });

  group('barra del paciente', () {
    tearDown(() => AuthService.instance.current = null);

    AppUser patient({required bool hasCaregivers}) => AppUser(
      uid: 'p1',
      email: 'juan@correo.com',
      role: UserRole.paciente,
      nombres: 'Juan',
      apellidos: 'Paredes',
      hasCaregivers: hasCaregivers,
    );

    List<String> labels() => [for (final i in patientNavItems()) i.label];

    test('sin cuidadores muestra Facturación', () {
      AuthService.instance.current = patient(hasCaregivers: false);
      expect(labels(), [
        'Inicio',
        'Dispositivo',
        'Historial',
        'Facturación',
        'Perfil',
      ]);
      expect(patientTabIndex(PatientTab.dispositivo), 1);
    });

    test('con cuidadores muestra Cuidadores', () {
      AuthService.instance.current = patient(hasCaregivers: true);
      expect(labels(), [
        'Inicio',
        'Cuidadores',
        'Dispositivo',
        'Historial',
        'Perfil',
      ]);
      expect(patientTabIndex(PatientTab.dispositivo), 2);
      expect(patientTabIndex(PatientTab.historial), 3);
    });
  });

  group('pantallas', () {
    late FakeCareService care;

    setUp(() {
      care = FakeCareService();
      CareService.instance = care;
      AdminService.instance = FakeAdminService();
    });

    Future<void> show(WidgetTester tester, Widget home) async {
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: home));
      await tester.pumpAndSettle();
    }

    testWidgets('el admin asigna un cuidador a un paciente', (tester) async {
      final patient = FakeAdminService().users.first;
      await show(tester, AssignmentFormScreen(fixed: patient));

      await tester.tap(find.text('Elegí el cuidador'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('María González · maria.gonzalez@correo.com').last,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parentesco o relación con el paciente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Madre').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Asignar'));
      await tester.tap(find.text('Asignar'));
      await tester.pumpAndSettle();
      expect(care.calls, [
        'asignar c1 p1 Madre principal Ver, Configurar, Calibrar',
      ]);
    });

    testWidgets('sin elegir cuidador no se asigna', (tester) async {
      await show(
        tester,
        AssignmentFormScreen(fixed: FakeAdminService().users.first),
      );
      await tester.ensureVisible(find.text('Asignar'));
      await tester.tap(find.text('Asignar'));
      await tester.pumpAndSettle();
      expect(find.text('Elegí un cuidador.'), findsOneWidget);
      expect(care.calls, isEmpty);
    });

    testWidgets('editar datos implica poder verlos', (tester) async {
      await show(
        tester,
        AssignmentFormScreen(fixed: FakeAdminService().users.first),
      );
      bool value(String label) => tester
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, label))
          .value;
      Future<void> toggle(String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      const ver = 'Ver sus datos';
      const editar = 'Editar sus datos y diagnósticos';
      await toggle(ver);
      expect((value(ver), value(editar)), (false, false));
      await toggle(editar);
      expect((value(ver), value(editar)), (true, true));
      await toggle(ver);
      expect((value(ver), value(editar)), (false, false));
    });

    testWidgets('el paciente ve solo vínculos vigentes y quita uno', (
      tester,
    ) async {
      await show(tester, const PatientCaregiversScreen());
      expect(find.text('María González'), findsOneWidget);
      expect(find.text('Ana Torres'), findsNothing);

      await tester.tap(find.text('María González'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Quitar cuidador'));
      await tester.tap(find.text('Quitar cuidador'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, quitar acceso'));
      await tester.pumpAndSettle();

      expect(care.calls, ['terminar c1_p1']);
      expect(find.text('María González ya no es tu cuidador.'), findsOneWidget);
    });
  });
}
