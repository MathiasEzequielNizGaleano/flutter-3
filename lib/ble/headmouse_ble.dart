// Conexión Bluetooth LE con el HeadMouse Pro.
//
// Un único objeto compartido por toda la app ([HeadMouseBle.instance]) que:
//  - busca el dispositivo,
//  - se conecta y se suscribe a batería, sensor, estado y configuración,
//  - entra/sale del modo configuración (pausa cursor y clics),
//  - escribe la configuración y pide la calibración manual,
//  - se desconecta para que la computadora pueda volver a usarlo como mouse.
//
// El ESP32 acepta una sola conexión a la vez: mientras el teléfono está
// conectado, la computadora no puede usarlo, y viceversa.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'headmouse_protocol.dart';

export 'headmouse_protocol.dart';

enum HeadMouseLink { disconnected, connecting, connected }

/// Un HeadMouse Pro encontrado durante la búsqueda.
class HeadMouseFound {
  const HeadMouseFound({
    required this.device,
    required this.name,
    this.rssi,
    this.alreadyConnected = false,
  });

  final BluetoothDevice device;
  final String name;
  final int? rssi;

  /// Ya estaba conectado al teléfono a nivel sistema (no anuncia, pero se
  /// puede usar igual).
  final bool alreadyConnected;

  /// En Android es la MAC; en iOS es un identificador propio del teléfono.
  String get id => device.remoteId.str;
}

/// Lecturas en vivo del MPU6050 (10 por segundo). No se guardan en Firebase.
class SensorTelemetry {
  const SensorTelemetry({this.raw, this.calibrado, this.centro});

  final AxisSample? raw;
  final AxisSample? calibrado;

  /// Centro de la última calibración. El firmware no lo envía; se deduce
  /// porque calibrado = raw - centro, entonces centro = raw - calibrado.
  final AxisSample? centro;
}

/// Una calibración manual hecha desde la app (tabla CALIBRACION).
class CalibrationRecord {
  const CalibrationRecord({
    required this.fecha,
    required this.motivo,
    required this.resultado,
    this.centro,
    this.mac,
  });

  final DateTime fecha;
  final String motivo;

  /// 'exitosa' o 'error'.
  final String resultado;
  final AxisSample? centro;
  final String? mac;

  Map<String, Object?> toFirestore() => {
    'tipoCalibracion': 'manual',
    'motivo': motivo,
    'estadoResultado': resultado,
    'centroAX': centro?.ax,
    'centroAY': centro?.ay,
    'macBLE': mac,
    'fechaCalibracion': fecha.toIso8601String(),
  };
}

/// Una configuración guardada en el dispositivo (tabla CONFIGURACION_DISPOSITIVO).
class ConfigRecord {
  const ConfigRecord({required this.config, required this.fecha, this.mac});

  final DeviceConfig config;
  final DateTime fecha;
  final String? mac;

  Map<String, Object?> toFirestore() => {
    'macBLE': mac,
    'configuracion': config.toFirestore(),
    'fechaConfiguracion': fecha.toIso8601String(),
  };
}

