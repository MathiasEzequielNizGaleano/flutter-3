// Tarifas, Plan Premium y pagos (Facturación) en Firestore.
//
// - Tarifas             → `tarifas/actual` (solo el administrador las cambia)
// - Plan Premium        → `planes/{idPaciente}`
// - Pagos y comprobantes → `pacientes/{idPaciente}/pagos/{id}`
//
// La pasarela de pagos es SIMULADA. El proyecto usa el plan gratuito de
// Firebase (Spark), que no permite Cloud Functions ni guardar las claves
// privadas de Pagopar o Bancard. Por eso el pago con QR se aprueba o rechaza
// desde la misma app ("Simular pago aprobado"), y la transferencia y el
// efectivo quedan pendientes hasta que el administrador los confirma. Todo lo
// demás es real: el plan, los vencimientos, los comprobantes y la auditoría
// quedan guardados en Firestore. Nada se borra.

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/date_format.dart';
import 'audit.dart';
import 'auth_service.dart';
import 'records_service.dart' show Choice;

String _text(Object? value) => value is String ? value : '';
DateTime? _time(Object? value) => value is Timestamp ? value.toDate() : null;

/// "1.550.000".
String formatAmount(int amount) {
  final digits = amount.abs().toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    groups.insert(0, digits.substring(max(0, end - 3), end));
  }
  return '${amount < 0 ? '-' : ''}${groups.join('.')}';
}

/// "Gs. 1.550.000".
String formatGs(int amount) => 'Gs. ${formatAmount(amount)}';

/// Lee un monto escrito a mano ("1.550.000", "Gs 200000"). `null` si no hay
/// un número mayor que cero.
int? parseGs(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty || digits.length > 12) return null;
  final value = int.parse(digits);
  return value > 0 ? value : null;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// El mismo día del mes siguiente (o el último día, si ese mes es más
/// corto: 31 ene → 28 feb). Se guarda al mediodía para que la zona horaria
/// nunca lo cambie de día.
DateTime addMonth(DateTime date) {
  final year = date.month == 12 ? date.year + 1 : date.year;
  final month = date.month == 12 ? 1 : date.month + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, min(date.day, lastDay), 12);
}

/// Cliente particular (B2C) o institución (B2B): define las tarifas.
enum Segment implements Choice {
  b2c('B2C', 'Particular (B2C)'),
  b2b('B2B', 'Institución (B2B)');

  const Segment(this.id, this.label);

  @override
  final String id;
  @override
  final String label;

  static Segment fromId(Object? id) => id == b2b.id ? b2b : b2c;
}

enum PaymentConcept implements Choice {
  premium('premium', 'Plan Premium'),
  dispositivo('dispositivo', 'HeadMouse Pro · pago único'),
  soporte('soporte', 'Soporte técnico sin plan'),
  capacitacion('capacitacion', 'Capacitación del personal');

  const PaymentConcept(this.id, this.label);

  @override
  final String id;
  @override
  final String label;

  static PaymentConcept fromId(Object? id) =>
      values.firstWhere((c) => c.id == id, orElse: () => premium);
}

enum PaymentMethod implements Choice {
  qr('qr', 'QR Bancard'),
  transferencia('transferencia', 'Transferencia bancaria'),
  efectivo('efectivo', 'Pago en efectivo');

  const PaymentMethod(this.id, this.label);

  @override
  final String id;
  @override
  final String label;

  static PaymentMethod fromId(Object? id) =>
      values.firstWhere((m) => m.id == id, orElse: () => efectivo);
}

enum PaymentStatus {
  aprobado('aprobado', 'Aprobado'),
  pendiente('pendiente', 'Pendiente'),
  rechazado('rechazado', 'Rechazado');

  const PaymentStatus(this.id, this.label);

  final String id;
  final String label;

  static PaymentStatus fromId(Object? id) =>
      values.firstWhere((s) => s.id == id, orElse: () => pendiente);
}

