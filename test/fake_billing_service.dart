import 'package:headmouse_pro/services/billing_service.dart';

/// BillingService con un plan y pagos fijos en memoria, para tests sin
/// Firebase. Juan Paredes (p1) tiene Premium al día, el dispositivo pagado
/// y un pago de Premium por transferencia esperando confirmación.
class FakeBillingService extends BillingService {
  FakeBillingService() {
    final now = DateTime.now();
    final due = DateTime(now.year, now.month, now.day + 20, 12);
    plans = {
      'p1': PremiumPlan(
        idPaciente: 'p1',
        nombrePaciente: 'Juan Paredes',
        activo: true,
        proximoPago: due,
        ultimoCambio: 'Pago registrado (QR Bancard)',
        autorUltimoCambio: 'María González',
        fechaUltimoCambio: now.subtract(const Duration(days: 10)),
      ),
    };
    payments = [
      Payment(
        id: 'pay3',
        idPaciente: 'p1',
        nombrePaciente: 'Juan Paredes',
        concepto: PaymentConcept.premium,
        monto: 200000,
        metodo: PaymentMethod.transferencia,
        estado: PaymentStatus.pendiente,
        numero: 'HM-20261112-PAY03',
        referencia: '0045123',
        idPagador: 'c1',
        nombrePagador: 'María González',
        fecha: now.subtract(const Duration(days: 1)),
      ),
      Payment(
        id: 'pay2',
        idPaciente: 'p1',
        nombrePaciente: 'Juan Paredes',
        concepto: PaymentConcept.premium,
        monto: 200000,
        metodo: PaymentMethod.qr,
        estado: PaymentStatus.aprobado,
        numero: 'HM-20261103-PAY02',
        referencia: 'PGP-12345678',
        idPagador: 'c1',
        nombrePagador: 'María González',
        periodoHasta: due,
        fecha: now.subtract(const Duration(days: 10)),
      ),
      Payment(
        id: 'pay1',
        idPaciente: 'p1',
        nombrePaciente: 'Juan Paredes',
        concepto: PaymentConcept.dispositivo,
        monto: 1550000,
        metodo: PaymentMethod.transferencia,
        estado: PaymentStatus.aprobado,
        numero: 'HM-20260804-PAY01',
        referencia: '0039876',
        idPagador: 'p1',
        nombrePagador: 'Juan Paredes',
        fecha: DateTime(2026, 8, 4),
        nombreConfirmador: 'Administrador del sistema',
        fechaConfirmacion: DateTime(2026, 8, 5),
      ),
    ];
  }

  Tariffs tariffs = const Tariffs();
  late Map<String, PremiumPlan> plans;
  late List<Payment> payments;

  /// Acciones recibidas, para verificarlas en los tests.
  final calls = <String>[];

  // Los tests no tienen sesión: con uid vacío se usa el paciente p1.
  String _patient(String uid) => uid.isEmpty ? 'p1' : uid;

  List<Payment> _sorted(Iterable<Payment> list) =>
      list.toList()..sort(Payment.newestFirst);

  Payment _payment(
    Charge charge,
    PaymentMethod method,
    PaymentStatus status, {
    DateTime? until,
    String referencia = '',
  }) => Payment(
    id: 'nuevo',
    idPaciente: charge.patientUid,
    nombrePaciente: charge.patientName,
    concepto: charge.concept,
    monto: charge.amount,
    metodo: method,
    estado: status,
    segmento: charge.segment,
    numero: 'HM-20261113-NUEVO',
    referencia: referencia,
    periodoHasta: until,
    fecha: DateTime.now(),
  );

  @override
  Stream<Tariffs> watchTariffs() => Stream.value(tariffs);

  @override
  Future<void> saveTariffs(Tariffs before, Tariffs after) async {
    calls.add('tarifas ${after.changesFrom(before).join(', ')}');
    tariffs = after;
  }

  @override
  Stream<PremiumPlan> watchPlan(String patientUid, {String patientName = ''}) {
    final uid = _patient(patientUid);
    return Stream.value(
      plans[uid] ?? PremiumPlan(idPaciente: uid, nombrePaciente: patientName),
    );
  }

  @override
  Stream<List<PremiumPlan>> watchPlans() => Stream.value(plans.values.toList());

  @override
  Stream<List<Payment>> watchPayments(String patientUid) => Stream.value(
    _sorted(payments.where((p) => p.idPaciente == _patient(patientUid))),
  );

  @override
  Stream<List<Payment>> watchAllPayments() => Stream.value(_sorted(payments));

  @override
  Future<Payment> payWithQr(
    Charge charge,
    PremiumPlan plan, {
    required bool approved,
  }) async {
    calls.add(
      'qr ${charge.patientUid} ${charge.concept.id} ${charge.amount} '
      '${approved ? 'aprobado' : 'rechazado'}',
    );
    return _payment(
      charge,
      PaymentMethod.qr,
      approved ? PaymentStatus.aprobado : PaymentStatus.rechazado,
      until: approved && charge.concept == PaymentConcept.premium
          ? plan.nextDueAfterPayment()
          : null,
    );
  }

  @override
  Future<Payment> submitPayment(
    Charge charge, {
    required PaymentMethod method,
    String referencia = '',
  }) async {
    calls.add('informar ${charge.concept.id} ${method.id} $referencia');
    return _payment(
      charge,
      method,
      PaymentStatus.pendiente,
      referencia: referencia,
    );
  }

  @override
  Future<void> setRenewal(PremiumPlan plan, {required bool cancelado}) async =>
      calls.add('renovación ${plan.idPaciente} cancelado=$cancelado');

  @override
  Future<Payment> registerPayment(
    Charge charge,
    PremiumPlan plan, {
    required PaymentMethod method,
    String referencia = '',
  }) async {
    calls.add(
      'registrar ${charge.patientUid} ${charge.concept.id} ${method.id} '
      '${charge.amount}',
    );
    return _payment(
      charge,
      method,
      PaymentStatus.aprobado,
      until: charge.concept == PaymentConcept.premium
          ? plan.nextDueAfterPayment()
          : null,
    );
  }

  @override
  Future<void> confirmPayment(Payment payment, PremiumPlan plan) async =>
      calls.add('confirmar ${payment.id} ${plan.idPaciente}');

  @override
  Future<void> rejectPayment(Payment payment, String motivo) async =>
      calls.add('rechazar ${payment.id} $motivo');

  @override
  Future<void> endPlan(PremiumPlan plan) async =>
      calls.add('baja ${plan.idPaciente}');

  @override
  Future<void> setSegment(PremiumPlan plan, Segment segment) async =>
      calls.add('segmento ${plan.idPaciente} ${segment.id}');
}
