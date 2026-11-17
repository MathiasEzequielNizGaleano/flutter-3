import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headmouse_pro/l10n/app_strings.dart';
import 'package:headmouse_pro/screens/login_screen.dart';
import 'package:headmouse_pro/screens/two_factor_screen.dart';
import 'package:headmouse_pro/screens/two_factor_settings_screen.dart';
import 'package:headmouse_pro/services/auth_service.dart';
import 'package:headmouse_pro/services/two_factor_service.dart';
import 'package:headmouse_pro/widgets/gradient_button.dart';

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

void main() {
  group('datos', () {
    final sent = DateTime(2026, 11, 13, 10);
    TwoFactorChallenge challenge() => TwoFactorChallenge(
      code: '123456',
      channel: TwoFactorChannel.correo,
      destination: 'ma•••@correo.com',
      sentAt: sent,
    );

    test('el código correcto entra una sola vez', () {
      final c = challenge();
      expect(c.verify('123456', now: sent), VerifyResult.ok);
      expect(c.verify('123456', now: sent), VerifyResult.locked);
    });

    test('el código vence a los 5 minutos', () {
      expect(
        challenge().verify(
          '123456',
          now: sent.add(const Duration(minutes: 5, seconds: 1)),
        ),
        VerifyResult.expired,
      );
    });

    test('después de 5 intentos fallidos se bloquea', () {
      final c = challenge();
      for (var i = 0; i < 4; i++) {
        expect(c.verify('000000', now: sent), VerifyResult.wrong);
      }
      expect(c.remainingAttempts, 1);
      expect(c.verify('000000', now: sent), VerifyResult.locked);
      expect(c.verify('123456', now: sent), VerifyResult.locked);
    });

    test('enmascara el correo y el teléfono', () {
      expect(maskEmail('maria.gonzalez@correo.com'), 'ma•••@correo.com');
      expect(maskPhone('0982 111 222'), '••• ••• 222');
    });

    test('SMS sin teléfono cargado va por correo', () {
      const noPhone = TwoFactorSettings(channel: TwoFactorChannel.sms);
      expect(noPhone.effectiveChannel, TwoFactorChannel.correo);
      expect(
        TwoFactorSettings.fromMap({
          'metodo': 'sms',
          'telefono': '0981 234 567',
        }).effectiveChannel,
        TwoFactorChannel.sms,
      );
      expect(TwoFactorSettings.fromMap(null).channel, TwoFactorChannel.correo);

      final service = FakeTwoFactorService();
      expect(
        service
            .start(noPhone, email: 'a@b.com', channel: TwoFactorChannel.sms)
            .channel,
        TwoFactorChannel.correo,
      );
      expect(
        service.start(_smsUser.twoFactor, email: _smsUser.email).destination,
        '••• ••• 222',
      );
    });

    test('el código real tiene 6 dígitos al azar', () {
      final service = FirestoreTwoFactorService();
      final codes = {for (var i = 0; i < 20; i++) service.newCode()};
      expect(codes.every((c) => RegExp(r'^\d{6}$').hasMatch(c)), isTrue);
      expect(codes.length, greaterThan(1));
    });
  });

  group('pantallas', () {
    late FakeTwoFactorService service;

    setUp(() {
      service = FakeTwoFactorService();
      TwoFactorService.instance = service;
    });
    tearDown(() => AuthService.instance.current = null);

    Future<void> show(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pump();
    }

    Widget twoFactor(AppUser user) => TwoFactorScreen(
      user: user,
      destination: (_) => const Scaffold(body: Text('INICIO')),
    );

    testWidgets('el código llega (simulado) y al completarlo entra', (
      tester,
    ) async {
      await show(tester, twoFactor(_user));
      expect(find.text('Enviando el código por correo…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(
        find.textContaining('Tu código de HeadMouse Pro es 123456'),
        findsOneWidget,
      );
      expect(find.text('Para ma•••@correo.com'), findsOneWidget);
      expect(find.text('Reenviar código en 30 s'), findsOneWidget);

      await tester.tap(find.text('Completar código'));
      await tester.pumpAndSettle();
      expect(find.text('INICIO'), findsOneWidget);
      expect(service.calls, ['intento c1 ok correo']);
    });

    testWidgets('un código equivocado avisa cuántos intentos quedan', (
      tester,
    ) async {
      await show(tester, twoFactor(_user));
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), '000000');
      await tester.pump();
      expect(
        find.text('Código incorrecto. Te quedan 4 intentos.'),
        findsOneWidget,
      );
      expect(service.calls, ['intento c1 mal correo']);
      expect(find.text('INICIO'), findsNothing);
    });

    testWidgets('con teléfono cargado llega por SMS y se puede cambiar', (
      tester,
    ) async {
      await show(tester, twoFactor(_smsUser));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('SMS · HeadMouse Pro'), findsOneWidget);
      expect(find.text('Para ••• ••• 222'), findsOneWidget);

      await tester.tap(find.text('Recibirlo por correo'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Correo · HeadMouse Pro'), findsOneWidget);
    });

    testWidgets('reenviar el código espera 30 segundos', (tester) async {
      await show(tester, twoFactor(_user));
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Reenviar código en 30 s'),
            )
            .onPressed,
        isNull,
      );

      await tester.pump(const Duration(seconds: 30));
      await tester.tap(find.text('Reenviar código'));
      await tester.pump();
      expect(find.text('Enviando el código por correo…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('el login exige marcar "No soy un robot"', (tester) async {
      await show(tester, const LoginScreen());
      await tester.enterText(
        find.byType(TextFormField).first,
        'ana@correo.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'secreta123');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      ElevatedButton login() => tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text(AppStrings.login),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(login().onPressed, isNull);

      await tester.ensureVisible(find.text('No soy un robot'));
      await tester.tap(find.text('No soy un robot'));
      await tester.pump();
      expect(find.text('Verificando…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('No soy un robot'), findsOneWidget);
      expect(login().onPressed, isNotNull);
    });

    testWidgets('para recibirlo por SMS hay que cargar el número', (
      tester,
    ) async {
      String? message;
      await show(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              message = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => const TwoFactorSettingsScreen(user: _user),
                ),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SMS al celular'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(GradientButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ingresá el número donde vas a recibir el SMS.'),
        findsOneWidget,
      );
      expect(service.calls, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Número de celular'),
        '0981 234 567',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(GradientButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(service.calls, ['guardar sms 0981 234 567']);
      expect(message, 'Listo. Los próximos códigos te llegan por SMS.');
    });
  });
}
