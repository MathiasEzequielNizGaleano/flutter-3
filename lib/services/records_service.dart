// Fichas del paciente y del cuidador, y el historial de diagnósticos.
//
// - PACIENTE              → `pacientes/{uid}` (datos personales y estado
//                            funcional)
// - CUIDADOR              → `cuidadores/{uid}`
// - HISTORIAL_DIAGNOSTICO → `pacientes/{uid}/diagnosticos/{id}`
//
// Nombres, apellidos, documento y correo siguen en `usuarios/{uid}`. El id
// de cada ficha es el uid de la cuenta, así las reglas comprueban el permiso
// del cuidador con una sola lectura de `asignaciones/{cuidador}_{paciente}`.
// Nada se borra: un diagnóstico se anula y queda en el historial.

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/date_format.dart';
import '../utils/streams.dart';
import 'admin_service.dart';
import 'audit.dart';
import 'auth_service.dart';

/// Opción guardada con un id fijo y mostrada con una etiqueta.
abstract interface class Choice {
  String get id;
  String get label;
}

T? choiceById<T extends Choice>(List<T> values, Object? id) {
  for (final value in values) {
    if (value.id == id) return value;
  }
  return null;
}

enum Sex implements Choice {
  masculino('masculino', 'Masculino'),
  femenino('femenino', 'Femenino'),
  otro('otro', 'Otro');

  const Sex(this.id, this.label);

  @override
  final String id;
  @override
  final String label;
}

/// Movilidad cervical y miofacial.
enum Mobility implements Choice {
  conservada('conservada', 'Conservada'),
  parcial('parcial', 'Parcial'),
  noConservada('no_conservada', 'No conservada');

  const Mobility(this.id, this.label);

  @override
  final String id;
  @override
  final String label;
}

enum HeadControl implements Choice {
  estable('estable', 'Estable'),
  parcial('parcial', 'Parcial'),
  inestable('inestable', 'Inestable');

  const HeadControl(this.id, this.label);

  @override
  final String id;
  @override
  final String label;
}

enum Assistance implements Choice {
  independiente('independiente', 'Independiente'),
  parcial('parcial', 'Parcial'),
  dependiente('dependiente', 'Dependiente');

  const Assistance(this.id, this.label);

  @override
  final String id;
  @override
  final String label;
}

enum DiagnosisType implements Choice {
  principal('principal', 'Principal'),
  secundario('secundario', 'Secundario'),
  antecedente('antecedente', 'Antecedente');

  const DiagnosisType(this.id, this.label);

  @override
  final String id;
  @override
  final String label;
}

String _text(Object? value) => value is String ? value : '';
DateTime? _time(Object? value) => value is Timestamp ? value.toDate() : null;
String? _iso(DateTime? date) => date == null ? null : toIsoDate(date);

/// Estado funcional del paciente: de esto depende que pueda usar el
/// HeadMouse con la cabeza y los pulsadores.
@immutable
class FunctionalState {
  const FunctionalState({
    this.movilidadCervical,
    this.movilidadMiofacial,
    this.controlCefalico,
    this.nivelAsistencia,
    this.limitacionMiembrosSuperiores = false,
    this.movimientosInvoluntarios = false,
    this.puedeClipIzquierdo = true,
    this.puedeClipDerecho = true,
    this.observaciones = '',
    this.fechaEvaluacion,
    this.nombreEvaluador = '',
  });

  factory FunctionalState.fromMap(Map<String, dynamic> data) => FunctionalState(
    movilidadCervical: choiceById(Mobility.values, data['movilidadCervical']),
    movilidadMiofacial: choiceById(Mobility.values, data['movilidadMiofacial']),
    controlCefalico: choiceById(HeadControl.values, data['controlCefalico']),
    nivelAsistencia: choiceById(Assistance.values, data['nivelAsistencia']),
    limitacionMiembrosSuperiores: data['limitacionMiembrosSuperiores'] == true,
    movimientosInvoluntarios: data['movimientosInvoluntarios'] == true,
    puedeClipIzquierdo: data['puedeActivarClipIzquierdo'] != false,
    puedeClipDerecho: data['puedeActivarClipDerecho'] != false,
    observaciones: _text(data['observacionesFuncionales']),
    fechaEvaluacion: _time(data['fechaEvaluacion']),
    nombreEvaluador: _text(data['nombreEvaluador']),
  );

