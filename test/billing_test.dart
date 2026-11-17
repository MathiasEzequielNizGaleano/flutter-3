import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headmouse_pro/screens/admin_plans_screen.dart';
import 'package:headmouse_pro/screens/billing_screen.dart';
import 'package:headmouse_pro/screens/device_history_screen.dart';
import 'package:headmouse_pro/services/admin_service.dart';
import 'package:headmouse_pro/services/auth_service.dart';
import 'package:headmouse_pro/services/billing_service.dart';
import 'package:headmouse_pro/services/care_service.dart';
import 'package:headmouse_pro/services/device_service.dart';
import 'package:headmouse_pro/widgets/gradient_button.dart';

import 'fake_admin_service.dart';
import 'fake_billing_service.dart';
import 'fake_care_service.dart';
import 'fake_device_service.dart';

void main() {
  group('datos', () {
    test('montos en guaraníes', () {
      expect(formatGs(1550000), 'Gs. 1.550.000');
      expect(formatGs(200000), 'Gs. 200.000');
      expect(formatGs(999), 'Gs. 999');
      expect(parseGs('1.550.000'), 1550000);
      expect(parseGs('Gs 200000'), 200000);
      expect(parseGs(''), isNull);
      expect(parseGs('0'), isNull);
    });

    test('sumar un mes respeta el fin de mes', () {
      expect(addMonth(DateTime(2026, 1, 31)), DateTime(2026, 2, 28, 12));
      expect(addMonth(DateTime(2028, 1, 31)), DateTime(2028, 2, 29, 12));
      expect(addMonth(DateTime(2026, 12, 15)), DateTime(2027, 1, 15, 12));
    });

    test('estado del plan según la fecha de pago', () {
      final due = DateTime(2026, 11, 20, 12);
      final plan = PremiumPlan(
        idPaciente: 'p1',
        activo: true,
        proximoPago: due,
      );
      // El día del vencimiento todavía es Premium.
      expect(plan.statusOn(DateTime(2026, 11, 20, 23)), PlanStatus.premium);
      expect(plan.statusOn(DateTime(2026, 11, 21)), PlanStatus.vencido);

      final cancelled = PremiumPlan(
        idPaciente: 'p1',
        activo: true,
        cancelado: true,
        proximoPago: due,
      );
      expect(cancelled.statusOn(DateTime(2026, 11, 19)), PlanStatus.premium);
      expect(cancelled.statusOn(DateTime(2026, 11, 21)), PlanStatus.sinPlan);
      expect(
        const PremiumPlan(idPaciente: 'p1').statusOn(DateTime(2026)),
        PlanStatus.sinPlan,
      );
    });

    test('pagar un mes suma a lo ya pagado o cuenta desde hoy', () {
      final plan = PremiumPlan(
        idPaciente: 'p1',
        activo: true,
        proximoPago: DateTime(2026, 11, 20, 12),
      );
      expect(
        plan.nextDueAfterPayment(now: DateTime(2026, 11, 13)),
        DateTime(2026, 12, 20, 12),
      );
      // Vencido: se cuenta desde hoy.
      expect(
        plan.nextDueAfterPayment(now: DateTime(2026, 12, 5)),
        DateTime(2027, 1, 5, 12),
      );
      expect(
        const PremiumPlan(
          idPaciente: 'p1',
        ).nextDueAfterPayment(now: DateTime(2026, 11, 13, 18)),
        DateTime(2026, 12, 13, 12),
      );
    });

    test('tarifas por segmento y cambios para Auditoría', () {
      const tariffs = Tariffs();
      expect(tariffs.amountFor(PaymentConcept.premium, Segment.b2c), 200000);
      expect(tariffs.amountFor(PaymentConcept.premium, Segment.b2b), 500000);
      expect(
        tariffs.amountFor(PaymentConcept.capacitacion, Segment.b2c),
        350000,
      );
      final after = tariffs.copyWith(Tariff.premiumB2C, 250000);
      expect(after.changesFrom(tariffs), [
        'Plan Premium B2C: Gs. 200.000 → Gs. 250.000',
      ]);
      // Un monto inválido en Firestore no se usa.
      expect(
        Tariffs.fromMap({
          'premium_B2C': 250000,
          'soporte_B2C': 0,
        }).of(Tariff.soporteB2C),
        210000,
      );
    });

    test('número de comprobante', () {
      expect(
        receiptNumber('abcde12345', DateTime(2026, 11, 13)),
        'HM-20261113-ABCDE',
      );
    });
  });

  group('pantallas', () {
    late FakeBillingService billing;

    setUp(() {
      billing = FakeBillingService();
      BillingService.instance = billing;
      CareService.instance = FakeCareService();
      AdminService.instance = FakeAdminService();
      DeviceService.instance = FakeDeviceService();
    });
    tearDown(() => AuthService.instance.current = null);

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

    testWidgets('activar Premium con QR: la pasarela simulada lo aprueba', (
      tester,
    ) async {
      billing.plans.clear();
      billing.payments.clear();
      await show(tester, const BillingScreen());
      expect(find.text('Sin plan'), findsOneWidget);
      expect(find.text('Todavía no hay pagos registrados.'), findsOneWidget);

      await tap(tester, find.text('Activar Plan Premium'));
      expect(find.text('Gs. 200.000'), findsOneWidget);
      await tap(tester, find.text('Pagar con QR'));
      expect(find.text('Simular pago aprobado'), findsOneWidget);

      await tap(tester, find.text('Simular pago aprobado'));
      expect(find.text('¡Pago aprobado!'), findsOneWidget);
      expect(billing.calls, ['qr p1 premium 200000 aprobado']);

      await tap(tester, find.text('Volver a Facturación'));
      expect(
        find.text('Pago aprobado. Comprobante HM-20261113-NUEVO.'),
        findsOneWidget,
      );
    });

    testWidgets('un pago rechazado se puede volver a intentar', (tester) async {
      billing.plans.clear();
      billing.payments.clear();
      await show(tester, const BillingScreen());
      await tap(tester, find.text('Activar Plan Premium'));
      await tap(tester, find.text('Pagar con QR'));
      await tap(tester, find.text('Simular pago rechazado'));

      expect(find.text('Pago rechazado'), findsOneWidget);
      expect(billing.calls, ['qr p1 premium 200000 rechazado']);
      await tap(tester, find.text('Intentar de nuevo'));
      expect(find.text('Pagar con QR'), findsOneWidget);
    });

    testWidgets('la transferencia pide el número de operación', (tester) async {
      billing.payments.clear();
      await show(tester, const BillingScreen());
      await tap(tester, find.text('Pagar el dispositivo'));
      expect(find.text('Gs. 1.550.000'), findsOneWidget);

      await tap(tester, find.text('Transferencia bancaria'));
      await tap(tester, find.text('Enviar comprobante'));
      expect(
        find.text('Escribí el número de operación que te dio el banco.'),
        findsOneWidget,
      );
      expect(billing.calls, isEmpty);

      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'N° de operación de la transferencia',
        ),
        '778899',
      );
      await tap(tester, find.text('Enviar comprobante'));
      expect(find.text('Comprobante enviado'), findsOneWidget);
      expect(billing.calls, ['informar dispositivo transferencia 778899']);
    });

    testWidgets('con un pago pendiente no se ofrece pagar otra vez', (
      tester,
    ) async {
      await show(tester, const BillingScreen());
      expect(find.text('Activo'), findsOneWidget);
      expect(
        find.textContaining('Pago pendiente de confirmación'),
        findsOneWidget,
      );
      expect(find.text('Pagar el próximo mes'), findsNothing);
      expect(find.text('Pagado'), findsOneWidget);
      expect(find.text('Plan Premium'), findsWidgets);
    });

    testWidgets('cancelar la renovación pide confirmación', (tester) async {
      billing.payments.removeWhere((p) => p.pendiente);
      await show(tester, const BillingScreen());
      await tap(tester, find.text('Cancelar la renovación'));
      expect(find.text('¿Cancelar la renovación?'), findsOneWidget);

      await tap(tester, find.text('Cancelar renovación'));
      expect(billing.calls, ['renovación p1 cancelado=true']);
    });

    testWidgets('el cuidador ve la facturación de su paciente', (tester) async {
      await show(tester, const BillingScreen(caregiverNav: true));
      expect(find.text('Paciente: Juan Paredes'), findsOneWidget);
      expect(find.text('Activo'), findsOneWidget);
    });

    testWidgets('el administrador confirma y rechaza pagos pendientes', (
      tester,
    ) async {
      await show(tester, const AdminPlansScreen());
      expect(find.text('PAGOS POR CONFIRMAR (1)'), findsOneWidget);

      await tap(tester, find.text('Confirmar pago'));
      expect(find.text('¿Confirmar el pago?'), findsOneWidget);
      await tap(tester, find.text('Confirmar pago').last);
      expect(billing.calls, ['confirmar pay3 p1']);

      await tap(tester, find.text('Rechazar'));
      await tester.enterText(find.byType(TextField).last, 'No llegó');
      await tap(tester, find.text('Rechazar pago'));
      expect(billing.calls.last, 'rechazar pay3 No llegó');
    });

    testWidgets('el administrador registra un pago en efectivo', (
      tester,
    ) async {
      await show(tester, const AdminPlansScreen());
      expect(find.text('Juan Paredes'), findsOneWidget);
      expect(find.text('HeadMouse Pro · #0231'), findsOneWidget);

      await tap(tester, find.text('Registrar pago'));
      expect(find.text('Monto según tarifas'), findsOneWidget);
      await tap(tester, find.widgetWithText(GradientButton, 'Registrar pago'));
      expect(billing.calls, ['registrar p1 premium efectivo 200000']);
      expect(find.textContaining('queda Premium hasta el'), findsOneWidget);
    });

    testWidgets('el administrador da de baja y cambia el segmento', (
      tester,
    ) async {
      await show(tester, const AdminPlansScreen());
      await tap(tester, find.text('Dar de baja'));
      await tap(tester, find.text('Dar de baja').last);
      await tap(tester, find.text('Pasar a B2B'));
      await tap(tester, find.text('Pasar a B2B').last);
      expect(billing.calls, ['baja p1', 'segmento p1 B2B']);
    });

    testWidgets('el administrador guarda las tarifas', (tester) async {
      await show(tester, const AdminPlansScreen());
      final premium = find.widgetWithText(TextField, '200.000');
      await tester.ensureVisible(premium);
      await tester.enterText(premium, '250.000');
      await tap(tester, find.text('Guardar tarifas'));
      expect(billing.calls, [
        'tarifas Plan Premium B2C: Gs. 200.000 → Gs. 250.000',
      ]);
    });

    testWidgets('sin Premium, recuperar una configuración avisa', (
      tester,
    ) async {
      billing.plans.clear();
      await show(
        tester,
        const DeviceHistoryScreen(
          patientUid: 'p1',
          patientName: 'Juan Paredes',
          canRestore: true,
        ),
      );
      expect(find.text('Usar esta configuración · Premium'), findsNWidgets(2));

      await tap(tester, find.text('Usar esta configuración · Premium').first);
      expect(find.text('Función del Plan Premium'), findsOneWidget);
    });
  });
}
