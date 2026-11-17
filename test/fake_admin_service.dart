import 'package:headmouse_pro/services/admin_service.dart';
import 'package:headmouse_pro/services/auth_service.dart';

/// AdminService con datos fijos en memoria, para tests sin Firebase.
class FakeAdminService implements AdminService {
  FakeAdminService() {
    final now = DateTime.now();
    users = [
      ManagedUser(
        uid: 'p1',
        email: 'juan.paredes@correo.com',
        role: UserRole.paciente,
        nombres: 'Juan',
        apellidos: 'Paredes',
        documento: '4567890',
        fechaRegistro: now.subtract(const Duration(days: 40)),
        ultimoIngreso: now,
      ),
      const ManagedUser(
        uid: 'p2',
        email: 'lucia.fernandez@correo.com',
        role: UserRole.paciente,
        nombres: 'Lucía',
        apellidos: 'Fernández Benítez de la Cruz',
        active: false,
      ),
      const ManagedUser(
        uid: 'c1',
        email: 'maria.gonzalez@correo.com',
        role: UserRole.cuidador,
        nombres: 'María',
        apellidos: 'González',
      ),
      const ManagedUser(uid: 'x1', email: 'sinrol@correo.com', role: null),
    ];
    log = [
      AuditEvent(
        category: 'Login',
        actor: 'María González',
        time: now,
        action: 'Inició sesión',
        metaLeft: 'Rol: Cuidador / tutor',
        metaRight: 'Android',
      ),
      AuditEvent(
        category: 'Cambios de datos',
        actor: 'Administrador del sistema',
        time: now.subtract(const Duration(days: 1)),
        action: 'Dio de baja la cuenta de Lucía Fernández Benítez de la Cruz',
        metaLeft: 'Rol: Administrador',
        metaRight: 'Rol: Paciente',
      ),
      AuditEvent(
        category: 'Login',
        actor: 'Usuario',
        time: now.subtract(const Duration(days: 9)),
        action: 'Intento fallido de inicio de sesión',
        failed: true,
      ),
    ];
  }

  late List<ManagedUser> users;
  late List<AuditEvent> log;

  /// Acciones recibidas, para verificarlas en los tests.
  final calls = <String>[];

  @override
  Stream<List<ManagedUser>> watchUsers() => Stream.value(users);

  @override
  Stream<List<AuditEvent>> watchAuditLog({int limit = 100}) =>
      Stream.value(log);

  @override
  Future<ManagedUser> createUser(NewUser data) async => ManagedUser(
    uid: 'nuevo',
    email: data.email,
    role: data.role,
    nombres: data.nombres,
    apellidos: data.apellidos,
    documento: data.documento,
  );

  @override
  Future<void> updateUser(
    ManagedUser user, {
    required String nombres,
    required String apellidos,
    required String documento,
  }) async {}

  @override
  Future<void> setRole(ManagedUser user, UserRole role) async =>
      calls.add('rol ${user.uid} ${role.id}');

  @override
  Future<void> setActive(ManagedUser user, bool active) async =>
      calls.add('estado ${user.uid} $active');
}
