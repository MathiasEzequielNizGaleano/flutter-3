import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headmouse_pro/screens/admin_users_screen.dart';
import 'package:headmouse_pro/services/admin_service.dart';
import 'package:headmouse_pro/services/auth_service.dart';
import 'package:headmouse_pro/utils/date_format.dart';

import 'fake_admin_service.dart';

void main() {
  group('ManagedUser', () {
    test('lee un documento de usuarios', () {
      final user = ManagedUser.fromMap('abc', {
        'email': 'ana@correo.com',
        'rol': 'cuidador',
        'nombres': 'Ana',
        'apellidos': 'Duarte',
        'documento': '1234567',
        'estado': true,
        'fechaRegistro': Timestamp.fromDate(DateTime(2026, 9, 1, 10)),
      });
      expect(user.uid, 'abc');
      expect(user.role, UserRole.cuidador);
      expect(user.fullName, 'Ana Duarte');
      expect(user.initials, 'AD');
      expect(user.active, isTrue);
      expect(user.fechaRegistro, DateTime(2026, 9, 1, 10));
      expect(user.ultimoIngreso, isNull);
    });

    test('solo estado == false es una baja', () {
      expect(ManagedUser.fromMap('a', {'estado': false}).active, isFalse);
      expect(ManagedUser.fromMap('a', {}).active, isTrue);
    });

    test('rol desconocido queda como "Sin rol"', () {
      final user = ManagedUser.fromMap('a', {'rol': 'superusuario'});
      expect(user.role, isNull);
      expect(user.roleLabel, 'Sin rol');
    });

    test('sin nombre usa el correo', () {
      final user = ManagedUser.fromMap('a', {'email': 'zoe@correo.com'});
      expect(user.fullName, 'zoe@correo.com');
      expect(user.initials, 'Z');
    });

    test('ordena por apellido sin importar mayúsculas', () {
      const a = ManagedUser(
        uid: '1',
        email: '',
        role: null,
        apellidos: 'rojas',
      );
      const b = ManagedUser(
        uid: '2',
        email: '',
        role: null,
        apellidos: 'Paredes',
      );
      expect(([a, b]..sort(ManagedUser.compareByName)).first, b);
    });
  });

  group('AuditEvent', () {
    test('acceso exitoso', () {
      final event = AuditEvent.fromAccess({
        'tipoEvento': 'login',
        'resultado': 'exitoso',
        'nombreUsuario': 'María González',
        'rol': 'cuidador',
        'plataforma': 'android',
        'fechaHora': Timestamp.fromDate(DateTime(2026, 11, 12, 9, 12)),
      });
      expect(event.category, 'Login');
      expect(event.actor, 'María González');
      expect(event.action, 'Inició sesión');
      expect(event.metaLeft, 'Rol: Cuidador / tutor');
      expect(event.metaRight, 'Android');
      expect(event.failed, isFalse);
    });

    test('acceso viejo sin nombre ni rol', () {
      final event = AuditEvent.fromAccess({'tipoEvento': 'logout'});
      expect(event.actor, 'Usuario');
      expect(event.action, 'Cerró sesión');
      expect(event.metaLeft, isEmpty);
    });

    test('intento fallido se marca', () {
      final event = AuditEvent.fromAccess({
        'tipoEvento': 'login',
        'resultado': 'fallido',
      });
      expect(event.failed, isTrue);
      expect(event.action, 'Intento fallido de inicio de sesión');
    });

    test('cambio de auditoría', () {
      final event = AuditEvent.fromAudit({
        'categoria': 'Cambios de datos',
        'nombreActor': 'Admin',
        'rolActor': 'admin',
        'accion': 'Cambió el rol de Ana Duarte',
        'detalle': 'Paciente → Cuidador / tutor',
      });
      expect(event.actor, 'Admin');
      expect(event.metaLeft, 'Rol: Administrador');
      expect(event.metaRight, 'Paciente → Cuidador / tutor');
    });
  });

  group('formatEventTime', () {
    final now = DateTime(2026, 11, 12, 15, 30);

    test('hoy, ayer y fechas anteriores', () {
      expect(
        formatEventTime(DateTime(2026, 11, 12, 9, 5), now: now),
        'Hoy 09:05',
      );
      expect(
        formatEventTime(DateTime(2026, 11, 11, 18, 30), now: now),
        'Ayer 18:30',
      );
      expect(
        formatEventTime(DateTime(2026, 9, 3, 0, 0), now: now),
        '3 sep 00:00',
      );
      expect(
        formatEventTime(DateTime(2025, 12, 31, 23, 59), now: now),
        '31 dic 2025 23:59',
      );
    });

    test('ayer cruzando el cambio de mes', () {
      final firstDay = DateTime(2026, 12, 1, 8);
      expect(
        formatEventTime(DateTime(2026, 11, 30, 22), now: firstDay),
        'Ayer 22:00',
      );
    });
  });

  group('pantalla de usuarios', () {
    late FakeAdminService fake;

    setUp(() {
      fake = FakeAdminService();
      AdminService.instance = fake;
    });

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: AdminUsersScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('filtra los dados de baja', (tester) async {
      await open(tester);
      expect(find.text('Juan Paredes'), findsOneWidget);
      // El chip queda fuera de pantalla en un celular angosto.
      await tester.ensureVisible(find.text('Inactivos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inactivos'));
      await tester.pumpAndSettle();
      expect(find.text('Juan Paredes'), findsNothing);
      expect(find.text('Lucía Fernández Benítez de la Cruz'), findsOneWidget);
    });

    testWidgets('dar de baja pide confirmación y llama al servicio', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Juan Paredes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dar de baja'));
      await tester.pumpAndSettle();
      expect(find.text('¿Dar de baja a Juan Paredes?'), findsOneWidget);
      expect(fake.calls, isEmpty);

      await tester.tap(find.text('Sí, dar de baja'));
      await tester.pumpAndSettle();
      expect(fake.calls, ['estado p1 false']);
      expect(find.text('Juan Paredes quedó dado de baja.'), findsOneWidget);
    });

    testWidgets('cambiar rol', (tester) async {
      await open(tester);
      await tester.tap(find.text('María González'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambiar rol'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Administrador'));
      await tester.pumpAndSettle();
      expect(fake.calls, ['rol c1 admin']);
    });
  });
}
