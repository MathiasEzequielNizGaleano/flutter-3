// Sesiones abiertas e historial de accesos de cada cuenta.
//
// - Cerrar las demás sesiones: Firebase solo revoca sesiones desde un
//   servidor (Cloud Functions, plan Blaze). En el plan gratuito cada
//   teléfono con la app abierta escucha su documento `usuarios/{uid}`: si
//   otra sesión escribe `cierreSesiones`, o el administrador da de baja la
//   cuenta, la app cierra la sesión sola (ver navigation/session_guard.dart).
// - Historial: los registros de `accesos` de una cuenta. Los ve la persona,
//   su cuidador (si puede ver sus datos) y el administrador.
// - Intentos fallidos: una contraseña incorrecta no tiene sesión, así que se
//   guarda solo el correo que se escribió (lo ve el administrador).

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'admin_service.dart';
import 'auth_service.dart';

/// Por qué se cerró la sesión de este teléfono sin que la persona lo pidiera.
enum SessionEnd {
  /// La persona cerró sus sesiones desde otro dispositivo.
  closedElsewhere(
    'logout_remoto',
    'Se cerró tu sesión desde otro dispositivo. Volvé a ingresar si fuiste '
        'vos.',
  ),

  /// El administrador dio de baja la cuenta.
  deactivated(
    'logout_baja',
    'Tu cuenta fue dada de baja. Contactá al administrador.',
  );

  const SessionEnd(this.eventType, this.message);

  /// `tipoEvento` del registro en `accesos`.
  final String eventType;

  /// Lo que se le muestra a la persona en el login.
  final String message;
}

String get platformId => kIsWeb ? 'web' : defaultTargetPlatform.name;

/// Punto de acceso de las pantallas. En los tests se reemplaza [instance].
abstract class SessionService {
  static SessionService instance = FirestoreSessionService();

  /// Identifica la sesión de este teléfono (cambia en cada ingreso).
  String sessionId = '';

  /// Empieza una sesión nueva en este teléfono.
  void begin() {
    final random = Random.secure();
    sessionId = List.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  /// Avisa cuando esta sesión tiene que cerrarse (baja de la cuenta o
  /// cierre desde otro dispositivo).
  Stream<SessionEnd> watchEnd(AppUser user);

  /// Cierra la sesión en los demás teléfonos; este sigue abierto.
  Future<void> closeOthers(AppUser user);

  /// Últimos accesos de la cuenta [uid], del más nuevo al más viejo.
  Stream<List<AuditEvent>> watchAccesses(String uid, {int limit = 50});

  /// Guarda un intento de ingreso con contraseña incorrecta.
  Future<void> logFailedLogin(String email);
}

class FirestoreSessionService extends SessionService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  Stream<SessionEnd> watchEnd(AppUser user) {
    // Valor de `cierreSesiones` al ingresar: lo que pasó antes no cuenta.
    String? baseline;
    var hasBaseline = false;
    final mySession = sessionId;
    try {
      return _db
          .doc('usuarios/${user.uid}')
          .snapshots()
          .handleError((Object _) {})
          .expand((snap) {
            final data = snap.data();
            if (data == null) return const <SessionEnd>[];
            if (data['estado'] == false) return const [SessionEnd.deactivated];
            final closing = data['cierreSesiones'];
            final closedBy = closing is Map ? closing['id'] as String? : null;
            if (!hasBaseline) {
              // Solo un dato confirmado por el servidor sirve de punto de
              // partida (el de la caché puede ser viejo).
              if (snap.metadata.isFromCache) return const <SessionEnd>[];
              hasBaseline = true;
              baseline = closedBy;
              return const <SessionEnd>[];
            }
            if (closedBy != null &&
                closedBy != baseline &&
                closedBy != mySession) {
              return const [SessionEnd.closedElsewhere];
            }
            return const <SessionEnd>[];
          });
    } catch (e) {
      return const Stream.empty();
    }
  }

  @override
  Future<void> closeOthers(AppUser user) async {
    try {
      await _db.doc('usuarios/${user.uid}').update({
        'cierreSesiones': {
          'id': sessionId,
          'fecha': FieldValue.serverTimestamp(),
          'plataforma': platformId,
        },
      });
    } catch (e) {
      throw AuthException(AuthService.describeError(e));
    }
    await AuthService.instance.logAccess(user, 'cierre_sesiones');
  }

  @override
  Stream<List<AuditEvent>> watchAccesses(String uid, {int limit = 50}) {
    try {
      return _db
          .collection('accesos')
          .where('idUsuario', isEqualTo: uid)
          .orderBy('fechaHora', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snap) => [
              for (final doc in snap.docs) AuditEvent.fromAccess(doc.data()),
            ],
          );
    } catch (e) {
      return Stream.error(e);
    }
  }

  @override
  Future<void> logFailedLogin(String email) async {
    try {
      await _db.collection('accesos').add({
        'correo': email.trim().toLowerCase(),
        'tipoEvento': 'login',
        'resultado': 'fallido',
        'fechaHora': FieldValue.serverTimestamp(),
        'plataforma': platformId,
      });
    } catch (_) {
      // Si no se puede guardar, el ingreso igual se rechazó.
    }
  }
}