/// Montos que se cobran (tabla de tarifas del administrador).
enum Tariff {
  dispositivoB2C('dispositivo_B2C', 'Dispositivo B2C', 'Pago único', 1550000),
  dispositivoB2B(
    'dispositivo_B2B',
    'Dispositivo B2B',
    'Pago único por unidad',
    1380000,
  ),
  premiumB2C('premium_B2C', 'Plan Premium B2C', 'Mensual', 200000),
  premiumB2B(
    'premium_B2B',
    'Plan Premium B2B',
    'Mensual, institucional',
    500000,
  ),
  soporteB2C('soporte_B2C', 'Soporte sin plan B2C', 'Por solicitud', 210000),
  soporteB2B('soporte_B2B', 'Soporte sin plan B2B', 'Por solicitud', 300000),
  capacitacion(
    'capacitacion_B2B',
    'Capacitación del personal',
    'Por evento, B2B',
    350000,
  );

  const Tariff(this.key, this.label, this.sub, this.defaultAmount);

  /// Campo en `tarifas/actual`: `{concepto}_{segmento}`.
  final String key;
  final String label;
  final String sub;
  final int defaultAmount;
}

@immutable
class Tariffs {
  const Tariffs([this._amounts = const {}]);

  factory Tariffs.fromMap(Map<String, dynamic>? data) => Tariffs({
    for (final t in Tariff.values)
      if (data?[t.key] case final int amount when amount > 0) t: amount,
  });

  final Map<Tariff, int> _amounts;

  int of(Tariff tariff) => _amounts[tariff] ?? tariff.defaultAmount;

  /// Lo que cuesta [concept] para un cliente [segment]. La capacitación
  /// tiene un solo precio.
  int amountFor(PaymentConcept concept, Segment segment) {
    final key = '${concept.id}_${segment.id}';
    for (final t in Tariff.values) {
      if (t.key == key) return of(t);
    }
    return of(Tariff.capacitacion);
  }

  Tariffs copyWith(Tariff tariff, int amount) =>
      Tariffs({..._amounts, tariff: amount});

  Map<String, int> toMap() => {for (final t in Tariff.values) t.key: of(t)};

  /// "Plan Premium B2C: Gs. 200.000 → Gs. 250.000" por cada cambio.
  List<String> changesFrom(Tariffs before) => [
    for (final t in Tariff.values)
      if (before.of(t) != of(t))
        '${t.label}: ${formatGs(before.of(t))} → ${formatGs(of(t))}',
  ];
}

enum PlanStatus {
  premium('Premium'),
  vencido('Premium vencido'),
  sinPlan('Sin plan');

  const PlanStatus(this.label);

  final String label;
}

/// Plan Premium de un paciente (`planes/{idPaciente}`). Un paciente sin
/// documento todavía no tiene plan.
@immutable
class PremiumPlan {
  const PremiumPlan({
    required this.idPaciente,
    this.nombrePaciente = '',
    this.segmento = Segment.b2c,
    this.activo = false,
    this.proximoPago,
    this.cancelado = false,
    this.ultimoCambio = '',
    this.autorUltimoCambio = '',
    this.fechaUltimoCambio,
  });

  factory PremiumPlan.fromMap(String id, Map<String, dynamic> data) =>
      PremiumPlan(
        idPaciente: id,
        nombrePaciente: _text(data['nombrePaciente']),
        segmento: Segment.fromId(data['segmento']),
        activo: data['estado'] == 'premium',
        proximoPago: _time(data['proximoPago']),
        cancelado: data['cancelado'] == true,
        ultimoCambio: _text(data['ultimoCambio']),
        autorUltimoCambio: _text(data['autorUltimoCambio']),
        fechaUltimoCambio: _time(data['fechaUltimoCambio']),
      );

  final String idPaciente;
  final String nombrePaciente;
  final Segment segmento;

  /// Tiene el Premium contratado (aunque puede estar vencido).
  final bool activo;

  /// Hasta qué día está pago. Ese día todavía cuenta como Premium.
  final DateTime? proximoPago;

  /// Pidió no renovar: al vencer pasa a "Sin plan" en vez de "Vencido".
  final bool cancelado;
  final String ultimoCambio;
  final String autorUltimoCambio;
  final DateTime? fechaUltimoCambio;

