// Funciones del administrador: altas, bajas, roles y auditoría.
//
// Todo lo que cambia el administrador se escribe junto con un registro en
// `auditoria` en la misma operación (batch), así no puede quedar un cambio
// sin su registro. Las reglas de seguridad (firestore.rules) son las que
// garantizan que solo un administrador activo pueda hacerlo.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'accounts.dart';
import 'audit.dart';
import 'auth_service.dart';

/// Cuenta de la colección `usuarios`, vista por el administrador.
@immutable
class ManagedUser {
  const ManagedUser({
    required this.uid,
    required this.email,
    required this.role,
    this.nombres = '',
    this.apellidos = '',
    this.documento = '',
    this.active = true,
    this.fechaRegistro,
    this.ultimoIngreso,
  });

  factory ManagedUser.fromMap(String uid, Map<String, dynamic> data) {
    return ManagedUser(
      uid: uid,
      email: (data['email'] as String?) ?? '',
      role: UserRole.fromId(data['rol']),
      nombres: (data['nombres'] as String?) ?? '',
      apellidos: (data['apellidos'] as String?) ?? '',
      documento: (data['documento'] as String?) ?? '',
      // Solo `false` desactiva: un perfil sin el campo se considera activo.
      active: data['estado'] != false,
      fechaRegistro: _date(data['fechaRegistro']),
      ultimoIngreso: _date(data['ultimoIngreso']),
    );
  }

  final String uid;
  final String email;

  /// `null` si el documento tiene un rol que la app no reconoce.
  final UserRole? role;
  final String nombres;
  final String apellidos;
  final String documento;
  final bool active;
  final DateTime? fechaRegistro;
  final DateTime? ultimoIngreso;

  String get fullName {
    final name = '$nombres $apellidos'.trim();
    return name.isEmpty ? email : name;
  }

  String get initials {
    final parts = [
      nombres,
      apellidos,
    ].map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      return email.isEmpty ? '?' : email.substring(0, 1).toUpperCase();
    }
    return parts.map((p) => p.substring(0, 1).toUpperCase()).join();
  }

  String get roleLabel => switch (role) {
    UserRole.paciente => 'Paciente',
    UserRole.cuidador => 'Cuidador',
    UserRole.admin => 'Admin',
    null => 'Sin rol',
  };

  /// Orden alfabético por apellido y nombre, sin distinguir mayúsculas.
  static int compareByName(ManagedUser a, ManagedUser b) {
    String key(ManagedUser u) =>
        '${u.apellidos} ${u.nombres} ${u.email}'.trim().toLowerCase();
    return key(a).compareTo(key(b));
  }
}

/// Datos para dar de alta una cuenta nueva.
class NewUser {
  const NewUser({
    required this.nombres,
    required this.apellidos,
    required this.email,
    required this.documento,
    required this.password,
    required this.role,
  });

  final String nombres;
  final String apellidos;
  final String email;
  final String documento;
  final String password;
  final UserRole role;

  /// Cuenta recién creada con estos datos.
  ManagedUser toManagedUser(User account) => ManagedUser(
    uid: account.uid,
    email: account.email ?? email.trim(),
    role: role,
    nombres: nombres.trim(),
    apellidos: apellidos.trim(),
    documento: documento,
    fechaRegistro: DateTime.now(),
  );

  /// Documento de `usuarios/{uid}` para la cuenta nueva.
  Map<String, Object?> profileFor(ManagedUser created, {String? creadoPor}) => {
    'email': created.email,
    'rol': role.id,
    'nombres': created.nombres,
    'apellidos': created.apellidos,
    'documento': created.documento,
    'estado': true,
    'fechaRegistro': FieldValue.serverTimestamp(),
    'creadoPor': creadoPor,
  };
}

/// Un evento del historial: un acceso (`accesos`) o un cambio (`auditoria`).
@immutable
class AuditEvent {
  const AuditEvent({
    required this.category,
    required this.actor,
    required this.time,
    required this.action,
    this.metaLeft = '',
    this.metaRight = '',
    this.failed = false,
  });

