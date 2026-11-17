// Vínculo cuidador ↔ paciente (tabla CUIDADOR_PACIENTE del documento).
//
// Cada vínculo es un documento `asignaciones/{idCuidador}_{idPaciente}`.
// El id fijo permite que las reglas de seguridad comprueben en una sola
// lectura si un cuidador tiene permiso sobre un paciente. Los vínculos no se
// borran: al terminar quedan con `activo = false` y su `fechaFin`.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'accounts.dart';
import 'admin_service.dart';
import 'audit.dart';
import 'auth_service.dart';

enum Responsibility {
  principal('principal', 'Principal'),
  secundario('secundario', 'Secundario'),
  temporal('temporal', 'Temporal');

  const Responsibility(this.id, this.label);

  final String id;
  final String label;

  static Responsibility fromId(Object? id) => values.firstWhere(
    (r) => r.id == id,
    orElse: () => Responsibility.secundario,
  );
}

/// Opciones de parentesco que ofrece la app.
const kinshipOptions = [
  'Madre',
  'Padre',
  'Hermano/a',
  'Hijo/a',
  'Pareja',
  'Tutor/a',
  'Acompañante',
  'Profesional de salud',
  'Otro',
];

@immutable
class CarePermissions {
  const CarePermissions({
    this.verDatos = true,
    this.editarDatos = false,
    this.configurar = true,
    this.calibrar = true,
  });

  factory CarePermissions.fromMap(Map<String, dynamic> data) => CarePermissions(
    verDatos: data['puedeVerDatos'] == true,
    editarDatos: data['puedeEditarDatos'] == true,
    configurar: data['puedeConfigurar'] == true,
    calibrar: data['puedeCalibrar'] == true,
  );

  final bool verDatos;
  final bool editarDatos;
  final bool configurar;
  final bool calibrar;

  Map<String, bool> toMap() => {
    'puedeVerDatos': verDatos,
    'puedeEditarDatos': editarDatos,
    'puedeConfigurar': configurar,
    'puedeCalibrar': calibrar,
  };

  CarePermissions copyWith({
    bool? verDatos,
    bool? editarDatos,
    bool? configurar,
    bool? calibrar,
  }) => CarePermissions(
    verDatos: verDatos ?? this.verDatos,
    editarDatos: editarDatos ?? this.editarDatos,
    configurar: configurar ?? this.configurar,
    calibrar: calibrar ?? this.calibrar,
  );

  /// Lista corta para mostrar: "Ver, Configurar, Calibrar".
  String get summary {
    final granted = [
      if (verDatos) 'Ver',
      if (editarDatos) 'Editar',
      if (configurar) 'Configurar',
      if (calibrar) 'Calibrar',
    ];
    return granted.isEmpty ? 'Sin permisos' : granted.join(', ');
  }

  @override
  bool operator ==(Object other) =>
      other is CarePermissions &&
      other.verDatos == verDatos &&
      other.editarDatos == editarDatos &&
      other.configurar == configurar &&
      other.calibrar == calibrar;

  @override
  int get hashCode => Object.hash(verDatos, editarDatos, configurar, calibrar);
}

@immutable
class CareAssignment {
  const CareAssignment({
    required this.idCuidador,
    required this.idPaciente,
    required this.nombreCuidador,
    required this.nombrePaciente,
    required this.parentesco,
    required this.responsabilidad,
    required this.permisos,
    this.activo = true,
    this.fechaAsignacion,
    this.fechaFin,
  });

  factory CareAssignment.fromMap(Map<String, dynamic> data) => CareAssignment(
    idCuidador: (data['idCuidador'] as String?) ?? '',
    idPaciente: (data['idPaciente'] as String?) ?? '',
    nombreCuidador: (data['nombreCuidador'] as String?) ?? 'Cuidador',
    nombrePaciente: (data['nombrePaciente'] as String?) ?? 'Paciente',
    parentesco: (data['parentesco'] as String?) ?? '',
    responsabilidad: Responsibility.fromId(data['tipoResponsabilidad']),
    permisos: CarePermissions.fromMap(data),
    activo: data['activo'] == true,
    fechaAsignacion: _date(data['fechaAsignacion']),
    fechaFin: _date(data['fechaFin']),
  );