  final Mobility? movilidadCervical;
  final Mobility? movilidadMiofacial;
  final HeadControl? controlCefalico;
  final Assistance? nivelAsistencia;
  final bool limitacionMiembrosSuperiores;
  final bool movimientosInvoluntarios;
  final bool puedeClipIzquierdo;
  final bool puedeClipDerecho;
  final String observaciones;

  /// Los completa el servicio al guardar.
  final DateTime? fechaEvaluacion;
  final String nombreEvaluador;

  /// La más reciente primero; sin fecha (recién guardada) arriba.
  static int newestFirst(FunctionalState a, FunctionalState b) {
    final da = a.fechaEvaluacion;
    final db = b.fechaEvaluacion;
    if (da == null || db == null) return da == null ? (db == null ? 0 : -1) : 1;
    return db.compareTo(da);
  }

  /// Campos que escribe la app (la fecha y el evaluador los agrega el
  /// servicio).
  Map<String, Object?> toMap() => {
    'movilidadCervical': movilidadCervical?.id,
    'movilidadMiofacial': movilidadMiofacial?.id,
    'controlCefalico': controlCefalico?.id,
    'nivelAsistencia': nivelAsistencia?.id,
    'limitacionMiembrosSuperiores': limitacionMiembrosSuperiores,
    'movimientosInvoluntarios': movimientosInvoluntarios,
    'puedeActivarClipIzquierdo': puedeClipIzquierdo,
    'puedeActivarClipDerecho': puedeClipDerecho,
    'observacionesFuncionales': observaciones.trim(),
  };
}

/// Ficha del paciente (tabla PACIENTE, sin los datos que están en USUARIO).
@immutable
class PatientRecord {
  const PatientRecord({
    this.fechaNacimiento,
    this.sexo,
    this.telefono = '',
    this.direccion = '',
    this.registroSenadis = '',
    this.contactoEmergencia = '',
    this.telefonoEmergencia = '',
    this.estadoFuncional,
    this.fechaActualizacion,
  });

  factory PatientRecord.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const PatientRecord();
    final functional = data['estadoFuncional'];
    return PatientRecord(
      fechaNacimiento: parseIsoDate(data['fechaNacimiento']),
      sexo: choiceById(Sex.values, data['sexo']),
      telefono: _text(data['telefono']),
      direccion: _text(data['direccion']),
      registroSenadis: _text(data['registroSenadis']),
      contactoEmergencia: _text(data['contactoEmergencia']),
      telefonoEmergencia: _text(data['telefonoEmergencia']),
      estadoFuncional: functional is Map<String, dynamic>
          ? FunctionalState.fromMap(functional)
          : null,
      fechaActualizacion: _time(data['fechaActualizacion']),
    );
  }

  /// Lo único que el paciente puede cambiar de su propia ficha. El resto lo
  /// cargan su cuidador o el administrador.
  static const selfEditableKeys = [
    'telefono',
    'direccion',
    'contactoEmergencia',
    'telefonoEmergencia',
  ];

  final DateTime? fechaNacimiento;
  final Sex? sexo;
  final String telefono;
  final String direccion;
  final String registroSenadis;
  final String contactoEmergencia;
  final String telefonoEmergencia;

  /// `null` mientras nadie haya registrado la evaluación funcional.
  final FunctionalState? estadoFuncional;
  final DateTime? fechaActualizacion;

  Map<String, Object?> toPersonalMap() => {
    'fechaNacimiento': _iso(fechaNacimiento),
    'sexo': sexo?.id,
    'telefono': telefono.trim(),
    'direccion': direccion.trim(),
    'registroSenadis': registroSenadis.trim(),
    'contactoEmergencia': contactoEmergencia.trim(),
    'telefonoEmergencia': telefonoEmergencia.trim(),
  };
}

/// Ficha del cuidador (tabla CUIDADOR, sin los datos que están en USUARIO).
@immutable
class CaregiverRecord {
  const CaregiverRecord({
    this.fechaNacimiento,
    this.sexo,
    this.telefono = '',
    this.direccion = '',
    this.correoAlternativo = '',
    this.ocupacion = '',
    this.observaciones = '',
    this.fechaActualizacion,
  });

