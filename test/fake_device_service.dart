import 'package:headmouse_pro/ble/headmouse_ble.dart';
import 'package:headmouse_pro/services/admin_service.dart';
import 'package:headmouse_pro/services/device_service.dart';

/// DeviceService con equipos e historiales fijos en memoria, para tests sin
/// Firebase.
class FakeDeviceService extends DeviceService {
  final devices = <HeadMouseDevice>[
    HeadMouseDevice(
      id: 'AABBCCDDEEFF',
      codigo: '0231',
      mac: 'AA:BB:CC:DD:EE:FF',
      versionFirmware: '1.2.0',
      idPaciente: 'p1',
      nombrePaciente: 'Juan Paredes',
      bateria: 82,
      estadoSensor: 'Listo',
      ultimaConexion: DateTime(2026, 11, 12, 9, 12),
      ultimaCalibracion: DateTime(2026, 11, 12, 9, 15),
    ),
    const HeadMouseDevice(
      id: '101A2B3C4D5E',
      codigo: '0045',
      mac: '10:1A:2B:3C:4D:5E',
      activo: false,
    ),
  ];

  final configs = <ConfigEntry>[
    ConfigEntry(
      id: 'k3',
      idPaciente: 'p1',
      config: DeviceConfig.defaults,
      nombreAutor: 'Administrador',
      fecha: DateTime(2026, 11, 12, 10),
      pendiente: true,
      origen: ConfigOrigin.pedidoAdmin,
    ),
    ConfigEntry(
      id: 'k2',
      idPaciente: 'p1',
      config: const DeviceConfig(
        umbralMovimiento: 4,
        velocidadMax: 15,
        delayMovimiento: 12,
        boton1: ButtonAction.mouseLeft,
        boton2: ButtonAction.mouseBack,
      ),
      nombreAutor: 'María González',
      fecha: DateTime(2026, 11, 11, 18),
      vigente: true,
    ),
    ConfigEntry(
      id: 'k1',
      idPaciente: 'p1',
      config: DeviceConfig.defaults.copyWith(velocidadMax: 10),
      nombreAutor: 'Juan Paredes',
      fecha: DateTime(2026, 10, 2),
    ),
  ];

  final calibrations = <CalibrationEntry>[
    CalibrationEntry(
      id: 'c2',
      idPaciente: 'p1',
      motivo: 'Recolocación',
      exitosa: true,
      centroAX: 120,
      centroAY: -340,
      nombreAutor: 'María González',
      fecha: DateTime(2026, 11, 12, 9, 15),
      vigente: true,
    ),
    CalibrationEntry(
      id: 'c1',
      idPaciente: 'p1',
      motivo: 'Cursor descentrado',
      exitosa: false,
      nombreAutor: 'Juan Paredes',
      fecha: DateTime(2026, 11, 10, 8),
    ),
  ];

  /// Acciones recibidas, para verificarlas en los tests.
  final calls = <String>[];

  // Sin sesión en los tests: con uid vacío se usa el paciente p1.
  String _patient(String uid) => uid.isEmpty ? 'p1' : uid;

  @override
  Stream<List<HeadMouseDevice>> watchDevices() => Stream.value(devices);

  @override
  Future<HeadMouseDevice?> findDevice(String mac) async {
    for (final d in devices) {
      if (d.id == deviceIdFor(mac)) return d;
    }
    return null;
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
    calls.add(
      '${before == null ? 'alta' : 'editar'} $codigo ${formatMac(mac)} '
      '${paciente?.uid ?? 'sin paciente'} activo=$activo',
    );
  }

  @override
  Future<void> requestFactoryReset(HeadMouseDevice device) async {
    calls.add('restablecer ${device.id}');
  }

  @override
  Future<void> checkIn(
    String mac, {
    required bool connected,
    int? battery,
    SensorStatus? sensor,
  }) async {
    calls.add('checkIn $mac $connected');
  }

  @override
  Stream<List<ConfigEntry>> watchConfigs(String patientUid) => Stream.value([
    for (final c in configs)
      if (c.idPaciente == _patient(patientUid)) c,
  ]);

  @override
  Stream<List<CalibrationEntry>> watchCalibrations(String patientUid) =>
      Stream.value([
        for (final c in calibrations)
          if (c.idPaciente == _patient(patientUid)) c,
      ]);

  @override
  Stream<List<CalibrationEntry>> watchAllCalibrations() =>
      Stream.value(calibrations);

  @override
  Future<void> recordConfig(
    DevicePatient patient,
    DeviceConfig config, {
    String? mac,
    ConfigOrigin origen = ConfigOrigin.app,
  }) async {
    calls.add('config ${patient.uid} ${origen.id} $config');
  }

  @override
  Future<void> recordCalibration(
    DevicePatient patient,
    CalibrationRecord record,
  ) async {
    calls.add('calibracion ${patient.uid} ${record.resultado}');
  }
}