  static String idFor(String idCuidador, String idPaciente) =>
      '${idCuidador}_$idPaciente';

  final String idCuidador;
  final String idPaciente;
  final String nombreCuidador;
  final String nombrePaciente;
  final String parentesco;
  final Responsibility responsabilidad;
  final CarePermissions permisos;
  final bool activo;
  final DateTime? fechaAsignacion;
  final DateTime? fechaFin;

  String get id => idFor(idCuidador, idPaciente);

  /// "Madre · Principal"
  String get relation => [
    if (parentesco.isNotEmpty) parentesco,
    responsabilidad.label,
  ].join(' · ');
}

DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : null;

abstract class CareService {
  static CareService instance = FirestoreCareService();

  /// Vínculos de un cuidador. Con [includeEnded] también los terminados.
  Stream<List<CareAssignment>> watchForCaregiver(
    String uid, {
    bool includeEnded = false,
  });

  /// Vínculos de un paciente. Con [includeEnded] también los terminados.
  Stream<List<CareAssignment>> watchForPatient(
    String uid, {
    bool includeEnded = false,
  });

  /// Crea el vínculo, o lo reactiva si ya existió. Solo administradores.
  Future<void> assign({
    required ManagedUser caregiver,
    required ManagedUser patient,
    required String parentesco,
    required Responsibility responsabilidad,
    required CarePermissions permisos,
  });

  /// Cambia parentesco, tipo o permisos de un vínculo. Solo administradores.
  Future<void> update(
    CareAssignment assignment, {
    required String parentesco,
    required Responsibility responsabilidad,
    required CarePermissions permisos,
  });

  /// Termina el vínculo. Lo puede hacer el administrador o el paciente.
  Future<void> end(CareAssignment assignment);

  /// El cuidador da de alta a un paciente nuevo (con su cuenta) y queda
  /// vinculado con todos los permisos. Devuelve la cuenta creada.
  Future<ManagedUser> registerPatient(
    NewUser data, {
    required String parentesco,
    required Responsibility responsabilidad,
  });
}