/// Error con un mensaje listo para mostrar al usuario.
class HeadMouseException implements Exception {
  const HeadMouseException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HeadMouseBle extends ChangeNotifier {
  HeadMouseBle._();

  static final instance = HeadMouseBle._();

  static final _serviceGuid = Guid(HeadMouseUuids.service);

  static const _notifyUuids = [
    HeadMouseUuids.battery,
    HeadMouseUuids.sensorRaw,
    HeadMouseUuids.sensorCalibrado,
    HeadMouseUuids.sensorStatus,
    HeadMouseUuids.config,
    HeadMouseUuids.configMode,
  ];

  static const _requiredUuids = [
    ..._notifyUuids,
    HeadMouseUuids.mac,
    HeadMouseUuids.calibrate,
  ];

  // ---------------------------------------------------------------- búsqueda

  bool _scanning = false;
  bool get scanning => _scanning;

  List<HeadMouseFound> _systemFound = const [];
  List<HeadMouseFound> _found = const [];
  List<HeadMouseFound> get found => _found;

  String? scanError;

  // ---------------------------------------------------------------- conexión

  HeadMouseLink link = HeadMouseLink.disconnected;
  bool get isConnected => link == HeadMouseLink.connected;

  BluetoothDevice? _device;
  String? deviceName;

  /// Mensaje si la conexión se cortó sin que el usuario la cerrara.
  String? disconnectMessage;

  // ------------------------------------------- datos del dispositivo (ESP32)
  // Se conservan después de desconectar como "último dato recibido".

  String? mac;
  int? battery;
  SensorStatus? sensorStatus;
  DeviceConfig? config;
  bool configMode = false;

  final telemetry = ValueNotifier<SensorTelemetry>(const SensorTelemetry());

  /// Historial de esta sesión. Cuando exista backend, se sube a Firebase.
  final List<CalibrationRecord> calibrations = [];
  final List<ConfigRecord> configHistory = [];

  DateTime? get lastCalibration =>
      calibrations.lastWhereOrNull((c) => c.resultado == 'exitosa')?.fecha;

  // ---------------------------------------------------------------- interno

  final Map<String, BluetoothCharacteristic> _chars = {};
  final _statusEvents = StreamController<SensorStatus>.broadcast();
  final _configEvents = StreamController<DeviceConfig>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanResultsSub;
  StreamSubscription<bool>? _isScanningSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  AxisSample? _raw;
  AxisSample? _cal;
  AxisSample? _centro;
  bool _userDisconnect = false;
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await FlutterBluePlus.setLogLevel(LogLevel.warning, color: false);
    } catch (_) {}
    _isScanningSub = FlutterBluePlus.isScanning.listen((value) {
      _scanning = value;
      notifyListeners();
    });
  }

  Future<void> _ensureBluetoothReady() async {
    await _init();
    bool supported;
    try {
      supported = await FlutterBluePlus.isSupported;
    } catch (_) {
      supported = false;
    }
    if (!supported) {
      throw const HeadMouseException(
        'Bluetooth LE no está disponible en este equipo.',
      );
    }
    // En web el navegador maneja el adaptador y los permisos.
    if (kIsWeb) return;

    var state = await FlutterBluePlus.adapterState
        .firstWhere((s) => s != BluetoothAdapterState.unknown)
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => FlutterBluePlus.adapterStateNow,
        );
    if (state == BluetoothAdapterState.off &&
        defaultTargetPlatform == TargetPlatform.android) {
      try {
        await FlutterBluePlus.turnOn(); // muestra el diálogo del sistema
        state = BluetoothAdapterState.on;
      } catch (_) {}
    }
    switch (state) {
      case BluetoothAdapterState.off:
      case BluetoothAdapterState.turningOff:
        throw const HeadMouseException('Activá el Bluetooth del teléfono.');
      case BluetoothAdapterState.unauthorized:
        throw const HeadMouseException(
          'La app no tiene permiso para usar Bluetooth. Habilitalo en los '
          'ajustes del teléfono.',
        );
      case BluetoothAdapterState.unavailable:
        throw const HeadMouseException('Este equipo no tiene Bluetooth.');
      default:
        return;
    }
  }

  // ======================================================== BUSCAR

  Future<void> startScan() async {
    scanError = null;
    _systemFound = const [];
    _found = const [];
    notifyListeners();
    try {
      await _ensureBluetoothReady();

      // Si el teléfono ya está conectado al HeadMouse a nivel sistema, el
      // dispositivo deja de anunciarse: lo agregamos igual a la lista.
      if (!kIsWeb) {
        try {
          // En Android el filtro por servicio se ignora y vuelven todos los
          // equipos BLE conectados (relojes, auriculares...): se filtra por
          // nombre, igual que en el escaneo.
          final devices = await FlutterBluePlus.systemDevices([_serviceGuid]);
          _systemFound = [
            for (final d in devices)
              if (_hasHeadMouseName(d.platformName))
                HeadMouseFound(
                  device: d,
                  name: _nameOf(d),
                  alreadyConnected: true,
                ),
          ];
          _found = _systemFound;
          notifyListeners();
        } catch (_) {}
      }

      await _scanResultsSub?.cancel();
      _scanResultsSub = FlutterBluePlus.onScanResults.listen(
        _onScanResults,
        onError: (Object e) {
          scanError = _friendly(e);
          notifyListeners();
        },
      );
      FlutterBluePlus.cancelWhenScanComplete(_scanResultsSub!);

      if (kIsWeb) {
        // Web Bluetooth abre el selector del navegador.
        await FlutterBluePlus.startScan(
          withNames: const [headMouseAdvName],
          webOptionalServices: [_serviceGuid],
        );
      } else {
        // Sin filtros en el escaneo: el nombre viaja en la respuesta de
        // escaneo y el UUID propio no siempre entra en el anuncio. Se filtra
        // acá abajo en _isHeadMouse.
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 15),
          androidCheckLocationServices: false,
        );
      }
    } catch (e) {
      scanError = _friendly(e);
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    if (!_initialized) return;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  void _onScanResults(List<ScanResult> results) {
    final systemIds = {for (final f in _systemFound) f.id};
    final scanned = [
      for (final r in results)
        if (_isHeadMouse(r) && !systemIds.contains(r.device.remoteId.str))
          HeadMouseFound(
            device: r.device,
            name: r.advertisementData.advName.isNotEmpty
                ? r.advertisementData.advName
                : _nameOf(r.device),
            rssi: r.rssi,
          ),
    ]..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
    _found = [..._systemFound, ...scanned];
    notifyListeners();
  }

  static bool _isHeadMouse(ScanResult r) {
    if (r.advertisementData.serviceUuids.contains(_serviceGuid)) return true;
    return _hasHeadMouseName(
      '${r.advertisementData.advName} ${r.device.platformName}',
    );
  }

  static bool _hasHeadMouseName(String name) =>
      name.toLowerCase().contains('headmouse');

  static BluetoothService? _configService(List<BluetoothService> services) =>
      services.firstWhereOrNull((s) => s.serviceUuid == _serviceGuid);

  static String _nameOf(BluetoothDevice d) {
    if (d.advName.isNotEmpty) return d.advName;
    if (d.platformName.isNotEmpty) return d.platformName;
    return headMouseAdvName;
  }

  // ======================================================== CONECTAR

  Future<void> connect(HeadMouseFound target) async {
    if (link != HeadMouseLink.disconnected) await disconnect();
    await _ensureBluetoothReady();
    await stopScan();

    final device = target.device;
    disconnectMessage = null;
    deviceName = target.name;

    for (var attempt = 1; ; attempt++) {
      _userDisconnect = false;
      _device = device;
      link = HeadMouseLink.connecting;
      notifyListeners();

      try {
        await _open(device);
        link = HeadMouseLink.connected;
        notifyListeners();
        return;
      } catch (e) {
        _userDisconnect = true;
        await _safeDisconnect(device);
        _handleDisconnected();
        // Android a veces corta con el error genérico 133 sin una causa
        // concreta; un segundo intento suele funcionar.
        if (attempt == 1 && _isAndroidGenericError(e)) {
          await Future<void>.delayed(const Duration(seconds: 1));
          continue;
        }
        throw HeadMouseException(_friendly(e, whileConnecting: true));
      }
    }
  }

  Future<void> _open(BluetoothDevice device) async {
    await device.connect(
      license: License.nonprofit, // proyecto educativo (tesis)
      timeout: const Duration(seconds: 15),
      mtu: null, // los paquetes del HeadMouse miden como mucho 8 bytes
    );
    _connSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _handleDisconnected();
      }
    });
    await _setupGatt(device);
  }

  /// Error 133 de Android (`ANDROID_SPECIFIC_ERROR` / `GATT_ERROR`).
  static bool _isAndroidGenericError(Object e) =>
      e is FlutterBluePlusException &&
      e.platform == ErrorPlatform.android &&
      e.code == 133;

  Future<void> _setupGatt(BluetoothDevice device) async {
    var service = _configService(await device.discoverServices());
    if (service == null &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      // Android recuerda la tabla GATT de los equipos vinculados: si el ESP32
      // se reprogramó después de vincularlo, sigue viendo los servicios del
      // firmware anterior. Se borra esa copia y se vuelve a leer.
      await device.clearGattCache();
      service = _configService(await device.discoverServices());
    }
    if (service == null) {
      throw const HeadMouseException(
        'Ese dispositivo no tiene el servicio de configuración del '
        'HeadMouse Pro. Revisá que tenga cargado el firmware correcto.',
      );
    }

    _chars.clear();
    for (final c in service.characteristics) {
      _chars[c.characteristicUuid.str128.toLowerCase()] = c;
    }
    final missing = _requiredUuids
        .where((u) => !_chars.containsKey(u))
        .toList();
    if (missing.isNotEmpty) {
      throw HeadMouseException(
        'El firmware no expone todas las características esperadas '
        '(${missing.length} faltantes). ¿La versión del firmware coincide?\n'
        'Faltan: ${missing.join(', ')}\n'
        'Recibidas: ${_chars.keys.join(', ')}',
      );
    }

    for (final uuid in _notifyUuids) {
      final c = _chars[uuid]!;
      final sub = c.onValueReceived.listen((value) => _onValue(uuid, value));
      device.cancelWhenDisconnected(sub);
      await c.setNotifyValue(true);
    }

    mac =
        HeadMouseCodec.mac(await _chars[HeadMouseUuids.mac]!.read()) ??
        (defaultTargetPlatform == TargetPlatform.android
            ? device.remoteId.str
            : mac);

    // Valores iniciales: cada read() también pasa por _onValue.
    for (final uuid in _notifyUuids) {
      _onValue(uuid, await _chars[uuid]!.read());
    }
  }

  void _onValue(String uuid, List<int> value) {
    switch (uuid) {
      case HeadMouseUuids.battery:
        final b = HeadMouseCodec.battery(value);
        if (b != null && b != battery) {
          battery = b;
          notifyListeners();
        }
      case HeadMouseUuids.sensorRaw:
        _raw = HeadMouseCodec.sensorRaw(value) ?? _raw;
        _publishTelemetry();
      case HeadMouseUuids.sensorCalibrado:
        _cal = HeadMouseCodec.sensorCalibrado(value) ?? _cal;
        // En cada ciclo el ESP32 manda primero el raw y después el
        // calibrado, así que el par es del mismo instante.
        if (_raw != null && _cal != null) _centro = _raw! - _cal!;
        _publishTelemetry();
      case HeadMouseUuids.sensorStatus:
        final s = HeadMouseCodec.sensorStatus(value);
        if (s == null) return;
        _statusEvents.add(s);
        if (s != sensorStatus) {
          sensorStatus = s;
          notifyListeners();
        }
      case HeadMouseUuids.config:
        final c = DeviceConfig.fromBytes(value);
        if (c == null) return;
        _configEvents.add(c);
        if (c != config) {
          config = c;
          notifyListeners();
        }
      case HeadMouseUuids.configMode:
        final m = HeadMouseCodec.configMode(value);
        if (m != null && m != configMode) {
          configMode = m;
          notifyListeners();
        }
    }
  }

  void _publishTelemetry() {
    telemetry.value = SensorTelemetry(
      raw: _raw,
      calibrado: _cal,
      centro: _centro,
    );
  }

  // ======================================================== ACCIONES

  /// true: pausa cursor y clics. false: los vuelve a habilitar.
  Future<void> setConfigMode(bool enabled) async {
    final c = _requireChar(HeadMouseUuids.configMode);
    try {
      await c.write(HeadMouseCodec.configModeCommand(enabled));
      final confirmed = HeadMouseCodec.configMode(await c.read());
      configMode = confirmed ?? enabled;
      notifyListeners();
    } catch (e) {
      throw HeadMouseException(_friendly(e));
    }
    if (configMode != enabled) {
      throw const HeadMouseException(
        'El HeadMouse no confirmó el cambio de modo configuración.',
      );
    }
  }

  /// Escribe la configuración y espera la confirmación del ESP32.
  ///
  /// El firmware descarta la escritura si no está en modo configuración, así
  /// que primero lo activa. La confirmación es la notificación que manda
  /// `actualizarBLEConfiguracion()` con los valores que realmente aplicó.
  Future<DeviceConfig> saveConfig(DeviceConfig desired) async {
    final c = _requireChar(HeadMouseUuids.config);
    if (!configMode) await setConfigMode(true);

    DeviceConfig? applied;
    try {
      final confirmation = _configEvents.stream.first
          .timeout(const Duration(seconds: 3))
          .then<DeviceConfig?>((v) => v, onError: (_) => null);
      await c.write(desired.toBytes());
      applied = await confirmation;
      applied ??= DeviceConfig.fromBytes(await c.read());
    } catch (e) {
      throw HeadMouseException(_friendly(e));
    }

    if (applied != null && applied != config) {
      config = applied;
      notifyListeners();
    }
    if (applied != desired) {
      throw HeadMouseException(
        'El HeadMouse no aplicó la configuración. Tiene: '
        '${applied ?? 'sin respuesta'}',
      );
    }
    configHistory.add(
      ConfigRecord(config: applied!, fecha: DateTime.now(), mac: mac),
    );
    return applied;
  }

  /// Guarda, reactiva cursor/clics y se desconecta para que la computadora
  /// pueda volver a conectarse al HeadMouse.
  Future<void> saveAndRelease(DeviceConfig desired) async {
    await saveConfig(desired);
    await setConfigMode(false);
    await disconnect();
  }

  /// Pide una calibración manual. El paciente tiene que quedarse quieto,
  /// mirando al centro, unos 2 segundos.
  Future<CalibrationRecord> calibrate({required String motivo}) async {
    final c = _requireChar(HeadMouseUuids.calibrate);

    // El ESP32 avisa estado 2 (calibrando) y al terminar 1 (listo). Además
    // deja el calibrado en (0,0), que sirve de señal si se pierde el "2".
    var started = false;
    final done = Completer<SensorStatus>();
    final statusSub = _statusEvents.stream.listen((s) {
      if (s == SensorStatus.calibrating) {
        started = true;
      } else if (s == SensorStatus.error ||
          (s == SensorStatus.ready && started)) {
        if (!done.isCompleted) done.complete(s);
      }
    });
    void onTelemetry() {
      if (telemetry.value.calibrado == const AxisSample(0, 0)) started = true;
    }

    telemetry.addListener(onTelemetry);

    try {
      await c.write(HeadMouseCodec.calibrateCommand);
      final result = await done.future.timeout(const Duration(seconds: 10));
      if (result == SensorStatus.error) {
        throw const HeadMouseException(
          'El MPU6050 no responde, no se pudo calibrar. Revisá el sensor.',
        );
      }
      // Esperar un par raw/calibrado nuevo para deducir el centro.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final record = CalibrationRecord(
        fecha: DateTime.now(),
        motivo: motivo,
        resultado: 'exitosa',
        centro: telemetry.value.centro,
        mac: mac,
      );
      calibrations.add(record);
      notifyListeners();
      return record;
    } catch (e) {
      calibrations.add(
        CalibrationRecord(
          fecha: DateTime.now(),
          motivo: motivo,
          resultado: 'error',
          mac: mac,
        ),
      );
      notifyListeners();
      if (e is TimeoutException) {
        throw const HeadMouseException(
          'El HeadMouse no confirmó la calibración a tiempo.',
        );
      }
      throw HeadMouseException(_friendly(e));
    } finally {
      await statusSub.cancel();
      telemetry.removeListener(onTelemetry);
    }
  }

  // ======================================================== DESCONECTAR

  /// Sale del modo configuración (si estaba activo) y libera el dispositivo.
  /// Al desconectarse, el ESP32 vuelve a anunciarse para la computadora.
  Future<void> disconnect() async {
    final device = _device;
    if (device == null) return;
    _userDisconnect = true;
    if (isConnected && configMode) {
      try {
        await setConfigMode(false);
      } catch (_) {}
    }
    await _safeDisconnect(device);
    _handleDisconnected();
  }

  Future<void> _safeDisconnect(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (_) {}
  }

  void _handleDisconnected() {
    if (_device == null) return;
    if (!_userDisconnect && link == HeadMouseLink.connected) {
      disconnectMessage = 'Se perdió la conexión con el HeadMouse Pro.';
    }
    _connSub?.cancel();
    _connSub = null;
    _device = null;
    _chars.clear();
    link = HeadMouseLink.disconnected;
    configMode = false; // el ESP32 también lo apaga al desconectarse
    sensorStatus = null;
    _raw = null;
    _cal = null;
    telemetry.value = SensorTelemetry(centro: _centro);
    notifyListeners();
  }

  // ======================================================== AYUDAS

  BluetoothCharacteristic _requireChar(String uuid) {
    final c = _chars[uuid];
    if (!isConnected || c == null) {
      throw const HeadMouseException('No hay un HeadMouse Pro conectado.');
    }
    return c;
  }

  static String _friendly(Object e, {bool whileConnecting = false}) {
    if (e is HeadMouseException) return e.message;
    if (e is TimeoutException) {
      return whileConnecting
          ? 'El HeadMouse no respondió. Verificá que esté encendido y que no '
                'esté conectado a la computadora.'
          : 'El HeadMouse no respondió a tiempo.';
    }
    if (_isAndroidGenericError(e)) {
      return 'No se pudo conectar con el HeadMouse. Apagá y prendé el '
          'Bluetooth del teléfono y probá de nuevo. Si sigue fallando, '
          'olvidá el HeadMouse Pro en Ajustes > Bluetooth y volvé a buscarlo.';
    }
    final text = e is FlutterBluePlusException
        ? (e.description ?? e.toString())
        : e.toString();
    final lower = text.toLowerCase();
    if (lower.contains('permission')) {
      return 'Se necesita el permiso de Bluetooth (dispositivos cercanos) '
          'para buscar el HeadMouse.';
    }
    if (lower.contains('turned on') || lower.contains('adapter')) {
      return 'Activá el Bluetooth del teléfono.';
    }
    if (lower.contains('location')) {
      return 'Activá la ubicación del teléfono para buscar dispositivos.';
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return whileConnecting
          ? 'El HeadMouse no respondió. Verificá que esté encendido y que no '
                'esté conectado a la computadora.'
          : 'El HeadMouse no respondió a tiempo.';
    }
    return 'Error de Bluetooth: $text';
  }

  @override
  void dispose() {
    _scanResultsSub?.cancel();
    _isScanningSub?.cancel();
    _connSub?.cancel();
    _statusEvents.close();
    _configEvents.close();
    telemetry.dispose();
    super.dispose();
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }

  T? lastWhereOrNull(bool Function(T) test) {
    T? result;
    for (final e in this) {
      if (test(e)) result = e;
    }
    return result;
  }
}
