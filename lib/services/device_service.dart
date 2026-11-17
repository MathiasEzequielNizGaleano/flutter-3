// Dispositivos HeadMouse Pro, configuraciones y calibraciones en Firestore.
//
// - DISPOSITIVO               → `dispositivos/{MAC sin ':'}`
// - CONFIGURACION_DISPOSITIVO → `pacientes/{uid}/configuraciones/{id}`
// - CALIBRACION               → `pacientes/{uid}/calibraciones/{id}`
//
// La conexión Bluetooth (`lib/ble/`) no sabe nada de Firebase: las pantallas
// llaman a este servicio después de guardar o calibrar, y [DeviceSync]
// registra cuándo se conectó cada equipo. Nada se borra: la configuración y
// la calibración actuales son las que tienen `vigente = true`.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../ble/headmouse_ble.dart';
import 'admin_service.dart';
import 'audit.dart';
import 'auth_service.dart';
import 'care_service.dart';

String _text(Object? value) => value is String ? value : '';
int? _int(Object? value) => value is int ? value : null;
DateTime? _time(Object? value) => value is Timestamp ? value.toDate() : null;

final _macPattern = RegExp(r'^([0-9A-Fa-f]{2}[:\-]?){5}[0-9A-Fa-f]{2}$');

bool isValidMac(String mac) => _macPattern.hasMatch(mac.trim());

/// Id del documento: la MAC sin separadores, en mayúsculas.
String deviceIdFor(String mac) =>
    mac.replaceAll(RegExp('[^0-9A-Fa-f]'), '').toUpperCase();

/// "aabbccddeeff" → "AA:BB:CC:DD:EE:FF".
String formatMac(String mac) {
  final id = deviceIdFor(mac);
  return [
    for (var i = 0; i + 1 < id.length; i += 2) id.substring(i, i + 2),
  ].join(':');
}

/// Un equipo registrado por el administrador (tabla DISPOSITIVO).
@immutable
class HeadMouseDevice {
  const HeadMouseDevice({
    required this.id,
    required this.codigo,
    required this.mac,
    this.versionFirmware = '',
    this.idPaciente,
    this.nombrePaciente = '',
    this.activo = true,
    this.conectado = false,
    this.estadoSensor = '',
    this.bateria,
    this.ultimaConexion,
    this.ultimaCalibracion,
    this.fechaAsignacion,
  });

  factory HeadMouseDevice.fromMap(String id, Map<String, dynamic> data) =>
      HeadMouseDevice(
        id: id,
        codigo: _text(data['codigoDispositivo']),
        mac: _text(data['macBLE']),
        versionFirmware: _text(data['versionFirmware']),
        idPaciente: data['idPaciente'] as String?,
        nombrePaciente: _text(data['nombrePaciente']),
        activo: data['activo'] != false,
        conectado: data['estadoConexion'] == 'conectado',
        estadoSensor: _text(data['estadoSensor']),
        bateria: _int(data['bateriaPorcentaje']),
        ultimaConexion: _time(data['ultimaConexion']),
        ultimaCalibracion: _time(data['ultimaCalibracion']),
        fechaAsignacion: _time(data['fechaAsignacion']),
      );

  final String id;
  final String codigo;
  final String mac;
  final String versionFirmware;

  /// `null` si todavía no se entregó a ningún paciente.
  final String? idPaciente;
  final String nombrePaciente;
  final bool activo;

  /// Último estado informado por la app (puede haber quedado viejo si la
  /// app se cerró de golpe; ver [ultimaConexion]).
  final bool conectado;
  final String estadoSensor;
  final int? bateria;
  final DateTime? ultimaConexion;
  final DateTime? ultimaCalibracion;
  final DateTime? fechaAsignacion;

  String get title =>
      codigo.isEmpty ? 'HeadMouse Pro' : 'HeadMouse Pro · #$codigo';
}

/// Paciente con el que se usa el HeadMouse en esta sesión y lo que puede
/// hacer quien lo maneja.
@immutable
class DevicePatient {
  const DevicePatient({
    required this.uid,
    required this.nombre,
    this.puedeConfigurar = true,
    this.puedeCalibrar = true,
  });

  factory DevicePatient.fromAssignment(CareAssignment a) => DevicePatient(
    uid: a.idPaciente,
    nombre: a.nombrePaciente,
    puedeConfigurar: a.permisos.configurar,
    puedeCalibrar: a.permisos.calibrar,
  );