  /// Registro de `accesos`: inicio de sesión, cierre o registro.
  factory AuditEvent.fromAccess(Map<String, dynamic> data) {
    final failed = (data['resultado'] ?? 'exitoso') != 'exitoso';
    final role = UserRole.fromId(data['rol']);
    final via = data['canal'] == 'sms' ? 'SMS' : 'correo';
    // Una contraseña incorrecta no tiene sesión: solo queda el correo.
    final email = data['correo'] as String?;
    return AuditEvent(
      category: 'Login',
      actor: (data['nombreUsuario'] as String?) ?? email ?? 'Usuario',
      time: _date(data['fechaHora']) ?? DateTime.now(),
      action: switch (data['tipoEvento']) {
        'verificacion' when failed =>
          'Código de verificación incorrecto ($via)',
        'verificacion' => 'Verificó su identidad con el código ($via)',
        _ when failed => 'Intento fallido de inicio de sesión',
        'login' => 'Inició sesión',
        'logout' => 'Cerró sesión',
        'registro' => 'Creó su cuenta desde la app',
        'cierre_sesiones' => 'Cerró la sesión en los demás dispositivos',
        'logout_remoto' => 'Se cerró su sesión desde otro dispositivo',
        'logout_baja' => 'Se cerró su sesión: la cuenta fue dada de baja',
        final other => 'Evento de acceso: $other',
      },
      metaLeft: role != null
          ? 'Rol: ${role.label}'
          : (email != null ? 'Correo o contraseña incorrectos' : ''),
      metaRight: _platform(data['plataforma']),
      failed: failed,
    );
  }

  /// Registro de `auditoria`: un cambio hecho por alguien.
  factory AuditEvent.fromAudit(Map<String, dynamic> data) {
    final role = UserRole.fromId(data['rolActor']);
    return AuditEvent(
      category: (data['categoria'] as String?) ?? 'Cambios de datos',
      actor: (data['nombreActor'] as String?) ?? 'Usuario',
      time: _date(data['fechaHora']) ?? DateTime.now(),
      action: (data['accion'] as String?) ?? '',
      metaLeft: role == null ? '' : 'Rol: ${role.label}',
      metaRight: (data['detalle'] as String?) ?? '',
    );
  }

  final String category;
  final String actor;
  final DateTime time;
  final String action;
  final String metaLeft;
  final String metaRight;

  /// Se resalta en la lista (intentos fallidos, bloqueos).
  final bool failed;

  static String _platform(Object? id) => switch (id) {
    'android' => 'Android',
    'iOS' => 'iPhone',
    'web' => 'Web',
    'windows' => 'Windows',
    'macOS' => 'Mac',
    'linux' => 'Linux',
    null => '',
    final other => '$other',
  };
}

DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : null;

/// Punto de acceso que usan las pantallas del administrador. En los tests se
/// reemplaza [instance] por una versión con datos fijos.
abstract class AdminService {
  static AdminService instance = FirestoreAdminService();

  /// Todas las cuentas, ordenadas por apellido. Se actualiza solo.
  Stream<List<ManagedUser>> watchUsers();

  /// Accesos y cambios mezclados, del más reciente al más viejo.
  Stream<List<AuditEvent>> watchAuditLog({int limit = 100});

  Future<ManagedUser> createUser(NewUser data);

  Future<void> updateUser(
    ManagedUser user, {
    required String nombres,
    required String apellidos,
    required String documento,
  });

  Future<void> setRole(ManagedUser user, UserRole role);

  /// Baja (`false`) o reactivación (`true`). Nunca se borra la cuenta.
  Future<void> setActive(ManagedUser user, bool active);
}

