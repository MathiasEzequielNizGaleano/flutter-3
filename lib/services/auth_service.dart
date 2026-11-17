// Inicio de sesión con Firebase Authentication + perfil en Firestore.
//
// El rol NO lo elige el usuario al entrar: se guarda en `usuarios/{uid}` al
// registrarse y solo un administrador puede cambiarlo (ver firestore.rules).
//
// Después de la contraseña se pide un código de verificación (simulado, ver
// two_factor_service.dart).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../ble/headmouse_ble.dart';
import 'session_service.dart';
import 'two_factor_service.dart';

enum UserRole {
  paciente('paciente', 'Paciente'),
  cuidador('cuidador', 'Cuidador / tutor'),
  admin('admin', 'Administrador');

  const UserRole(this.id, this.label);

  /// Valor guardado en Firestore.
  final String id;
  final String label;

  static UserRole? fromId(Object? id) {
    for (final role in values) {
      if (role.id == id) return role;
    }
    return null;
  }
}

/// Usuario con sesión iniciada (tabla USUARIO).
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.role,
    required this.nombres,
    required this.apellidos,
    this.hasCaregivers = false,
    this.twoFactor = const TwoFactorSettings(),
  });

  final String uid;
  final String email;
  final UserRole role;
  final String nombres;
  final String apellidos;

  /// Solo pacientes: si tiene algún cuidador asignado al iniciar sesión.
  /// Define qué barra de navegación ve (ver `patientNavItems`).
  final bool hasCaregivers;

  /// Cómo recibe el código de verificación en dos pasos.
  final TwoFactorSettings twoFactor;

  AppUser copyWith({TwoFactorSettings? twoFactor}) => AppUser(
    uid: uid,
    email: email,
    role: role,
    nombres: nombres,
    apellidos: apellidos,
    hasCaregivers: hasCaregivers,
    twoFactor: twoFactor ?? this.twoFactor,
  );

  String get fullName {
    final name = '$nombres $apellidos'.trim();
    return name.isEmpty ? email : name;
  }
}