  /// El mismo plan con el nombre actual del paciente.
  PremiumPlan withName(String name) => PremiumPlan(
    idPaciente: idPaciente,
    nombrePaciente: name,
    segmento: segmento,
    activo: activo,
    proximoPago: proximoPago,
    cancelado: cancelado,
    ultimoCambio: ultimoCambio,
    autorUltimoCambio: autorUltimoCambio,
    fechaUltimoCambio: fechaUltimoCambio,
  );

  PlanStatus statusOn(DateTime now) {
    final due = proximoPago;
    if (!activo || due == null) return PlanStatus.sinPlan;
    if (!_day(now).isAfter(_day(due))) return PlanStatus.premium;
    return cancelado ? PlanStatus.sinPlan : PlanStatus.vencido;
  }

  PlanStatus get status => statusOn(DateTime.now());

  bool get isPremium => status == PlanStatus.premium;

  /// Hasta cuándo queda pago si hoy se paga un mes más: se suma a lo que
  /// ya estaba pago o, si venció, se cuenta desde hoy.
  DateTime nextDueAfterPayment({DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final due = proximoPago;
    final base = activo && due != null && !today.isAfter(_day(due))
        ? due
        : today;
    return addMonth(base);
  }
}

/// Lo que se va a cobrar y a qué paciente.
@immutable
class Charge {
  const Charge({
    required this.patientUid,
    required this.patientName,
    required this.concept,
    required this.amount,
    this.segment = Segment.b2c,
  });

  final String patientUid;
  final String patientName;
  final PaymentConcept concept;
  final int amount;
  final Segment segment;
}

/// Un pago (comprobante) de `pacientes/{uid}/pagos`.
@immutable
class Payment {
  const Payment({
    required this.id,
    required this.idPaciente,
    this.nombrePaciente = '',
    required this.concepto,
    required this.monto,
    required this.metodo,
    required this.estado,
    this.segmento = Segment.b2c,
    this.numero = '',
    this.referencia = '',
    this.idPagador = '',
    this.nombrePagador = '',
    this.periodoHasta,
    this.fecha,
    this.nombreConfirmador = '',
    this.fechaConfirmacion,
    this.motivoRechazo = '',
    this.registradoPorAdmin = false,
  });

  factory Payment.fromMap(String id, Map<String, dynamic> data) => Payment(
    id: id,
    idPaciente: _text(data['idPaciente']),
    nombrePaciente: _text(data['nombrePaciente']),
    concepto: PaymentConcept.fromId(data['concepto']),
    monto: data['monto'] is int ? data['monto'] as int : 0,
    metodo: PaymentMethod.fromId(data['metodo']),
    estado: PaymentStatus.fromId(data['estado']),
    segmento: Segment.fromId(data['segmento']),
    numero: _text(data['numero']),
    referencia: _text(data['referencia']),
    idPagador: _text(data['idPagador']),
    nombrePagador: _text(data['nombrePagador']),
    periodoHasta: _time(data['periodoHasta']),
    fecha: _time(data['fecha']),
    nombreConfirmador: _text(data['nombreConfirmador']),
    fechaConfirmacion: _time(data['fechaConfirmacion']),
    motivoRechazo: _text(data['motivoRechazo']),
    registradoPorAdmin: data['registradoPorAdmin'] == true,
  );

  final String id;
  final String idPaciente;
  final String nombrePaciente;
  final PaymentConcept concepto;
  final int monto;
  final PaymentMethod metodo;
  final PaymentStatus estado;
  final Segment segmento;

  /// Número del comprobante: "HM-20261113-4F2A9".
  final String numero;

  /// Transacción de la pasarela o número de operación de la transferencia.
  final String referencia;
  final String idPagador;
  final String nombrePagador;

  /// Solo Plan Premium aprobado: hasta qué día quedó pago.
  final DateTime? periodoHasta;
  final DateTime? fecha;
  final String nombreConfirmador;
  final DateTime? fechaConfirmacion;
  final String motivoRechazo;
  final bool registradoPorAdmin;

  bool get pendiente => estado == PaymentStatus.pendiente;
  bool get aprobado => estado == PaymentStatus.aprobado;