  factory CaregiverRecord.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const CaregiverRecord();
    return CaregiverRecord(
      fechaNacimiento: parseIsoDate(data['fechaNacimiento']),
      sexo: choiceById(Sex.values, data['sexo']),
      telefono: _text(data['telefono']),
      direccion: _text(data['direccion']),
      correoAlternativo: _text(data['correoAlternativo']),
      ocupacion: _text(data['ocupacion']),
      observaciones: _text(data['observaciones']),
      fechaActualizacion: _time(data['fechaActualizacion']),
    );
  }

  final DateTime? fechaNacimiento;
  final Sex? sexo;
  final String telefono;
  final String direccion;
  final String correoAlternativo;
  final String ocupacion;
  final String observaciones;
  final DateTime? fechaActualizacion;

  Map<String, Object?> toMap() => {
    'fechaNacimiento': _iso(fechaNacimiento),
    'sexo': sexo?.id,
    'telefono': telefono.trim(),
    'direccion': direccion.trim(),
    'correoAlternativo': correoAlternativo.trim(),
    'ocupacion': ocupacion.trim(),
    'observaciones': observaciones.trim(),
  };
}

/// Una entrada de HISTORIAL_DIAGNOSTICO.
@immutable
class Diagnosis {
  const Diagnosis({
    this.id = '',
    required this.idPaciente,
    required this.tipo,
    required this.diagnostico,
    this.descripcion = '',
    this.fechaDiagnostico,
    this.profesional = '',
    this.institucion = '',
    this.especialidad = '',
    this.esActual = true,
    this.anulado = false,
    this.nombreRegistrador = '',
    this.fechaRegistro,
    this.nombreModificador = '',
    this.fechaModificacion,
    this.adjuntos = 0,
  });

  factory Diagnosis.fromMap(String id, Map<String, dynamic> data) => Diagnosis(
    id: id,
    idPaciente: _text(data['idPaciente']),
    tipo:
        choiceById(DiagnosisType.values, data['tipoDiagnostico']) ??
        DiagnosisType.secundario,
    diagnostico: _text(data['diagnostico']),
    descripcion: _text(data['descripcion']),
    fechaDiagnostico: parseIsoDate(data['fechaDiagnostico']),
    profesional: _text(data['profesionalInformante']),
    institucion: _text(data['institucion']),
    especialidad: _text(data['especialidad']),
    esActual: data['esActual'] == true,
    // estado = false es "anulado" en la tabla del documento.
    anulado: data['estado'] == false,
    nombreRegistrador: _text(data['nombreRegistrador']),
    fechaRegistro: _time(data['fechaRegistro']),
    nombreModificador: _text(data['nombreModificador']),
    fechaModificacion: _time(data['fechaModificacion']),
    adjuntos: max(0, (data['adjuntos'] as num?)?.toInt() ?? 0),
  );

  /// Vacío mientras no se guardó.
  final String id;
  final String idPaciente;
  final DiagnosisType tipo;
  final String diagnostico;
  final String descripcion;
  final DateTime? fechaDiagnostico;
  final String profesional;
  final String institucion;
  final String especialidad;

  /// Sigue vigente (`es_actual`).
  final bool esActual;
  final bool anulado;

  final String nombreRegistrador;
  final DateTime? fechaRegistro;
  final String nombreModificador;
  final DateTime? fechaModificacion;

  /// Documentos de respaldo vigentes (ver attachment_service.dart).
  final int adjuntos;

  /// Vigente y sin anular.
  bool get isCurrent => esActual && !anulado;

  /// "Fisioterapia · CDT UNIDA"
  String get source => [
    especialidad,
    institucion,
  ].where((part) => part.trim().isNotEmpty).join(' · ');

  Diagnosis copyWith({
    String? id,
    DiagnosisType? tipo,
    String? diagnostico,
    String? descripcion,
    DateTime? Function()? fechaDiagnostico,
    String? profesional,
    String? institucion,
    String? especialidad,
    bool? esActual,
  }) => Diagnosis(
    id: id ?? this.id,
    idPaciente: idPaciente,
    tipo: tipo ?? this.tipo,
    diagnostico: diagnostico ?? this.diagnostico,
    descripcion: descripcion ?? this.descripcion,
    fechaDiagnostico: fechaDiagnostico == null
        ? this.fechaDiagnostico
        : fechaDiagnostico(),
    profesional: profesional ?? this.profesional,
    institucion: institucion ?? this.institucion,
    especialidad: especialidad ?? this.especialidad,
    esActual: esActual ?? this.esActual,
    anulado: anulado,
    nombreRegistrador: nombreRegistrador,
    fechaRegistro: fechaRegistro,
    nombreModificador: nombreModificador,
    fechaModificacion: fechaModificacion,
    adjuntos: adjuntos,
  );