  final String uid;
  final String nombre;
  final bool puedeConfigurar;
  final bool puedeCalibrar;
}

/// De dónde salió una configuración del historial.
enum ConfigOrigin {
  app('app', 'Guardada desde la app'),
  recuperada('recuperada', 'Recuperada del historial'),
  restablecida('restablecida', 'Valores de fábrica'),
  pedidoAdmin('pedido_admin', 'Restablecimiento pedido por el administrador');

  const ConfigOrigin(this.id, this.label);

  final String id;
  final String label;

  static ConfigOrigin fromId(Object? id) =>
      values.firstWhere((o) => o.id == id, orElse: () => ConfigOrigin.app);
}

/// Una entrada de CONFIGURACION_DISPOSITIVO.
@immutable
class ConfigEntry {
  const ConfigEntry({
    required this.id,
    required this.idPaciente,
    required this.config,
    this.mac = '',
    this.nombreAutor = '',
    this.fecha,
    this.vigente = false,
    this.pendiente = false,
    this.origen = ConfigOrigin.app,
  });

  /// `null` si los valores guardados no tienen el formato del firmware.
  static ConfigEntry? fromMap(String id, Map<String, dynamic> data) {
    final b1 = ButtonAction.fromCode(_int(data['boton1']) ?? -1);
    final b2 = ButtonAction.fromCode(_int(data['boton2']) ?? -1);
    final umbral = _int(data['umbralMovimiento']);
    final velocidad = _int(data['velocidadMax']);
    final delay = _int(data['delayMovimiento']);
    if (b1 == null ||
        b2 == null ||
        umbral == null ||
        velocidad == null ||
        delay == null) {
      return null;
    }
    return ConfigEntry(
      id: id,
      idPaciente: _text(data['idPaciente']),
      config: DeviceConfig(
        umbralMovimiento: umbral,
        velocidadMax: velocidad,
        delayMovimiento: delay,
        boton1: b1,
        boton2: b2,
      ),
      mac: _text(data['macBLE']),
      nombreAutor: _text(data['nombreConfigurador']),
      fecha: _time(data['fechaConfiguracion']),
      vigente: data['vigente'] == true,
      pendiente: data['pendiente'] == true,
      origen: ConfigOrigin.fromId(data['origen']),
    );
  }

  final String id;
  final String idPaciente;
  final DeviceConfig config;
  final String mac;
  final String nombreAutor;
  final DateTime? fecha;

  /// La que tiene el HeadMouse ahora.
  final bool vigente;

  /// Pedida por el administrador; se aplica la próxima vez que alguien se
  /// conecte al HeadMouse del paciente.
  final bool pendiente;
  final ConfigOrigin origen;

  /// "Umbral 4 · Velocidad 15 · Delay 12 ms"
  String get summary =>
      'Umbral ${config.umbralMovimiento} · Velocidad ${config.velocidadMax} '
      '· Delay ${config.delayMovimiento} ms';

  /// "Botón 1: Clic izquierdo · Botón 2: Atrás"
  String get buttons =>
      'Botón 1: ${config.boton1.label} · Botón 2: ${config.boton2.label}';
}

/// Una entrada de CALIBRACION.
@immutable
class CalibrationEntry {
  const CalibrationEntry({
    required this.id,
    required this.idPaciente,
    required this.motivo,
    required this.exitosa,
    this.centroAX,
    this.centroAY,
    this.mac = '',
    this.nombreAutor = '',
    this.fecha,
    this.vigente = false,
  });

  factory CalibrationEntry.fromMap(String id, Map<String, dynamic> data) =>
      CalibrationEntry(
        id: id,
        idPaciente: _text(data['idPaciente']),
        motivo: _text(data['motivo']),
        exitosa: data['estadoResultado'] == 'exitosa',
        centroAX: _int(data['centroAX']),
        centroAY: _int(data['centroAY']),
        mac: _text(data['macBLE']),
        nombreAutor: _text(data['nombreUsuario']),
        fecha: _time(data['fechaCalibracion']),
        vigente: data['vigente'] == true,
      );

  final String id;
  final String idPaciente;
  final String motivo;
  final bool exitosa;
  final int? centroAX;
  final int? centroAY;
  final String mac;
  final String nombreAutor;
  final DateTime? fecha;
  final bool vigente;

  String get center => centroAX == null || centroAY == null
      ? 'Centro sin datos'
      : 'Centro AX $centroAX · AY $centroAY';
}

