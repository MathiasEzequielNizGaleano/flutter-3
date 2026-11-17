import 'package:headmouse_pro/services/admin_service.dart';
import 'package:headmouse_pro/services/auth_service.dart';
import 'package:headmouse_pro/services/records_service.dart';

import 'fake_admin_service.dart';

/// RecordsService con fichas y diagnósticos fijos en memoria, para tests sin
/// Firebase. Hereda `watchDiagnosesFor` de la clase real.
class FakeRecordsService extends RecordsService {
  final accounts = {for (final u in FakeAdminService().users) u.uid: u};

  final patients = <String, PatientRecord>{
    'p1': PatientRecord(
      fechaNacimiento: DateTime(1998, 3, 14),
      sexo: Sex.masculino,
      telefono: '0981 234 567',
      direccion: 'San Lorenzo, PY',
      registroSenadis: 'SEN-2024-00871',
      contactoEmergencia: 'María González',
      telefonoEmergencia: '0982 111 222',
      estadoFuncional: FunctionalState(
        movilidadCervical: Mobility.parcial,
        movilidadMiofacial: Mobility.conservada,
        controlCefalico: HeadControl.estable,
        nivelAsistencia: Assistance.parcial,
        puedeClipDerecho: false,
        observaciones:
            'Mejor control del cursor a la mañana; se fatiga después de 40 '
            'minutos de uso continuo.',
        fechaEvaluacion: DateTime(2026, 10, 2),
        nombreEvaluador: 'María González',
      ),
    ),
  };

  final caregivers = <String, CaregiverRecord>{
    'c1': const CaregiverRecord(
      sexo: Sex.femenino,
      telefono: '0982 111 222',
      correoAlternativo: 'maria.alt@correo.com',
      ocupacion: 'Docente',
    ),
  };

  final diagnoses = <Diagnosis>[
    Diagnosis(
      id: 'd1',
      idPaciente: 'p1',
      tipo: DiagnosisType.principal,
      diagnostico: 'Parálisis cerebral espástica',
      descripcion:
          'Afecta el control motor fino de manos y cuello; dificulta '
          'sostener un mouse convencional.',
      fechaDiagnostico: DateTime(2022, 3, 14),
      profesional: 'Dr. Marcos Insfrán',
      institucion: 'Hospital de Clínicas',
      especialidad: 'Neurología',
      nombreRegistrador: 'María González',
      fechaRegistro: DateTime(2026, 9, 1),
      nombreModificador: 'María González',
      fechaModificacion: DateTime(2026, 9, 3),
      adjuntos: 1,
    ),
    Diagnosis(
      id: 'd2',
      idPaciente: 'p1',
      tipo: DiagnosisType.secundario,
      diagnostico: 'Contractura cervical crónica',
      fechaDiagnostico: DateTime(2023, 8, 2),
      nombreRegistrador: 'María González',
    ),
    Diagnosis(
      id: 'd3',
      idPaciente: 'p1',
      tipo: DiagnosisType.antecedente,
      diagnostico: 'Cirugía de columna cervical',
      fechaDiagnostico: DateTime(2019, 11, 27),
      esActual: false,
    ),
    const Diagnosis(
      id: 'd4',
      idPaciente: 'p1',
      tipo: DiagnosisType.secundario,
      diagnostico: 'Cargado por error',
      esActual: false,
      anulado: true,
      nombreModificador: 'María González',
    ),
  ];

  /// Acciones recibidas, para verificarlas en los tests.
  final calls = <String>[];

  // Los tests no tienen sesión: con uid vacío se usa el paciente p1.
  String _patient(String uid) => uid.isEmpty ? 'p1' : uid;

  @override
  Stream<ManagedUser> watchAccount(String uid) => Stream.value(
    accounts[_patient(uid)] ??
        ManagedUser(uid: uid, email: '', role: UserRole.paciente),
  );

  @override
  Stream<PatientRecord> watchPatient(String uid) =>
      Stream.value(patients[_patient(uid)] ?? const PatientRecord());

  @override
  Stream<Map<String, PatientRecord>> watchAllPatients() =>
      Stream.value(patients);

  @override
  Future<void> savePatient(
    String uid,
    PatientRecord record, {
    required String nombre,
    bool selfEdit = false,
  }) async {
    calls.add('savePatient $uid selfEdit=$selfEdit tel=${record.telefono}');
    patients[uid] = record;
  }

  @override
  Future<void> saveFunctionalState(
    String uid,
    FunctionalState state, {
    required String nombre,
  }) async {
    calls.add(
      'saveFunctionalState $uid cervical=${state.movilidadCervical?.id}',
    );
  }

  @override
  Stream<CaregiverRecord> watchCaregiver(String uid) => Stream.value(
    caregivers[uid.isEmpty ? 'c1' : uid] ?? const CaregiverRecord(),
  );

  @override
  Future<void> saveCaregiver(
    String uid,
    CaregiverRecord record, {
    required String nombre,
  }) async {
    calls.add('saveCaregiver $uid');
    caregivers[uid] = record;
  }

  List<Diagnosis> _sorted(Iterable<Diagnosis> list) =>
      list.toList()..sort(Diagnosis.compare);

  @override
  Stream<List<Diagnosis>> watchDiagnoses(String patientUid) => Stream.value(
    _sorted(diagnoses.where((d) => d.idPaciente == _patient(patientUid))),
  );

  @override
  Stream<List<Diagnosis>> watchAllDiagnoses() =>
      Stream.value(_sorted(diagnoses));

  @override
  Future<String> addDiagnosis(
    Diagnosis diagnosis, {
    required String paciente,
  }) async {
    calls.add(
      'add ${diagnosis.idPaciente} ${diagnosis.tipo.id} '
      '${diagnosis.diagnostico.trim()} actual=${diagnosis.esActual}',
    );
    return 'nuevo';
  }

  @override
  Future<void> updateDiagnosis(
    Diagnosis before,
    Diagnosis after, {
    required String paciente,
  }) async {
    calls.add('update ${before.id} ${after.diagnostico.trim()}');
  }

  @override
  Future<void> annulDiagnosis(
    Diagnosis diagnosis, {
    required String paciente,
  }) async {
    calls.add('annul ${diagnosis.id}');
  }

  /// La actual (la de la ficha) y una anterior.
  late final evaluations = <FunctionalState>[
    patients['p1']!.estadoFuncional!,
    FunctionalState(
      movilidadCervical: Mobility.noConservada,
      movilidadMiofacial: Mobility.conservada,
      controlCefalico: HeadControl.parcial,
      nivelAsistencia: Assistance.dependiente,
      fechaEvaluacion: DateTime(2026, 4, 20),
      nombreEvaluador: 'Carlos Herrera Villalba',
    ),
  ];

  @override
  Stream<List<FunctionalState>> watchEvaluations(String patientUid) =>
      Stream.value(_patient(patientUid) == 'p1' ? evaluations : const []);
}