  /// "Plan Premium · hasta 13 dic 2026".
  String get title {
    final until = periodoHasta;
    return until == null
        ? concepto.label
        : '${concepto.label} · hasta ${formatLongDate(until)}';
  }

  static int newestFirst(Payment a, Payment b) {
    final x = a.fecha, y = b.fecha;
    if (x == null || y == null) return x == y ? 0 : (x == null ? -1 : 1);
    return y.compareTo(x);
  }
}

/// Número de comprobante a partir del id del documento.
String receiptNumber(String id, DateTime date) =>
    'HM-${toIsoDate(date).replaceAll('-', '')}-'
    '${id.substring(0, min(5, id.length)).toUpperCase()}';

/// Lo que incluye el Plan Premium. Para cambiar qué es Premium alcanza con
/// cambiar esta lista y [PremiumPlan.isPremium] donde se use.
const premiumFeatures = [
  (
    'Recuperar configuraciones anteriores',
    'Volver a cargar en el HeadMouse una configuración guardada antes.',
  ),
  (
    'Soporte técnico prioritario',
    'Sin pagar cada solicitud de soporte por separado.',
  ),
];

abstract class BillingService {
  static BillingService instance = FirestoreBillingService();

  Stream<Tariffs> watchTariffs();

  /// Solo el administrador. Queda en Auditoría con los montos anteriores.
  Future<void> saveTariffs(Tariffs before, Tariffs after);

  Stream<PremiumPlan> watchPlan(String patientUid, {String patientName = ''});

  /// Solo el administrador: los planes de todos los pacientes que tienen.
  Stream<List<PremiumPlan>> watchPlans();

  /// Pagos del paciente, el más nuevo primero.
  Stream<List<Payment>> watchPayments(String patientUid);

  /// Solo el administrador: los pagos de todos, el más nuevo primero.
  Stream<List<Payment>> watchAllPayments();

  /// Pasarela simulada: el pago con QR se aprueba o se rechaza al instante.
  /// Si se aprueba un Plan Premium, el plan se extiende un mes.
  Future<Payment> payWithQr(
    Charge charge,
    PremiumPlan plan, {
    required bool approved,
  });

  /// Transferencia o efectivo: queda pendiente hasta que el administrador
  /// lo confirme.
  Future<Payment> submitPayment(
    Charge charge, {
    required PaymentMethod method,
    String referencia = '',
  });

  /// Paciente o cuidador: no renovar el plan (o volver a renovarlo).
  Future<void> setRenewal(PremiumPlan plan, {required bool cancelado});

  /// Administrador: registra un pago recibido (ya aprobado).
  Future<Payment> registerPayment(
    Charge charge,
    PremiumPlan plan, {
    required PaymentMethod method,
    String referencia = '',
  });

  /// Administrador: aprueba un pago pendiente.
  Future<void> confirmPayment(Payment payment, PremiumPlan plan);

  /// Administrador: rechaza un pago pendiente (el dinero no se recibió).
  Future<void> rejectPayment(Payment payment, String motivo);

  /// Administrador: da de baja el Plan Premium.
  Future<void> endPlan(PremiumPlan plan);

  /// Administrador: cambia el paciente a particular o institución.
  Future<void> setSegment(PremiumPlan plan, Segment segment);
}

class FirestoreBillingService extends BillingService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  AppUser? get _me => AuthService.instance.current;
  String get _actorName => _me?.fullName ?? 'Usuario';

  DocumentReference<Map<String, dynamic>> get _tariffs =>
      _db.doc('tarifas/actual');
  CollectionReference<Map<String, dynamic>> get _plans =>
      _db.collection('planes');
  CollectionReference<Map<String, dynamic>> _payments(String uid) =>
      _db.collection('pacientes/$uid/pagos');

  final _random = Random.secure();

  Stream<T> _guard<T>(Stream<T> Function() build) {
    try {
      return build();
    } catch (e) {
      return Stream.error(e);
    }
  }