/// Más nuevo primero; lo recién guardado (todavía sin fecha) arriba.
int newestFirst(DateTime? a, DateTime? b) {
  if (a == null || b == null) return a == null ? (b == null ? 0 : -1) : 1;
  return b.compareTo(a);
}

/// Punto de acceso de las pantallas. En los tests se reemplaza [instance].
abstract class DeviceService {
  static DeviceService instance = FirestoreDeviceService();

  static DevicePatient? _selected;
  static String? _selectedBy;

  /// El cuidador elige con qué paciente va a usar el HeadMouse.
  static void selectPatient(DevicePatient? patient) {
    _selected = patient;
    _selectedBy = AuthService.instance.current?.uid;
  }

  /// Con quién se está usando el HeadMouse: el paciente de la sesión, o el
  /// que eligió el cuidador. `null` si no hay ninguno (por ejemplo, sin
  /// sesión).
  static DevicePatient? get activePatient {
    final user = AuthService.instance.current;
    if (user == null) return null;
    if (user.role == UserRole.paciente) {
      return DevicePatient(uid: user.uid, nombre: user.fullName);
    }
    return _selectedBy == user.uid ? _selected : null;
  }

  /// Todos los equipos (solo administradores).
  Stream<List<HeadMouseDevice>> watchDevices();

  /// El equipo con esa MAC, o `null` si no está registrado o no es de un
  /// paciente al que el usuario tenga acceso.
  Future<HeadMouseDevice?> findDevice(String mac);

  /// Alta ([before] = null) o cambios de un equipo. Solo administradores.
  Future<void> saveDevice(
    HeadMouseDevice? before, {
    required String codigo,
    required String mac,
    required String versionFirmware,
    required ManagedUser? paciente,
    required bool activo,
  });

  /// Deja una configuración de fábrica pendiente para el paciente del
  /// equipo. Se aplica cuando alguien se conecte. Solo administradores.
  Future<void> requestFactoryReset(HeadMouseDevice device);

  /// Registra conexión, batería y estado del sensor. Si el equipo no está
  /// registrado no hace nada.
  Future<void> checkIn(
    String mac, {
    required bool connected,
    int? battery,
    SensorStatus? sensor,
  });

  Stream<List<ConfigEntry>> watchConfigs(String patientUid);

  Stream<List<CalibrationEntry>> watchCalibrations(String patientUid);

  /// Calibraciones de todos los pacientes (solo administradores, para los
  /// reportes).
  Stream<List<CalibrationEntry>> watchAllCalibrations();

  /// Guarda en el historial la configuración que se acaba de aplicar al
  /// HeadMouse. Pasa a ser la vigente.
  Future<void> recordConfig(
    DevicePatient patient,
    DeviceConfig config, {
    String? mac,
    ConfigOrigin origen = ConfigOrigin.app,
  });

  /// Guarda en el historial una calibración (exitosa o con error).
  Future<void> recordCalibration(
    DevicePatient patient,
    CalibrationRecord record,
  );
}

