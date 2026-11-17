import 'dart:async';

import 'package:headmouse_pro/services/admin_service.dart';
import 'package:headmouse_pro/services/auth_service.dart';
import 'package:headmouse_pro/services/session_service.dart';

/// SessionService en memoria. Con [ends] se simula que la sesión se cierra
/// desde otro lado.
class FakeSessionService extends SessionService {
  final calls = <String>[];
  final ends = StreamController<SessionEnd>.broadcast();

  final accesses = <String, List<AuditEvent>>{
    'p1': [
      AuditEvent(
        category: 'Login',
        actor: 'Juan Paredes',
        time: DateTime(2026, 11, 15, 18, 2),
        action: 'Cerró sesión',
        metaLeft: 'Rol: Paciente',
        metaRight: 'Android',
      ),
      AuditEvent(
        category: 'Login',
        actor: 'Juan Paredes',
        time: DateTime(2026, 11, 15, 9, 31),
        action: 'Inició sesión',
        metaLeft: 'Rol: Paciente',
        metaRight: 'Android',
      ),
      AuditEvent(
        category: 'Login',
        actor: 'Juan Paredes',
        time: DateTime(2026, 11, 15, 9, 30),
        action: 'Código de verificación incorrecto (correo)',
        metaLeft: 'Rol: Paciente',
        metaRight: 'Android',
        failed: true,
      ),
    ],
  };

  // Los tests no tienen sesión: con uid vacío se usa el paciente p1.
  String _uid(String uid) => uid.isEmpty ? 'p1' : uid;

  @override
  Stream<SessionEnd> watchEnd(AppUser user) => ends.stream;

  @override
  Future<void> closeOthers(AppUser user) async {
    calls.add('cerrar otras ${user.uid}');
  }

  @override
  Stream<List<AuditEvent>> watchAccesses(String uid, {int limit = 50}) {
    calls.add('historial ${_uid(uid)}');
    return Stream.value(accesses[_uid(uid)] ?? const []);
  }

  @override
  Future<void> logFailedLogin(String email) async {
    calls.add('fallido $email');
  }
}