  /// Campos que se pueden editar.
  Map<String, Object?> toEditableMap() => {
    'tipoDiagnostico': tipo.id,
    'diagnostico': diagnostico.trim(),
    'descripcion': descripcion.trim(),
    'fechaDiagnostico': _iso(fechaDiagnostico),
    'profesionalInformante': profesional.trim(),
    'institucion': institucion.trim(),
    'especialidad': especialidad.trim(),
    'esActual': esActual,
  };

  /// Mismo contenido editable (para saber si hay cambios sin guardar).
  bool sameContentAs(Diagnosis other) =>
      mapEquals(toEditableMap(), other.toEditableMap());

  /// Orden de las listas: primero lo vigente, después por tipo (principal,
  /// secundario, antecedente) y por fecha, más nuevo arriba; los anulados
  /// al final.
  static int compare(Diagnosis a, Diagnosis b) {
    if (a.anulado != b.anulado) return a.anulado ? 1 : -1;
    if (a.esActual != b.esActual) return a.esActual ? -1 : 1;
    if (a.tipo != b.tipo) return a.tipo.index.compareTo(b.tipo.index);
    final da = a.fechaDiagnostico ?? a.fechaRegistro;
    final db = b.fechaDiagnostico ?? b.fechaRegistro;
    if (da == null || db == null) return da == null ? (db == null ? 0 : 1) : -1;
    return db.compareTo(da);
  }
}

/// Punto de acceso de las pantallas. En los tests se reemplaza [instance].
abstract class RecordsService {
  static RecordsService instance = FirestoreRecordsService();

  /// Cuenta de `usuarios/{uid}`: documento, correo y último ingreso.
  Stream<ManagedUser> watchAccount(String uid);

  Stream<PatientRecord> watchPatient(String uid);

  /// Fichas de todos los pacientes por uid (solo administradores, para
  /// los reportes).
  Stream<Map<String, PatientRecord>> watchAllPatients();

  /// Guarda los datos personales. Con [selfEdit] (el propio paciente) solo
  /// se guardan [PatientRecord.selfEditableKeys].
  Future<void> savePatient(
    String uid,
    PatientRecord record, {
    required String nombre,
    bool selfEdit = false,
  });

  Future<void> saveFunctionalState(
    String uid,
    FunctionalState state, {
    required String nombre,
  });

  Stream<CaregiverRecord> watchCaregiver(String uid);

  Future<void> saveCaregiver(
    String uid,
    CaregiverRecord record, {
    required String nombre,
  });

  /// Diagnósticos de un paciente, anulados incluidos.
  Stream<List<Diagnosis>> watchDiagnoses(String patientUid);

  /// Diagnósticos de todos los pacientes (solo administradores).
  Stream<List<Diagnosis>> watchAllDiagnoses();

  /// Registra un diagnóstico. Si es principal y vigente, el principal
  /// anterior deja de ser vigente (no se borra).
  /// Devuelve el id del diagnóstico nuevo.
  Future<String> addDiagnosis(Diagnosis diagnosis, {required String paciente});

  Future<void> updateDiagnosis(
    Diagnosis before,
    Diagnosis after, {
    required String paciente,
  });

  /// Anula el diagnóstico: deja de mostrarse como vigente pero queda en el
  /// historial.
  Future<void> annulDiagnosis(Diagnosis diagnosis, {required String paciente});

  /// Evaluaciones funcionales del paciente, la más reciente primero.
  Stream<List<FunctionalState>> watchEvaluations(String patientUid);

  /// Diagnósticos de varios pacientes juntos (los de un cuidador).
  Stream<List<Diagnosis>> watchDiagnosesFor(List<String> patientUids) =>
      mergeLatest([
        for (final uid in patientUids.toSet()) watchDiagnoses(uid),
      ], compare: Diagnosis.compare);
}