class FirestoreAdminService implements AdminService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('usuarios');

  @override
  Stream<List<ManagedUser>> watchUsers() {
    try {
      return _users.snapshots().map((snap) {
        final users = [
          for (final doc in snap.docs) ManagedUser.fromMap(doc.id, doc.data()),
        ]..sort(ManagedUser.compareByName);
        return users;
      });
    } catch (e) {
      // Por ejemplo, Firebase no inicializado en esta plataforma.
      return Stream.error(e);
    }
  }

  @override
  Stream<List<AuditEvent>> watchAuditLog({int limit = 100}) {
    final subs = <StreamSubscription<Object?>>[];
    List<AuditEvent>? access;
    List<AuditEvent>? changes;
    late final StreamController<List<AuditEvent>> controller;

    void emit() {
      if (access == null || changes == null) return;
      final all = [...access!, ...changes!]
        ..sort((a, b) => b.time.compareTo(a.time));
      controller.add(all.take(limit).toList());
    }

    Query<Map<String, dynamic>> latest(String collection) => _db
        .collection(collection)
        .orderBy('fechaHora', descending: true)
        .limit(limit);

    controller = StreamController<List<AuditEvent>>(
      onListen: () {
        try {
          subs.add(
            latest('accesos').snapshots().listen((snap) {
              access = [
                for (final d in snap.docs) AuditEvent.fromAccess(d.data()),
              ];
              emit();
            }, onError: controller.addError),
          );
          subs.add(
            latest('auditoria').snapshots().listen((snap) {
              changes = [
                for (final d in snap.docs) AuditEvent.fromAudit(d.data()),
              ];
              emit();
            }, onError: controller.addError),
          );
        } catch (e) {
          controller.addError(e);
        }
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      },
    );
    return controller.stream;
  }

  @override
  Future<ManagedUser> createUser(NewUser data) => createAccount(
    email: data.email,
    password: data.password,
    writeProfile: (account) async {
      final created = data.toManagedUser(account);
      await _commit(
        created.uid,
        data.profileFor(created, creadoPor: _adminUid),
        create: true,
        accion: 'Dio de alta a ${created.fullName} como ${data.role.label}',
        detalle: 'Correo: ${created.email}',
      );
      return created;
    },
  );

  @override
  Future<void> updateUser(
    ManagedUser user, {
    required String nombres,
    required String apellidos,
    required String documento,
  }) async {
    final changes = <String, Object>{
      if (nombres.trim() != user.nombres) 'nombres': nombres.trim(),
      if (apellidos.trim() != user.apellidos) 'apellidos': apellidos.trim(),
      if (documento != user.documento) 'documento': documento,
    };
    if (changes.isEmpty) return;
    final fields = changes.keys.join(', ');
    final newName = ManagedUser(
      uid: user.uid,
      email: user.email,
      role: user.role,
      nombres: nombres.trim(),
      apellidos: apellidos.trim(),
    ).fullName;
    // Los vínculos guardan el nombre de cada parte: se corrigen en la misma
    // operación para que no quede el nombre viejo.
    final links = newName == user.fullName
        ? const <(DocumentReference<Map<String, dynamic>>, String)>[]
        : await _linksOf(user.uid);
    await _commit(
      user.uid,
      {...changes, 'fechaActualizacion': FieldValue.serverTimestamp()},
      accion: 'Actualizó los datos de ${user.fullName}',
      detalle: 'Campos: $fields',
      also: (batch) {
        for (final (ref, field) in links) {
          batch.update(ref, {field: newName});
        }
      },
    );
  }

  /// Vínculos donde participa [uid], con el campo que guarda su nombre.
  Future<List<(DocumentReference<Map<String, dynamic>>, String)>> _linksOf(
    String uid,
  ) async {
    final links = _db.collection('asignaciones');
    try {
      final asCaregiver = await links.where('idCuidador', isEqualTo: uid).get();
      final asPatient = await links.where('idPaciente', isEqualTo: uid).get();
      return [
        for (final doc in asCaregiver.docs) (doc.reference, 'nombreCuidador'),
        for (final doc in asPatient.docs) (doc.reference, 'nombrePaciente'),
      ];
    } catch (e) {
      throw AuthException(AuthService.describeError(e));
    }
  }

  @override
  Future<void> setRole(ManagedUser user, UserRole role) async {
    _rejectSelf(user);
    if (user.role == role) return;
    await _commit(
      user.uid,
      {'rol': role.id, 'fechaActualizacion': FieldValue.serverTimestamp()},
      accion: 'Cambió el rol de ${user.fullName}',
      detalle: '${user.role?.label ?? 'Sin rol'} → ${role.label}',
    );
  }

  @override
  Future<void> setActive(ManagedUser user, bool active) async {
    _rejectSelf(user);
    if (user.active == active) return;
    await _commit(
      user.uid,
      {'estado': active, 'fechaActualizacion': FieldValue.serverTimestamp()},
      accion: active
          ? 'Reactivó la cuenta de ${user.fullName}'
          : 'Dio de baja la cuenta de ${user.fullName}',
      detalle: 'Rol: ${user.role?.label ?? 'Sin rol'}',
    );
  }

  String? get _adminUid => FirebaseAuth.instance.currentUser?.uid;

  void _rejectSelf(ManagedUser user) {
    if (user.uid == _adminUid) {
      throw const AuthException(
        'No podés cambiar tu propio rol ni dar de baja tu propia cuenta. '
        'Pedíselo a otro administrador.',
      );
    }
  }

  /// Escribe el cambio en `usuarios` y su registro en `auditoria` juntos.
  Future<void> _commit(
    String uid,
    Map<String, Object?> data, {
    bool create = false,
    required String accion,
    required String detalle,
    void Function(WriteBatch batch)? also,
  }) async {
    final batch = _db.batch();
    final ref = _users.doc(uid);
    if (create) {
      batch.set(ref, data);
    } else {
      batch.update(ref, data);
    }
    also?.call(batch);
    batch.set(
      _db.collection('auditoria').doc(),
      auditRecord(
        accion: accion,
        detalle: detalle,
        entidad: 'usuarios',
        idEntidad: uid,
      ),
    );
    try {
      await batch.commit();
    } catch (e) {
      throw AuthException(AuthService.describeError(e));
    }
  }
}