/// Error con un mensaje listo para mostrar al usuario.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final instance = AuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  AppUser? current;

  /// Uid de la sesión actual, o `null` sin sesión o sin Firebase (tests).
  String? get currentUid {
    try {
      return _auth.currentUser?.uid ?? current?.uid;
    } catch (_) {
      return current?.uid;
    }
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final UserCredential cred;
    try {
      cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (_badCredentials.contains(e.code)) {
        // Sin sesión no hay a quién atribuirlo: queda el correo escrito.
        unawaited(SessionService.instance.logFailedLogin(email));
      }
      throw AuthException(_message(e.code));
    } catch (e) {
      throw AuthException(_unexpected(e));
    }

    final uid = cred.user!.uid;
    final DocumentSnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _db.doc('usuarios/$uid').get();
    } catch (e) {
      await _auth.signOut();
      throw AuthException(_unexpected(e));
    }
    final data = snap.data();
    final role = UserRole.fromId(data?['rol']);
    if (data == null || role == null) {
      await _auth.signOut();
      throw const AuthException(
        'Tu cuenta no tiene un perfil asignado. Contactá al administrador.',
      );
    }
    if (data['estado'] == false) {
      await _auth.signOut();
      throw const AuthException(
        'Tu cuenta está desactivada. Contactá al administrador.',
      );
    }

    final user = AppUser(
      uid: uid,
      email: cred.user!.email ?? email.trim(),
      role: role,
      nombres: (data['nombres'] as String?) ?? '',
      apellidos: (data['apellidos'] as String?) ?? '',
      hasCaregivers: role == UserRole.paciente && await _hasCaregivers(uid),
      twoFactor: TwoFactorSettings.fromMap(data['verificacion']),
    );
    current = user;
    // Registro de ingreso (HISTORIAL_ACCESO). Si falla no bloquea el acceso.
    try {
      await _db.doc('usuarios/$uid').update({
        'ultimoIngreso': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    await logAccess(user, 'login');
    return user;
  }

  /// Alta de paciente o cuidador. Los administradores no se registran
  /// desde la app: se asignan desde la consola de Firebase.
  Future<AppUser> register({
    required String nombres,
    required String apellidos,
    required String email,
    required String documento,
    required String password,
    required UserRole role,
  }) async {
    if (role == UserRole.admin) {
      throw const AuthException('No se puede registrar un administrador.');
    }
    final UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e.code));
    } catch (e) {
      throw AuthException(_unexpected(e));
    }

    final uid = cred.user!.uid;
    try {
      await _db.doc('usuarios/$uid').set({
        'email': cred.user!.email ?? email.trim(),
        'rol': role.id,
        'nombres': nombres.trim(),
        'apellidos': apellidos.trim(),
        'documento': documento,
        'estado': true,
        'fechaRegistro': FieldValue.serverTimestamp(),
        'ultimoIngreso': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Sin perfil la cuenta no sirve: la borramos para poder reintentar.
      try {
        await cred.user!.delete();
      } catch (_) {}
      throw AuthException(_unexpected(e));
    }

    final user = AppUser(
      uid: uid,
      email: cred.user!.email ?? email.trim(),
      role: role,
      nombres: nombres.trim(),
      apellidos: apellidos.trim(),
    );
    current = user;
    await logAccess(user, 'registro');
    return user;
  }

  /// Con [log] en `false` no se registra el cierre (lo registra quien lo
  /// provocó, por ejemplo una baja o un cierre desde otro dispositivo).
  Future<void> signOut({bool log = true}) async {
    // Libera el HeadMouse para que no quede controlado por otra sesión.
    await HeadMouseBle.instance.disconnect();
    final user = current;
    current = null;
    try {
      if (user != null && log) await logAccess(user, 'logout');
      await _auth.signOut();
    } catch (_) {
      // Sin Firebase (por ejemplo en tests) no hay sesión que cerrar.
    }
  }

  /// Envía el correo de Firebase con el enlace para elegir una contraseña
  /// nueva. Así no hace falta pedir la actual dentro de la app.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e.code));
    } catch (e) {
      throw AuthException(_unexpected(e));
    }
  }

  Future<bool> _hasCaregivers(String uid) async {
    try {
      final links = await _db
          .collection('asignaciones')
          .where('idPaciente', isEqualTo: uid)
          .get();
      return links.docs.any((doc) => doc.data()['activo'] == true);
    } catch (_) {
      return false;
    }
  }

  /// Registro en `accesos` (HISTORIAL_ACCESO). Si falla no bloquea nada.
  Future<void> logAccess(
    AppUser user,
    String tipoEvento, {
    bool ok = true,
    String? canal,
  }) async {
    try {
      await _db.collection('accesos').add({
        'idUsuario': user.uid,
        // Nombre y rol al momento del evento, para leer el historial sin
        // tener que cruzarlo con la colección de usuarios.
        'nombreUsuario': user.fullName,
        'rol': user.role.id,
        'tipoEvento': tipoEvento,
        'resultado': ok ? 'exitoso' : 'fallido',
        'canal': ?canal,
        'fechaHora': FieldValue.serverTimestamp(),
        'plataforma': kIsWeb ? 'web' : defaultTargetPlatform.name,
      });
    } catch (_) {}
  }

  /// Convierte cualquier error de Firebase en un mensaje para el usuario.
  static String describeError(Object e) =>
      e is FirebaseAuthException ? _message(e.code) : _unexpected(e);

  /// Códigos de Firebase para correo o contraseña incorrectos.
  static const _badCredentials = {
    'invalid-credential',
    'wrong-password',
    'user-not-found',
    'invalid-login-credentials',
  };

  static String _message(String code) => switch (code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'invalid-login-credentials' => 'Correo o contraseña incorrectos.',
    'invalid-email' => 'El correo no es válido.',
    'user-disabled' => 'Tu cuenta está bloqueada. Contactá al administrador.',
    'too-many-requests' =>
      'Demasiados intentos. Esperá unos minutos y volvé a probar.',
    'email-already-in-use' => 'Ya existe una cuenta con ese correo.',
    'weak-password' => 'La contraseña es demasiado débil.',
    'network-request-failed' => 'Sin conexión a internet.',
    'operation-not-allowed' =>
      'El acceso con correo y contraseña no está habilitado en Firebase.',
    _ => 'No se pudo completar la operación ($code).',
  };

  static String _unexpected(Object e) {
    if (e is AuthException) return e.message;
    if (e is FirebaseException && e.code == 'permission-denied') {
      return 'Firebase rechazó la operación: tu cuenta no tiene permiso.';
    }
    if (e is FirebaseException && e.code == 'unavailable') {
      return 'Sin conexión con el servidor. Revisá tu internet.';
    }
    return 'Error inesperado: $e';
  }
}