class FirestoreDeviceService extends DeviceService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String get _actorName => AuthService.instance.current?.fullName ?? 'Usuario';

  CollectionReference<Map<String, dynamic>> get _devices =>
      _db.collection('dispositivos');
  CollectionReference<Map<String, dynamic>> _configs(String uid) =>
      _db.collection('pacientes/$uid/configuraciones');
  CollectionReference<Map<String, dynamic>> _calibrations(String uid) =>
      _db.collection('pacientes/$uid/calibraciones');

  Stream<T> _guard<T>(Stream<T> Function() build) {
    try {
      return build();
    } catch (e) {
      return Stream.error(e);
    }
  }

  Future<T> _wrap<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw AuthException(AuthService.describeError(e));
    }
  }

  @override
  Stream<List<HeadMouseDevice>> watchDevices() => _guard(
    () => _devices.snapshots().map(
      (snap) =>
          [
            for (final doc in snap.docs)
              HeadMouseDevice.fromMap(doc.id, doc.data()),
          ]..sort((a, b) {
            if (a.activo != b.activo) return a.activo ? -1 : 1;
            return a.codigo.compareTo(b.codigo);
          }),
    ),
  );

  @override
  Future<HeadMouseDevice?> findDevice(String mac) async {
    try {
      final snap = await _devices.doc(deviceIdFor(mac)).get();
      final data = snap.data();
      return data == null ? null : HeadMouseDevice.fromMap(snap.id, data);
    } catch (_) {
      // Sin permiso: está registrado para otro paciente.
      return null;
    }
  }

  @override
  Future<void> saveDevice(
    HeadMouseDevice? before, {
    required String codigo,
    required String mac,
    required String versionFirmware,
    required ManagedUser? paciente,
    required bool activo,
  }) async {
    final id = before?.id ?? deviceIdFor(mac);
    final ref = _devices.doc(id);
    final reassigned = before?.idPaciente != paciente?.uid;
    final data = <String, Object?>{
      'codigoDispositivo': codigo.trim(),
      'nombreDispositivo': 'HeadMouse Pro',
      'versionFirmware': versionFirmware.trim(),
      'activo': activo,
      if (before == null || reassigned) ...{
        'idPaciente': paciente?.uid,
        'nombrePaciente': paciente?.fullName ?? '',
        'fechaAsignacion': paciente == null
            ? null
            : FieldValue.serverTimestamp(),
      },
    };
    await _wrap(() async {
      if (before == null) {
        if ((await ref.get()).exists) {
          throw const AuthException(
            'Ya hay un dispositivo registrado con esa MAC.',
          );
        }
        data.addAll({
          'macBLE': formatMac(mac),
          'estadoConexion': 'desconectado',
          'fechaRegistro': FieldValue.serverTimestamp(),
          'registradoPor': _uid,
        });
      }
      final batch = _db.batch();
      if (before == null) {
        batch.set(ref, data);
      } else {
        batch.update(ref, data);
      }
      final title = 'HeadMouse Pro · #${codigo.trim()}';
      batch.set(
        _db.collection('auditoria').doc(),
        auditRecord(
          accion: before == null
              ? 'Registró el dispositivo $title'
              : 'Modificó el dispositivo $title',
          detalle: [
            'MAC ${formatMac(mac)}',
            if (before == null || reassigned)
              paciente == null
                  ? 'Sin paciente asignado'
                  : 'Asignado a ${paciente.fullName}',
            if (before != null && before.activo != activo)
              activo ? 'Reactivado' : 'Desactivado',
          ].join(' · '),
          entidad: 'dispositivos',
          idEntidad: id,
        ),
      );
      await batch.commit();
    });
  }

  @override
  Future<void> requestFactoryReset(HeadMouseDevice device) async {
    final pid = device.idPaciente;
    if (pid == null) {
      throw const AuthException(
        'Asigná el dispositivo a un paciente antes de restablecerlo.',
      );
    }
    await _wrap(() async {
      final pending = await _configs(
        pid,
      ).where('pendiente', isEqualTo: true).get();
      final batch = _db.batch();
      for (final doc in pending.docs) {
        batch.update(doc.reference, {'pendiente': false});
      }
      batch.set(_configs(pid).doc(), {
        ..._configData(pid, DeviceConfig.defaults, device.mac),
        'vigente': false,
        'pendiente': true,
        'origen': ConfigOrigin.pedidoAdmin.id,
      });
      batch.set(
        _db.collection('auditoria').doc(),
        auditRecord(
          accion: 'Pidió restablecer ${device.title} a valores de fábrica',
          detalle: 'Paciente: ${device.nombrePaciente}',
          entidad: 'dispositivos',
          idEntidad: device.id,
        ),
      );
      await batch.commit();
    });
  }

  @override
  Future<void> checkIn(
    String mac, {
    required bool connected,
    int? battery,
    SensorStatus? sensor,
  }) async {
    try {
      await _devices.doc(deviceIdFor(mac)).update({
        'estadoConexion': connected ? 'conectado' : 'desconectado',
        'ultimaConexion': FieldValue.serverTimestamp(),
        'bateriaPorcentaje': ?battery,
        'estadoSensor': ?sensor?.label,
      });
    } catch (_) {
      // Equipo sin registrar, o de un paciente sin acceso: no se informa.
    }
  }

  @override
  Stream<List<ConfigEntry>> watchConfigs(String patientUid) => _guard(
    () => _configs(patientUid).snapshots().map((snap) {
      final list = <ConfigEntry>[
        for (final doc in snap.docs) ?ConfigEntry.fromMap(doc.id, doc.data()),
      ];
      return list..sort((a, b) => newestFirst(a.fecha, b.fecha));
    }),
  );

  @override
  Stream<List<CalibrationEntry>> watchCalibrations(String patientUid) => _guard(
    () => _calibrations(patientUid).snapshots().map(
      (snap) => [
        for (final doc in snap.docs)
          CalibrationEntry.fromMap(doc.id, doc.data()),
      ]..sort((a, b) => newestFirst(a.fecha, b.fecha)),
    ),
  );

  @override
  Stream<List<CalibrationEntry>> watchAllCalibrations() => _guard(
    () => _db.collectionGroup('calibraciones').snapshots().map(
      (snap) => [
        for (final doc in snap.docs)
          CalibrationEntry.fromMap(doc.id, doc.data()),
      ]..sort((a, b) => newestFirst(a.fecha, b.fecha)),
    ),
  );

  Map<String, Object?> _configData(String pid, DeviceConfig c, String? mac) => {
    'idPaciente': pid,
    'idDispositivo': mac == null ? null : deviceIdFor(mac),
    'macBLE': mac,
    ...c.toFirestore(),
    'configuradoPor': _uid,
    'nombreConfigurador': _actorName,
    'rolConfigurador': AuthService.instance.current?.role.id,
    'fechaConfiguracion': FieldValue.serverTimestamp(),
  };

  @override
  Future<void> recordConfig(
    DevicePatient patient,
    DeviceConfig config, {
    String? mac,
    ConfigOrigin origen = ConfigOrigin.app,
  }) async {
    await _wrap(() async {
      final configs = _configs(patient.uid);
      final current = await configs.where('vigente', isEqualTo: true).get();
      final pending = await configs.where('pendiente', isEqualTo: true).get();
      final batch = _db.batch();
      // Lo que tenía el equipo y cualquier pedido pendiente quedan como
      // historial: la nueva ya incluye la decisión de quien configuró.
      for (final doc in {...current.docs, ...pending.docs}) {
        batch.update(doc.reference, {'vigente': false, 'pendiente': false});
      }
      batch.set(configs.doc(), {
        ..._configData(patient.uid, config, mac),
        'vigente': true,
        'pendiente': false,
        'origen': origen.id,
      });
      await batch.commit();
    });
  }

  @override
  Future<void> recordCalibration(
    DevicePatient patient,
    CalibrationRecord record,
  ) async {
    final ok = record.resultado == 'exitosa';
    await _wrap(() async {
      final calibrations = _calibrations(patient.uid);
      final batch = _db.batch();
      if (ok) {
        final current = await calibrations
            .where('vigente', isEqualTo: true)
            .get();
        for (final doc in current.docs) {
          batch.update(doc.reference, {'vigente': false});
        }
      }
      batch.set(calibrations.doc(), {
        'idPaciente': patient.uid,
        'idDispositivo': record.mac == null ? null : deviceIdFor(record.mac!),
        'macBLE': record.mac,
        'idUsuario': _uid,
        'nombreUsuario': _actorName,
        'tipoCalibracion': 'manual',
        'centroAX': record.centro?.ax,
        'centroAY': record.centro?.ay,
        'estadoResultado': record.resultado,
        'motivo': record.motivo,
        'fechaCalibracion': FieldValue.serverTimestamp(),
        'vigente': ok,
      });
      await batch.commit();
    });
    // Para que el administrador vea la última calibración de cada equipo.
    final mac = record.mac;
    if (ok && mac != null) {
      try {
        await _devices.doc(deviceIdFor(mac)).update({
          'ultimaCalibracion': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }
}

/// Informa a Firestore cuándo se conecta y desconecta el HeadMouse, con la
/// batería y el estado del sensor. Se inicia una vez en `main()`.
class DeviceSync {
  DeviceSync._();

  static bool _started = false;
  static String? _reportedMac;

  static void start() {
    if (_started) return;
    _started = true;
    HeadMouseBle.instance.addListener(_onChange);
  }

  static void _onChange() {
    final ble = HeadMouseBle.instance;
    final mac = ble.mac;
    if (ble.isConnected && mac != null && _reportedMac == null) {
      _reportedMac = mac;
      DeviceService.instance.checkIn(
        mac,
        connected: true,
        battery: ble.battery,
        sensor: ble.sensorStatus,
      );
    } else if (!ble.isConnected && _reportedMac != null) {
      final reported = _reportedMac!;
      _reportedMac = null;
      DeviceService.instance.checkIn(
        reported,
        connected: false,
        battery: ble.battery,
        sensor: ble.sensorStatus,
      );
    }
  }
}