class FirestoreRecordsService extends RecordsService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String get _actorName => AuthService.instance.current?.fullName ?? 'Usuario';

  DocumentReference<Map<String, dynamic>> _patient(String uid) =>
      _db.doc('pacientes/$uid');
  CollectionReference<Map<String, dynamic>> _diagnoses(String uid) =>
      _patient(uid).collection('diagnosticos');

  Stream<T> _guard<T>(Stream<T> Function() build) {
    try {
      return build();
    } catch (e) {
      // Por ejemplo, Firebase no inicializado en esta plataforma.
      return Stream.error(e);
    }
  }

  @override
  Stream<ManagedUser> watchAccount(String uid) => _guard(
    () => _db
        .doc('usuarios/$uid')
        .snapshots()
        .map((snap) => ManagedUser.fromMap(uid, snap.data() ?? const {})),
  );

  @override
  Stream<PatientRecord> watchPatient(String uid) => _guard(
    () => _patient(
      uid,
    ).snapshots().map((snap) => PatientRecord.fromMap(snap.data())),
  );

  @override
  Stream<Map<String, PatientRecord>> watchAllPatients() => _guard(
    () => _db
        .collection('pacientes')
        .snapshots()
        .map(
          (snap) => {
            for (final doc in snap.docs)
              doc.id: PatientRecord.fromMap(doc.data()),
          },
        ),
  );

  @override
  Future<void> savePatient(
    String uid,
    PatientRecord record, {
    required String nombre,
    bool selfEdit = false,
  }) async {
    final all = record.toPersonalMap();
    final data = selfEdit
        ? {for (final key in PatientRecord.selfEditableKeys) key: all[key]}
        : all;
    await _commit(
      (batch) => batch.set(_patient(uid), {
        ...data,
        'fechaActualizacion': FieldValue.serverTimestamp(),
        'actualizadoPor': _uid,
      }, SetOptions(merge: true)),
      accion: selfEdit
          ? 'Actualizó sus datos de contacto'
          : 'Actualizó los datos personales de $nombre',
      detalle: selfEdit
          ? 'Teléfono, dirección y contacto de emergencia'
          : 'Ficha del paciente',
      entidad: 'pacientes',
      idEntidad: uid,
    );
  }

  @override
  Future<void> saveFunctionalState(
    String uid,
    FunctionalState state, {
    required String nombre,
  }) async {
    final evaluation = {
      ...state.toMap(),
      'fechaEvaluacion': FieldValue.serverTimestamp(),
      'evaluadoPor': _uid,
      'nombreEvaluador': _actorName,
    };
    await _commit(
      (batch) {
        // La ficha muestra la última; cada evaluación queda además en el
        // historial del paciente.
        batch.set(_patient(uid), {
          'estadoFuncional': evaluation,
          'fechaActualizacion': FieldValue.serverTimestamp(),
          'actualizadoPor': _uid,
        }, SetOptions(merge: true));
        batch.set(_patient(uid).collection('evaluaciones').doc(), {
          ...evaluation,
          'idPaciente': uid,
        });
      },
      accion: 'Registró el estado funcional de $nombre',
      detalle: [
        'Cervical: ${state.movilidadCervical?.label ?? '—'}',
        'Miofacial: ${state.movilidadMiofacial?.label ?? '—'}',
      ].join(' · '),
      entidad: 'pacientes',
      idEntidad: uid,
    );
  }

  @override
  Stream<List<FunctionalState>> watchEvaluations(String patientUid) => _guard(
    () => _patient(patientUid)
        .collection('evaluaciones')
        .snapshots()
        .map(
          (snap) =>
              [for (final doc in snap.docs) FunctionalState.fromMap(doc.data())]
                ..sort(FunctionalState.newestFirst),
        ),
  );

  @override
  Stream<CaregiverRecord> watchCaregiver(String uid) => _guard(
    () => _db
        .doc('cuidadores/$uid')
        .snapshots()
        .map((snap) => CaregiverRecord.fromMap(snap.data())),
  );

  @override
  Future<void> saveCaregiver(
    String uid,
    CaregiverRecord record, {
    required String nombre,
  }) async {
    await _commit(
      (batch) => batch.set(_db.doc('cuidadores/$uid'), {
        ...record.toMap(),
        'fechaActualizacion': FieldValue.serverTimestamp(),
        'actualizadoPor': _uid,
      }, SetOptions(merge: true)),
      accion: uid == _uid
          ? 'Actualizó sus datos personales'
          : 'Actualizó los datos personales de $nombre',
      detalle: 'Ficha del cuidador',
      entidad: 'cuidadores',
      idEntidad: uid,
    );
  }

  List<Diagnosis> _sorted(QuerySnapshot<Map<String, dynamic>> snap) =>
      [for (final doc in snap.docs) Diagnosis.fromMap(doc.id, doc.data())]
        ..sort(Diagnosis.compare);

  @override
  Stream<List<Diagnosis>> watchDiagnoses(String patientUid) =>
      _guard(() => _diagnoses(patientUid).snapshots().map(_sorted));

  @override
  Stream<List<Diagnosis>> watchAllDiagnoses() => _guard(
    () => _db.collectionGroup('diagnosticos').snapshots().map(_sorted),
  );

  /// Principales vigentes de un paciente, salvo [exceptId].
  Future<List<DocumentReference<Map<String, dynamic>>>> _currentPrincipals(
    String patientUid, {
    String? exceptId,
  }) async {
    final snap = await _diagnoses(
      patientUid,
    ).where('tipoDiagnostico', isEqualTo: DiagnosisType.principal.id).get();
    return [
      for (final doc in snap.docs)
        if (doc.id != exceptId &&
            doc.data()['esActual'] == true &&
            doc.data()['estado'] != false)
          doc.reference,
    ];
  }

  Map<String, Object?> get _modified => {
    'modificadoPor': _uid,
    'nombreModificador': _actorName,
    'fechaModificacion': FieldValue.serverTimestamp(),
  };

  Future<List<DocumentReference<Map<String, dynamic>>>> _toSupersede(
    Diagnosis d, {
    String? exceptId,
  }) async {
    if (d.tipo != DiagnosisType.principal || !d.esActual) return const [];
    try {
      return await _currentPrincipals(d.idPaciente, exceptId: exceptId);
    } catch (e) {
      throw AuthException(AuthService.describeError(e));
    }
  }

  @override
  Future<String> addDiagnosis(
    Diagnosis diagnosis, {
    required String paciente,
  }) async {
    final previous = await _toSupersede(diagnosis);
    final ref = _diagnoses(diagnosis.idPaciente).doc();
    await _commit(
      (batch) {
        for (final old in previous) {
          batch.update(old, {'esActual': false, ..._modified});
        }
        batch.set(ref, {
          'idPaciente': diagnosis.idPaciente,
          ...diagnosis.toEditableMap(),
          'estado': true,
          'registradoPor': _uid,
          'nombreRegistrador': _actorName,
          'rolRegistrador': AuthService.instance.current?.role.id,
          'fechaRegistro': FieldValue.serverTimestamp(),
        });
      },
      accion: 'Registró un diagnóstico de $paciente',
      detalle:
          '${diagnosis.tipo.label}: ${diagnosis.diagnostico.trim()}'
          '${previous.isEmpty ? '' : ' (el principal anterior dejó de estar vigente)'}',
      entidad: 'diagnosticos',
      idEntidad: '${diagnosis.idPaciente}/${ref.id}',
    );
    return ref.id;
  }

  @override
  Future<void> updateDiagnosis(
    Diagnosis before,
    Diagnosis after, {
    required String paciente,
  }) async {
    if (before.sameContentAs(after)) return;
    final previous = await _toSupersede(after, exceptId: before.id);
    await _commit(
      (batch) {
        for (final old in previous) {
          batch.update(old, {'esActual': false, ..._modified});
        }
        batch.update(_diagnoses(before.idPaciente).doc(before.id), {
          ...after.toEditableMap(),
          ..._modified,
        });
      },
      accion: 'Modificó un diagnóstico de $paciente',
      detalle: '${after.tipo.label}: ${after.diagnostico.trim()}',
      entidad: 'diagnosticos',
      idEntidad: '${before.idPaciente}/${before.id}',
    );
  }

  @override
  Future<void> annulDiagnosis(
    Diagnosis diagnosis, {
    required String paciente,
  }) async {
    await _commit(
      (batch) =>
          batch.update(_diagnoses(diagnosis.idPaciente).doc(diagnosis.id), {
            'estado': false,
            'esActual': false,
            'anuladoPor': _uid,
            'fechaAnulacion': FieldValue.serverTimestamp(),
            ..._modified,
          }),
      accion: 'Anuló un diagnóstico de $paciente',
      detalle: '${diagnosis.tipo.label}: ${diagnosis.diagnostico}',
      entidad: 'diagnosticos',
      idEntidad: '${diagnosis.idPaciente}/${diagnosis.id}',
    );
  }

  /// Escribe el cambio y su registro de auditoría en la misma operación.
  Future<void> _commit(
    void Function(WriteBatch batch) write, {
    required String accion,
    required String detalle,
    required String entidad,
    required String idEntidad,
  }) async {
    try {
      final batch = _db.batch();
      write(batch);
      batch.set(
        _db.collection('auditoria').doc(),
        auditRecord(
          accion: accion,
          detalle: detalle,
          entidad: entidad,
          idEntidad: idEntidad,
        ),
      );
      await batch.commit();
    } catch (e) {
      throw AuthException(AuthService.describeError(e));
    }
  }
}
