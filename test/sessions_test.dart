import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headmouse_pro/navigation/session_guard.dart';
import 'package:headmouse_pro/screens/access_history_screen.dart';
import 'package:headmouse_pro/screens/login_screen.dart';
import 'package:headmouse_pro/screens/patient_profile_screen.dart';
import 'package:headmouse_pro/services/admin_service.dart';
import 'package:headmouse_pro/services/auth_service.dart';
import 'package:headmouse_pro/services/care_service.dart';
import 'package:headmouse_pro/services/records_service.dart';
import 'package:headmouse_pro/services/session_service.dart';

import 'fake_admin_service.dart';
import 'fake_care_service.dart';
import 'fake_records_service.dart';
import 'fake_session_service.dart';

const _patient = AppUser(
  uid: 'p1',
  email: 'juan.paredes@correo.com',
  role: UserRole.paciente,
  nombres: 'Juan',
  apellidos: 'Paredes',
);

void main() {
  group('registros de acceso', () {
    test('una contraseña incorrecta muestra el correo escrito', () {
      final e = AuditEvent.fromAccess({
        'correo': 'juan.paredes@correo.com',
        'tipoEvento': 'login',
        'resultado': 'fallido',
        'plataforma': 'android',
      });
      expect(e.actor, 'juan.paredes@correo.com');
      expect(e.action, 'Intento fallido de inicio de sesión');
      expect(e.metaLeft, 'Correo o contraseña incorrectos');
      expect(e.metaRight, 'Android');
      expect(e.failed, isTrue);
    });

    test('nombra los cierres de sesión', () {
      String action(String type) => AuditEvent.fromAccess({
        'nombreUsuario': 'Juan Paredes',
        'rol': 'paciente',
        'tipoEvento': type,
        'resultado': 'exitoso',
      }).action;

      expect(
        action('cierre_sesiones'),
        'Cerró la sesión en los demás dispositivos',
      );
      expect(
        action('logout_remoto'),
        'Se cerró su sesión desde otro dispositivo',
      );
      expect(
        action('logout_baja'),
        'Se cerró su sesión: la cuenta fue dada de baja',
      );
    });

    test('cada sesión tiene un id nuevo', () {
      final service = FakeSessionService()..begin();
      final first = service.sessionId;
      service.begin();
      expect(first, hasLength(16));
      expect(service.sessionId, isNot(first));
    });
  });

  group('pantallas', () {
    late FakeSessionService sessions;

    setUp(() {
      sessions = FakeSessionService();
      SessionService.instance = sessions;
      AdminService.instance = FakeAdminService();
      CareService.instance = FakeCareService();
      RecordsService.instance = FakeRecordsService();
      AuthService.instance.current = _patient;
    });
    tearDown(() {
      SessionGuard.stop();
      AuthService.instance.current = null;
    });

    Future<void> pump(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(navigatorKey: SessionGuard.navigatorKey, home: screen),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    testWidgets('el historial muestra los ingresos y filtra los fallidos', (
      tester,
    ) async {
      await pump(tester, const AccessHistoryScreen(uid: 'p1'));

      expect(
        find.text('Últimos 3 registros. 1 intento fallido.'),
        findsOneWidget,
      );
      expect(find.text('Inició sesión'), findsOneWidget);
      expect(find.text('Cerró sesión'), findsOneWidget);

      await tapText(tester, 'Fallidos');
      expect(
        find.text('Código de verificación incorrecto (correo)'),
        findsOneWidget,
      );
      expect(find.text('Inició sesión'), findsNothing);
    });

    testWidgets('el perfil abre el historial de ingresos propio', (
      tester,
    ) async {
      await pump(tester, const PatientProfileScreen());

      await tapText(tester, 'Ver historial de ingresos');

      expect(find.text('Historial de ingresos'), findsOneWidget);
      expect(sessions.calls, ['historial p1']);
    });

    testWidgets('cierra la sesión en los otros dispositivos', (tester) async {
      await pump(tester, const PatientProfileScreen());

      await tapText(tester, 'Cerrar sesión en los otros dispositivos');
      expect(find.text('¿Cerrar las otras sesiones?'), findsOneWidget);
      await tester.tap(find.text('Cerrar las otras'));
      await tester.pumpAndSettle();

      expect(sessions.calls, ['cerrar otras p1']);
      expect(
        find.text('Listo. Se cerró tu sesión en los demás dispositivos.'),
        findsOneWidget,
      );
    });

    testWidgets('si la cierran desde otro dispositivo vuelve al login', (
      tester,
    ) async {
      await pump(tester, const PatientProfileScreen());
      SessionGuard.start(_patient);

      sessions.ends.add(SessionEnd.closedElsewhere);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(PatientProfileScreen), findsNothing);
      expect(find.text(SessionEnd.closedElsewhere.message), findsOneWidget);
      expect(AuthService.instance.current, isNull);
    });

    testWidgets('si dan de baja la cuenta vuelve al login con el motivo', (
      tester,
    ) async {
      await pump(tester, const PatientProfileScreen());
      SessionGuard.start(_patient);

      sessions.ends.add(SessionEnd.deactivated);
      await tester.pumpAndSettle();

      expect(
        find.text('Tu cuenta fue dada de baja. Contactá al administrador.'),
        findsOneWidget,
      );
    });

    testWidgets('después de cerrar sesión ya no vigila', (tester) async {
      await pump(tester, const PatientProfileScreen());
      SessionGuard.start(_patient);
      SessionGuard.stop();

      sessions.ends.add(SessionEnd.closedElsewhere);
      await tester.pumpAndSettle();

      expect(find.byType(PatientProfileScreen), findsOneWidget);
      expect(AuthService.instance.current, isNotNull);
    });
  });
}
