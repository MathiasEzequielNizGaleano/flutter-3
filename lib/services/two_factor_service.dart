// Verificación en dos pasos (SIMULADA).
//
// Firebase envía códigos por SMS (y permite mandar correos propios con Cloud
// Functions) solo en el plan Blaze, que es pago. Como el proyecto usa el plan
// gratuito, el envío se simula: la app genera un código de 6 dígitos, lo
// muestra como si hubiera llegado por SMS o por correo y lo verifica. Vence
// a los 5 minutos y se bloquea después de 5 intentos. Cada intento, bien o
// mal, queda en `accesos` (historial de accesos del administrador).
//
// Cada usuario elige el canal en su perfil (`usuarios/{uid}.verificacion`).

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'audit.dart';
import 'auth_service.dart';
import 'records_service.dart' show Choice;

enum TwoFactorChannel implements Choice {
  correo('correo', 'Correo electrónico'),
  sms('sms', 'SMS al celular');

  const TwoFactorChannel(this.id, this.label);

  @override
  final String id;
  @override
  final String label;

  static TwoFactorChannel fromId(Object? id) => id == sms.id ? sms : correo;
}

/// Cómo recibe el código cada usuario. Sin datos, por correo.
@immutable
class TwoFactorSettings {
  const TwoFactorSettings({
    this.channel = TwoFactorChannel.correo,
    this.telefono = '',
  });

  factory TwoFactorSettings.fromMap(Object? data) => data is Map
      ? TwoFactorSettings(
          channel: TwoFactorChannel.fromId(data['metodo']),
          telefono: data['telefono'] is String
              ? data['telefono'] as String
              : '',
        )
      : const TwoFactorSettings();

  final TwoFactorChannel channel;
  final String telefono;

  bool get hasPhone => telefono.trim().isNotEmpty;

  /// SMS sin teléfono cargado no se puede: va por correo.
  TwoFactorChannel get effectiveChannel =>
      channel == TwoFactorChannel.sms && hasPhone
      ? TwoFactorChannel.sms
      : TwoFactorChannel.correo;

  Map<String, Object?> toMap() => {
    'metodo': channel.id,
    'telefono': telefono.trim(),
  };

  @override
  bool operator ==(Object other) =>
      other is TwoFactorSettings &&
      other.channel == channel &&
      other.telefono.trim() == telefono.trim();

  @override
  int get hashCode => Object.hash(channel, telefono.trim());
}

/// "maria@correo.com" → "ma•••@correo.com".
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  final visible = email.substring(0, min(2, at));
  return '$visible•••${email.substring(at)}';
}

/// "0981 234 567" → "••• ••• 567".
String maskPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 3) return phone;
  return '••• ••• ${digits.substring(digits.length - 3)}';
}

enum VerifyResult { ok, wrong, expired, locked }

/// Un código enviado (simulado) y sus intentos.
class TwoFactorChallenge {
  TwoFactorChallenge({
    required this.code,
    required this.channel,
    required this.destination,
    required this.sentAt,
    this.lifetime = const Duration(minutes: 5),
    this.maxAttempts = 5,
  });

  final String code;
  final TwoFactorChannel channel;

  /// Teléfono o correo enmascarado: "••• ••• 567".
  final String destination;
  final DateTime sentAt;
  final Duration lifetime;
  final int maxAttempts;
  int _attempts = 0;
  bool _used = false;

  DateTime get expiresAt => sentAt.add(lifetime);
  int get remainingAttempts => max(0, maxAttempts - _attempts);

  /// Texto del SMS o del correo simulado.
  String get message =>
      'Tu código de HeadMouse Pro es $code. Vence en '
      '${lifetime.inMinutes} minutos. No lo compartas con nadie.';

  VerifyResult verify(String input, {DateTime? now}) {
    if (_used || remainingAttempts == 0) return VerifyResult.locked;
    if ((now ?? DateTime.now()).isAfter(expiresAt)) return VerifyResult.expired;
    _attempts++;
    if (input.trim() == code) {
      _used = true;
      return VerifyResult.ok;
    }
    return remainingAttempts == 0 ? VerifyResult.locked : VerifyResult.wrong;
  }
}

abstract class TwoFactorService {
  static TwoFactorService instance = FirestoreTwoFactorService();

  /// Espera mínima para pedir otro código.
  static const resendDelay = Duration(seconds: 30);

  final _random = Random.secure();

  String newCode() => List.generate(6, (_) => _random.nextInt(10)).join();

  /// "Envía" un código nuevo por el canal de [settings].
  TwoFactorChallenge start(
    TwoFactorSettings settings, {
    required String email,
    TwoFactorChannel? channel,
  }) {
    // SMS solo si hay un teléfono cargado.
    final via = switch (channel ?? settings.effectiveChannel) {
      TwoFactorChannel.sms when settings.hasPhone => TwoFactorChannel.sms,
      _ => TwoFactorChannel.correo,
    };
    return TwoFactorChallenge(
      code: newCode(),
      channel: via,
      destination: via == TwoFactorChannel.sms
          ? maskPhone(settings.telefono)
          : maskEmail(email),
      sentAt: DateTime.now(),
    );
  }

  /// Guarda el resultado de un intento en el historial de accesos.
  Future<void> recordAttempt(
    AppUser user, {
    required bool ok,
    required TwoFactorChannel channel,
  });

  /// Cambia el canal del usuario de la sesión.
  Future<void> saveSettings(AppUser user, TwoFactorSettings settings);
}

class FirestoreTwoFactorService extends TwoFactorService {
  @override
  Future<void> recordAttempt(
    AppUser user, {
    required bool ok,
    required TwoFactorChannel channel,
  }) => AuthService.instance.logAccess(
    user,
    'verificacion',
    ok: ok,
    canal: channel.id,
  );

  @override
  Future<void> saveSettings(AppUser user, TwoFactorSettings settings) async {
    final db = FirebaseFirestore.instance;
    try {
      final batch = db.batch()
        ..update(db.doc('usuarios/${user.uid}'), {
          'verificacion': settings.toMap(),
        })
        ..set(
          db.collection('auditoria').doc(),
          auditRecord(
            accion: 'Cambió su verificación en dos pasos',
            detalle: settings.effectiveChannel == TwoFactorChannel.sms
                ? 'SMS a ${maskPhone(settings.telefono)}'
                : 'Correo a ${maskEmail(user.email)}',
            entidad: 'usuarios',
            idEntidad: user.uid,
          ),
        );
      await batch.commit();
    } catch (e) {
      throw AuthException(AuthService.describeError(e));
    }
    AuthService.instance.current = user.copyWith(twoFactor: settings);
  }
}
