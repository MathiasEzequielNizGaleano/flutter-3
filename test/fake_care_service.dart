import 'package:headmouse_pro/services/admin_service.dart';
import 'package:headmouse_pro/services/care_service.dart';

/// CareService con vínculos fijos en memoria, para tests sin Firebase.
class FakeCareService implements CareService {
  final links = <CareAssignment>[
    CareAssignment(
      idCuidador: 'c1',
      idPaciente: 'p1',
      nombreCuidador: 'María González',
      nombrePaciente: 'Juan Paredes',
      parentesco: 'Madre',
      responsabilidad: Responsibility.principal,
      permisos: const CarePermissions(editarDatos: true),
      fechaAsignacion: DateTime(2026, 3, 4),
    ),
    const CareAssignment(
      idCuidador: 'c2',
      idPaciente: 'p1',
      nombreCuidador: 'Carlos Herrera Villalba',
      nombrePaciente: 'Juan Paredes',
      parentesco: 'Profesional de salud',
      responsabilidad: Responsibility.secundario,
      permisos: CarePermissions(calibrar: false),
    ),
    const CareAssignment(
      idCuidador: 'c3',
      idPaciente: 'p1',
      nombreCuidador: 'Ana Torres',
      nombrePaciente: 'Juan Paredes',
      parentesco: 'Acompañante',
      responsabilidad: Responsibility.temporal,
      permisos: CarePermissions(),
      activo: false,
    ),
  ];

  /// Acciones recibidas, para verificarlas en los tests.
  final calls = <String>[];

  List<CareAssignment> _filter(
    bool Function(CareAssignment) test,
    bool includeEnded,
  ) => links.where((a) => test(a) && (includeEnded || a.activo)).toList();

  // Los tests no tienen sesión: con uid vacío se devuelven todos.
  @override
  Stream<List<CareAssignment>> watchForCaregiver(
    String uid, {
    bool includeEnded = false,
  }) => Stream.value(
    _filter((a) => uid.isEmpty || a.idCuidador == uid, includeEnded),
  );

  @override
  Stream<List<CareAssignment>> watchForPatient(
    String uid, {
    bool includeEnded = false,
  }) => Stream.value(
    _filter((a) => uid.isEmpty || a.idPaciente == uid, includeEnded),
  );

  @override
  Future<void> assign({
    required ManagedUser caregiver,
    required ManagedUser patient,
    required String parentesco,
    required Responsibility responsabilidad,
    required CarePermissions permisos,
  }) async => calls.add(
    'asignar ${caregiver.uid} ${patient.uid} $parentesco '
    '${responsabilidad.id} ${permisos.summary}',
  );

  @override
  Future<void> update(
    CareAssignment assignment, {
    required String parentesco,
    required Responsibility responsabilidad,
    required CarePermissions permisos,
  }) async => calls.add('editar ${assignment.id} ${permisos.summary}');

  @override
  Future<void> end(CareAssignment assignment) async =>
      calls.add('terminar ${assignment.id}');

  @override
  Future<ManagedUser> registerPatient(
    NewUser data, {
    required String parentesco,
    required Responsibility responsabilidad,
  }) async {
    calls.add(
      'registrar ${data.nombres} ${data.apellidos} ${data.email} '
      '${data.documento} $parentesco ${responsabilidad.id}',
    );
    return ManagedUser(
      uid: 'p-nuevo',
      email: data.email,
      role: data.role,
      nombres: data.nombres,
      apellidos: data.apellidos,
    );
  }
}