  Future<T> _wrap<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw AuthException(AuthService.describeError(e));
    }
  }

  @override
  Stream<Tariffs> watchTariffs() => _guard(
    () => _tariffs.snapshots().map((snap) => Tariffs.fromMap(snap.data())),
  );

  @override
  Future<void> saveTariffs(Tariffs before, Tariffs after) => _wrap(() async {
    final changes = after.changesFrom(before);
    if (changes.isEmpty) return;
    final batch = _db.batch()
      ..set(_tariffs, {
        ...after.toMap(),
        'modificadoPor': _uid,
        'fechaModificacion': FieldValue.serverTimestamp(),
      })
      ..set(
        _db.collection('auditoria').doc(),
        auditRecord(
          accion: 'Cambió las tarifas',
          detalle: changes.join(' · '),
          entidad: 'tarifas',
          idEntidad: 'actual',
          categoria: 'Planes y pagos',
        ),
      );
    await batch.commit();
  });

  @override
  Stream<PremiumPlan> watchPlan(String patientUid, {String patientName = ''}) =>
      _guard(
        () => _plans.doc(patientUid).snapshots().map((snap) {
          final data = snap.data();
          return data == null
              ? PremiumPlan(idPaciente: patientUid, nombrePaciente: patientName)
              : PremiumPlan.fromMap(snap.id, data);
        }),
      );

  @override
  Stream<List<PremiumPlan>> watchPlans() => _guard(
    () => _plans.snapshots().map(
      (snap) => [
        for (final doc in snap.docs) PremiumPlan.fromMap(doc.id, doc.data()),
      ],
    ),
  );

  List<Payment> _sorted(QuerySnapshot<Map<String, dynamic>> snap) =>
      [for (final doc in snap.docs) Payment.fromMap(doc.id, doc.data())]
        ..sort(Payment.newestFirst);

  @override
  Stream<List<Payment>> watchPayments(String patientUid) =>
      _guard(() => _payments(patientUid).snapshots().map(_sorted));

  @override
  Stream<List<Payment>> watchAllPayments() =>
      _guard(() => _db.collectionGroup('pagos').snapshots().map(_sorted));

  Map<String, Object?> _paymentData(
    String id,
    Charge charge, {
    required PaymentMethod method,
    required PaymentStatus status,
    required String referencia,
    DateTime? periodoHasta,
    bool byAdmin = false,
  }) {
    final me = _me;
    return {
      'idPaciente': charge.patientUid,
      'nombrePaciente': charge.patientName,
      'segmento': charge.segment.id,
      'concepto': charge.concept.id,
      'descripcion': charge.concept.label,
      'monto': charge.amount,
      'metodo': method.id,
      'estado': status.id,
      'numero': receiptNumber(id, DateTime.now()),
      'referencia': referencia.trim(),
      // Si lo carga el administrador, el que pagó es el paciente.
      'idPagador': byAdmin ? charge.patientUid : _uid,
      'nombrePagador': byAdmin ? charge.patientName : _actorName,
      'rolPagador': byAdmin ? 'paciente' : me?.role.id,
      'registradoPor': _uid,
      'registradoPorAdmin': byAdmin,
      'periodoHasta': periodoHasta == null
          ? null
          : Timestamp.fromDate(periodoHasta),
      'fecha': FieldValue.serverTimestamp(),
      if (byAdmin && status == PaymentStatus.aprobado) ...{
        'confirmadoPor': _uid,
        'nombreConfirmador': _actorName,
        'fechaConfirmacion': FieldValue.serverTimestamp(),
      },
    };
  }

  /// Plan después de aprobarse un pago de Premium.
  Map<String, Object?> _paidPlan(
    PremiumPlan plan,
    Charge charge,
    String paymentId,
    DateTime until,
    String change,
  ) => {
    'idPaciente': charge.patientUid,
    'nombrePaciente': charge.patientName,
    'segmento': plan.segmento.id,
    'estado': 'premium',
    'proximoPago': Timestamp.fromDate(until),
    'cancelado': false,
    'ultimoPago': paymentId,
    'ultimoCambio': change,
    'autorUltimoCambio': _actorName,
    'fechaUltimoCambio': FieldValue.serverTimestamp(),
  };

  Map<String, Object?> _audit(String accion, Payment p, {String extra = ''}) =>
      auditRecord(
        accion: accion,
        detalle: [
          formatGs(p.monto),
          p.metodo.label,
          p.numero,
          if (extra.isNotEmpty) extra,
        ].join(' · '),
        entidad: 'pagos',
        idEntidad: p.id,
        categoria: 'Planes y pagos',
      );

  Future<Payment> _create(
    Charge charge,
    PremiumPlan plan, {
    required PaymentMethod method,
    required PaymentStatus status,
    required String referencia,
    required String accion,
    bool byAdmin = false,
  }) => _wrap(() async {
    final ref = _payments(charge.patientUid).doc();
    final extends_ =
        status == PaymentStatus.aprobado &&
        charge.concept == PaymentConcept.premium;
    final until = extends_ ? plan.nextDueAfterPayment() : null;
    final data = _paymentData(
      ref.id,
      charge,
      method: method,
      status: status,
      referencia: referencia,
      periodoHasta: until,
      byAdmin: byAdmin,
    );
    final payment = Payment(
      id: ref.id,
      idPaciente: charge.patientUid,
      nombrePaciente: charge.patientName,
      concepto: charge.concept,
      monto: charge.amount,
      metodo: method,
      estado: status,
      segmento: charge.segment,
      numero: data['numero']! as String,
      referencia: referencia.trim(),
      idPagador: data['idPagador'] as String? ?? '',
      nombrePagador: data['nombrePagador'] as String? ?? '',
      periodoHasta: until,
      fecha: DateTime.now(),
      registradoPorAdmin: byAdmin,
    );
    final batch = _db.batch()..set(ref, data);
    if (until != null) {
      batch.set(
        _plans.doc(charge.patientUid),
        _paidPlan(
          plan,
          charge,
          ref.id,
          until,
          'Pago registrado (${method.label})',
        ),
      );
    }
    batch.set(
      _db.collection('auditoria').doc(),
      _audit(
        accion,
        payment,
        extra: until == null ? '' : 'Premium hasta ${formatLongDate(until)}',
      ),
    );
    await batch.commit();
    return payment;
  });

  String _gatewayReference() =>
      'PGP-${List.generate(8, (_) => _random.nextInt(10)).join()}';

  @override
  Future<Payment> payWithQr(
    Charge charge,
    PremiumPlan plan, {
    required bool approved,
  }) => _create(
    charge,
    plan,
    method: PaymentMethod.qr,
    status: approved ? PaymentStatus.aprobado : PaymentStatus.rechazado,
    referencia: _gatewayReference(),
    accion: approved
        ? 'Pagó ${charge.concept.label} de ${charge.patientName}'
        : 'Pago rechazado: ${charge.concept.label} de ${charge.patientName}',
  );

  @override
  Future<Payment> submitPayment(
    Charge charge, {
    required PaymentMethod method,
    String referencia = '',
  }) => _create(
    charge,
    PremiumPlan(idPaciente: charge.patientUid),
    method: method,
    status: PaymentStatus.pendiente,
    referencia: referencia,
    accion:
        'Informó un pago de ${charge.concept.label} de ${charge.patientName}',
  );

  @override
  Future<Payment> registerPayment(
    Charge charge,
    PremiumPlan plan, {
    required PaymentMethod method,
    String referencia = '',
  }) => _create(
    charge,
    plan,
    method: method,
    status: PaymentStatus.aprobado,
    referencia: referencia,
    accion:
        'Registró un pago de ${charge.concept.label} de ${charge.patientName}',
    byAdmin: true,
  );

  @override
  Future<void> setRenewal(PremiumPlan plan, {required bool cancelado}) =>
      _wrap(() async {
        final batch = _db.batch()
          ..update(_plans.doc(plan.idPaciente), {
            'cancelado': cancelado,
            'ultimoCambio': cancelado
                ? 'Renovación cancelada'
                : 'Renovación reanudada',
            'autorUltimoCambio': _actorName,
            'fechaUltimoCambio': FieldValue.serverTimestamp(),
          })
          ..set(
            _db.collection('auditoria').doc(),
            auditRecord(
              accion: cancelado
                  ? 'Canceló la renovación del Plan Premium de '
                        '${plan.nombrePaciente}'
                  : 'Reanudó la renovación del Plan Premium de '
                        '${plan.nombrePaciente}',
              detalle: plan.proximoPago == null
                  ? ''
                  : 'Pago hasta ${formatLongDate(plan.proximoPago!)}',
              entidad: 'planes',
              idEntidad: plan.idPaciente,
              categoria: 'Planes y pagos',
            ),
          );
        await batch.commit();
      });

  @override
  Future<void> confirmPayment(Payment payment, PremiumPlan plan) => _wrap(
    () async {
      final until = payment.concepto == PaymentConcept.premium
          ? plan.nextDueAfterPayment()
          : null;
      final batch = _db.batch()
        ..update(_payments(payment.idPaciente).doc(payment.id), {
          'estado': PaymentStatus.aprobado.id,
          'confirmadoPor': _uid,
          'nombreConfirmador': _actorName,
          'fechaConfirmacion': FieldValue.serverTimestamp(),
          'periodoHasta': until == null ? null : Timestamp.fromDate(until),
        });
      if (until != null) {
        batch.set(
          _plans.doc(payment.idPaciente),
          _paidPlan(
            plan,
            Charge(
              patientUid: payment.idPaciente,
              patientName: payment.nombrePaciente,
              concept: payment.concepto,
              amount: payment.monto,
            ),
            payment.id,
            until,
            'Pago confirmado (${payment.metodo.label})',
          ),
        );
      }
      batch.set(
        _db.collection('auditoria').doc(),
        _audit(
          'Confirmó el pago de ${payment.concepto.label} de '
          '${payment.nombrePaciente}',
          payment,
          extra: until == null ? '' : 'Premium hasta ${formatLongDate(until)}',
        ),
      );
      await batch.commit();
    },
  );

  @override
  Future<void> rejectPayment(Payment payment, String motivo) => _wrap(() async {
    final batch = _db.batch()
      ..update(_payments(payment.idPaciente).doc(payment.id), {
        'estado': PaymentStatus.rechazado.id,
        'confirmadoPor': _uid,
        'nombreConfirmador': _actorName,
        'fechaConfirmacion': FieldValue.serverTimestamp(),
        'motivoRechazo': motivo.trim(),
      })
      ..set(
        _db.collection('auditoria').doc(),
        _audit(
          'Rechazó el pago de ${payment.concepto.label} de '
          '${payment.nombrePaciente}',
          payment,
          extra: motivo.trim(),
        ),
      );
    await batch.commit();
  });

  Future<void> _changePlan(
    PremiumPlan plan,
    Map<String, Object?> changes, {
    required String change,
    required String accion,
  }) => _wrap(() async {
    final batch = _db.batch()
      ..set(_plans.doc(plan.idPaciente), {
        'idPaciente': plan.idPaciente,
        'nombrePaciente': plan.nombrePaciente,
        'segmento': plan.segmento.id,
        'estado': plan.activo ? 'premium' : 'sin_plan',
        ...changes,
        'ultimoCambio': change,
        'autorUltimoCambio': _actorName,
        'fechaUltimoCambio': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true))
      ..set(
        _db.collection('auditoria').doc(),
        auditRecord(
          accion: accion,
          detalle: plan.nombrePaciente,
          entidad: 'planes',
          idEntidad: plan.idPaciente,
          categoria: 'Planes y pagos',
        ),
      );
    await batch.commit();
  });

  @override
  Future<void> endPlan(PremiumPlan plan) => _changePlan(
    plan,
    {'estado': 'sin_plan', 'proximoPago': null, 'cancelado': false},
    change: 'Plan Premium dado de baja',
    accion: 'Dio de baja el Plan Premium de ${plan.nombrePaciente}',
  );

  @override
  Future<void> setSegment(PremiumPlan plan, Segment segment) => _changePlan(
    plan,
    {'segmento': segment.id},
    change: 'Pasó a ${segment.id}',
    accion: 'Pasó a ${plan.nombrePaciente} a ${segment.label}',
  );
}