class FirestoreCareService implements CareService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _links =>
      _db.collection('asignaciones');

  Stream<List<CareAssignment>> _watch(
    String field,
    String uid,
    bool includeEnded,
    String Function(CareAssignment) sortKey,
  ) {
    try {
      // Un solo filtro por igualdad: no necesita índices compuestos y las
      // reglas pueden comprobar que cada uno lee solo lo suyo.
      return _links.where(field, isEqualTo: uid).snapshots().map((snap) {
        final list = [
          for (final doc in snap.docs) CareAssignment.fromMap(doc.data()),
        ].where((a) => includeEnded || a.activo).toList();
        list.sort((a, b) {
          if (a.activo != b.activo) return a.activo ? -1 : 1;
          return sortKey(a).toLowerCase().compareTo(sortKey(b).toLowerCase());
        });
        return list;
      });
    } catch (e) {
      return Stream.error(e);
    }
  }

  @override
  Stream<List<CareAssignment>> watchForCaregiver(
    String uid, {
    bool includeEnded = false,
  }) => _watch('idCuidador', uid, includeEnded, (a) => a.nombrePaciente);

  @override
  Stream<List<CareAssignment>> watchForPatient(
    String uid, {
    bool includeEnded = false,
  }) => _watch('idPaciente', uid, includeEnded, (a) => a.nombreCuidador);

  @override
  Future<void> assign({
    required ManagedUser caregiver,
    required ManagedUser patient,
    required String parentesco,
    required Responsibility responsabilidad,
    required CarePermissions permisos,
  }) async {
    final id = CareAssignment.idFor(caregiver.uid, patient.uid);
    await _commit(
      id,
      {
        'idCuidador': caregiver.uid,
        'idPaciente': patient.uid,
        'nombreCuidador': caregiver.fullName,
        'nombrePaciente': patient.fullName,
        'parentesco': parentesco,
        'tipoResponsabilidad': responsabilidad.id,
        ...permisos.toMap(),
        'activo': true,
        'fechaAsignacion': FieldValue.serverTimestamp(),
        'fechaFin': null,
        'asignadoPor': FirebaseAuth.instance.currentUser?.uid,
      },
      overwrite: true,
      accion:
          'Asignó a ${caregiver.fullName} como cuidador de '
          '${patient.fullName}',
      detalle: '$parentesco · ${responsabilidad.label}',
    );
  }

  @override
  Future<void> update(
    CareAssignment assignment, {
    required String parentesco,
    required Responsibility responsabilidad,
    required CarePermissions permisos,
  }) async {
    final changed = [
      if (parentesco != assignment.parentesco) 'parentesco',
      if (responsabilidad != assignment.responsabilidad) 'tipo',
      if (permisos != assignment.permisos) 'permisos',
    ];
    if (changed.isEmpty) return;
    await _commit(
      assignment.id,
      {
        'parentesco': parentesco,
        'tipoResponsabilidad': responsabilidad.id,
        ...permisos.toMap(),
      },
      accion:
          'Modificó el vínculo de ${assignment.nombreCuidador} con '
          '${assignment.nombrePaciente}',
      detalle: 'Permisos: ${permisos.summary}',
    );
  }

  @override
  Future<void> end(CareAssignment assignment) async {
    await _commit(
      assignment.id,
      {
        'activo': false,
        'fechaFin': FieldValue.serverTimestamp(),
        'finalizadoPor': FirebaseAuth.instance.currentUser?.uid,
      },
      accion:
          'Terminó el vínculo de ${assignment.nombreCuidador} con '
          '${assignment.nombrePaciente}',
      detalle: assignment.relation,
    );
  }

  @override
  Future<ManagedUser> registerPatient(
    NewUser data, {
    required String parentesco,
    required Responsibility responsabilidad,
  }) {
    final me = AuthService.instance.current;
    if (me == null || me.role != UserRole.cuidador) {
      throw const AuthException('Solo un cuidador puede registrar pacientes.');
    }
    if (data.role != UserRole.paciente) {
      throw const AuthException('La cuenta nueva tiene que ser de paciente.');
    }
    return createAccount(
      email: data.email,
      password: data.password,
      writeProfile: (account) async {
        final patient = data.toManagedUser(account);
        final id = CareAssignment.idFor(me.uid, patient.uid);
        // Perfil y vínculo juntos: las reglas solo dejan crear el perfil si
        // en la misma operación queda vinculado a quien lo registra.
        final batch = _db.batch();
        batch.set(
          _db.doc('usuarios/${patient.uid}'),
          data.profileFor(patient, creadoPor: me.uid),
        );
        batch.set(_links.doc(id), {
          'idCuidador': me.uid,
          'idPaciente': patient.uid,
          'nombreCuidador': me.fullName,
          'nombrePaciente': patient.fullName,
          'parentesco': parentesco,
          'tipoResponsabilidad': responsabilidad.id,
          ...const CarePermissions(editarDatos: true).toMap(),
          'activo': true,
          'fechaAsignacion': FieldValue.serverTimestamp(),
          'fechaFin': null,
          'asignadoPor': me.uid,
        });
        batch.set(
          _db.collection('auditoria').doc(),
          auditRecord(
            accion:
                'Registró al paciente ${patient.fullName} y quedó como su '
                'cuidador',
            detalle: '$parentesco · ${responsabilidad.label}',
            entidad: 'usuarios',
            idEntidad: patient.uid,
          ),
        );
        try {
          await batch.commit();
        } catch (e) {
          throw AuthException(AuthService.describeError(e));
        }
        return patient;
      },
    );
  }

  Future<void> _commit(
    String id,
    Map<String, Object?> data, {
    bool overwrite = false,
    required String accion,
    required String detalle,
  }) async {
    final batch = _db.batch();
    final ref = _links.doc(id);
    if (overwrite) {
      batch.set(ref, data);
    } else {
      batch.update(ref, data);
    }
    batch.set(
      _db.collection('auditoria').doc(),
      auditRecord(
        accion: accion,
        detalle: detalle,
        entidad: 'asignaciones',
        idEntidad: id,
      ),
    );
    try {
      await batch.commit();
    } catch (e) {
      throw AuthException(AuthService.describeError(e));
    }
  }
}
