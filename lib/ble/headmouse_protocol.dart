// Protocolo BLE del HeadMouse Pro (ESP32-C3 SuperMini + MPU6050).
//
// Refleja el firmware del ESP32: UUIDs y formato de bytes de cada
// característica. Si cambia el firmware, se cambia acá y nada más. Este archivo no depende del plugin de Bluetooth para poder
// probarlo con tests comunes.

import 'dart:convert';
import 'dart:typed_data';

/// Nombre con el que se anuncia el dispositivo (constructor de
/// `HeadMoxBleMouse` en el firmware).
const headMouseAdvName = 'HeadMouse Pro';

/// UUIDs del servicio personalizado para Flutter.
abstract final class HeadMouseUuids {
  static const service = 'a1fa9db1-821e-4b8b-bc99-ac78ef017e1e';

  /// 1 byte: porcentaje 0-100. READ | NOTIFY (cada 30 s).
  static const battery = '1e0d5187-8d4d-41a9-a72d-47634f08e598';

  /// 4 bytes: AX, AY como int16 little-endian. READ | NOTIFY (cada 100 ms).
  static const sensorRaw = 'c15d05d6-0cdf-48ce-a00f-145591116dfa';

  /// 8 bytes: AX, AY calibrados como int32 little-endian. READ | NOTIFY.
  static const sensorCalibrado = 'a1c7b6d8-8afc-492b-8a8c-0ac2a9eda796';

  /// 1 byte: 0 error, 1 listo, 2 calibrando. READ | NOTIFY.
  static const sensorStatus = '839327bd-a162-4672-93b6-4994b77cd80d';

  /// Texto ASCII "AA:BB:CC:DD:EE:FF". READ.
  static const mac = 'e62a626a-574e-4991-b4e3-f74d4b13f135';

  /// 5 bytes [umbral, velocidad, delay, boton1, boton2]. READ | WRITE | NOTIFY.
  /// El ESP32 IGNORA la escritura si antes no se activó el modo configuración.
  static const config = 'd49e7f5f-6099-4ede-ad3a-5d2c9adf8572';

  /// Escribir [1] pide una calibración manual. WRITE.
  static const calibrate = '2a2a0501-645d-4a4e-9d8f-5eb88d3095ba';

  /// [1] entra y [0] sale del modo configuración. READ | WRITE | NOTIFY.
  static const configMode = 'a8dbb497-199e-4a57-a8a9-be03415baf36';
}

/// Acciones que se pueden asignar a cada pulsador (constantes de BleMouse).
enum ButtonAction {
  mouseLeft(1, 'MOUSE_LEFT', 'Clic izquierdo'),
  mouseRight(2, 'MOUSE_RIGHT', 'Clic derecho'),
  mouseBack(8, 'MOUSE_BACK', 'Atrás'),
  mouseForward(16, 'MOUSE_FORWARD', 'Adelante');

  const ButtonAction(this.code, this.firmwareName, this.label);

  /// Valor que viaja por BLE y que guarda el ESP32.
  final int code;

  /// Nombre de la constante en el firmware (y en Firebase: `boton1Nombre`).
  final String firmwareName;

  /// Texto para mostrar al usuario.
  final String label;

  static ButtonAction? fromCode(int code) {
    for (final action in values) {
      if (action.code == code) return action;
    }
    return null;
  }
}

/// Estado del MPU6050 que informa el ESP32.
enum SensorStatus {
  error(0, 'Error'),
  ready(1, 'Listo'),
  calibrating(2, 'Calibrando');

  const SensorStatus(this.code, this.label);

  final int code;
  final String label;

  static SensorStatus? fromCode(int code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return null;
  }
}

/// Rango permitido de un parámetro. Coincide con la validación del ESP32:
/// si se manda algo fuera de rango, el firmware lo descarta en silencio.
class ParamRange {
  const ParamRange(this.min, this.max, this.defaultValue);

  final int min;
  final int max;
  final int defaultValue;

  int clamp(int value) => value.clamp(min, max);
  bool contains(int value) => value >= min && value <= max;
}

/// Configuración que vive en el ESP32 (y que se respalda en Firebase).
class DeviceConfig {
  const DeviceConfig({
    required this.umbralMovimiento,
    required this.velocidadMax,
    required this.delayMovimiento,
    required this.boton1,
    required this.boton2,
  });

  /// 3 = más sensible, 6 = más estable.
  static const umbralRange = ParamRange(3, 6, 3);

  /// Desplazamiento máximo del cursor por actualización.
  static const velocidadRange = ParamRange(1, 20, 20);

  /// Milisegundos entre actualizaciones (suavizado).
  static const delayRange = ParamRange(7, 16, 13);

  /// Valores de fábrica del firmware.
  static const defaults = DeviceConfig(
    umbralMovimiento: 3,
    velocidadMax: 20,
    delayMovimiento: 13,
    boton1: ButtonAction.mouseLeft,
    boton2: ButtonAction.mouseRight,
  );

  final int umbralMovimiento;
  final int velocidadMax;
  final int delayMovimiento;
  final ButtonAction boton1;
  final ButtonAction boton2;

  /// Bytes que espera `ConfigCallbacks::onWrite`.
  Uint8List toBytes() => Uint8List.fromList([
    umbralRange.clamp(umbralMovimiento),
    velocidadRange.clamp(velocidadMax),
    delayRange.clamp(delayMovimiento),
    boton1.code,
    boton2.code,
  ]);

  /// Decodifica lo que publica `actualizarBLEConfiguracion()`.
  /// Devuelve null si el paquete no tiene el formato esperado.
  static DeviceConfig? fromBytes(List<int> bytes) {
    if (bytes.length < 5) return null;
    final b1 = ButtonAction.fromCode(bytes[3]);
    final b2 = ButtonAction.fromCode(bytes[4]);
    if (b1 == null || b2 == null) return null;
    return DeviceConfig(
      umbralMovimiento: bytes[0],
      velocidadMax: bytes[1],
      delayMovimiento: bytes[2],
      boton1: b1,
      boton2: b2,
    );
  }

  /// Formato recomendado para Firebase en "Datos para la app de flutter".
  Map<String, Object> toFirestore() => {
    'umbralMovimiento': umbralMovimiento,
    'velocidadMax': velocidadMax,
    'delayMovimiento': delayMovimiento,
    'boton1': boton1.code,
    'boton1Nombre': boton1.firmwareName,
    'boton2': boton2.code,
    'boton2Nombre': boton2.firmwareName,
  };

  DeviceConfig copyWith({
    int? umbralMovimiento,
    int? velocidadMax,
    int? delayMovimiento,
    ButtonAction? boton1,
    ButtonAction? boton2,
  }) => DeviceConfig(
    umbralMovimiento: umbralMovimiento ?? this.umbralMovimiento,
    velocidadMax: velocidadMax ?? this.velocidadMax,
    delayMovimiento: delayMovimiento ?? this.delayMovimiento,
    boton1: boton1 ?? this.boton1,
    boton2: boton2 ?? this.boton2,
  );

  @override
  bool operator ==(Object other) =>
      other is DeviceConfig &&
      other.umbralMovimiento == umbralMovimiento &&
      other.velocidadMax == velocidadMax &&
      other.delayMovimiento == delayMovimiento &&
      other.boton1 == boton1 &&
      other.boton2 == boton2;

  @override
  int get hashCode => Object.hash(
    umbralMovimiento,
    velocidadMax,
    delayMovimiento,
    boton1,
    boton2,
  );

  @override
  String toString() =>
      'DeviceConfig(umbral: $umbralMovimiento, velocidad: $velocidadMax, '
      'delay: $delayMovimiento, boton1: ${boton1.firmwareName}, '
      'boton2: ${boton2.firmwareName})';
}

/// Par de lecturas del acelerómetro (eje X e Y).
class AxisSample {
  const AxisSample(this.ax, this.ay);

  final int ax;
  final int ay;

  AxisSample operator -(AxisSample other) =>
      AxisSample(ax - other.ax, ay - other.ay);

  @override
  bool operator ==(Object other) =>
      other is AxisSample && other.ax == ax && other.ay == ay;

  @override
  int get hashCode => Object.hash(ax, ay);

  @override
  String toString() => 'AxisSample($ax, $ay)';
}

/// Decodificadores de cada característica de lectura.
abstract final class HeadMouseCodec {
  static int? battery(List<int> bytes) =>
      bytes.isEmpty ? null : bytes[0].clamp(0, 100);

  /// AX y AY originales: dos int16 little-endian (ESP32 es little-endian).
  static AxisSample? sensorRaw(List<int> bytes) {
    if (bytes.length < 4) return null;
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    return AxisSample(
      data.getInt16(0, Endian.little),
      data.getInt16(2, Endian.little),
    );
  }

  /// AX y AY calibrados: dos int32 little-endian.
  static AxisSample? sensorCalibrado(List<int> bytes) {
    if (bytes.length < 8) return null;
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    return AxisSample(
      data.getInt32(0, Endian.little),
      data.getInt32(4, Endian.little),
    );
  }

  static SensorStatus? sensorStatus(List<int> bytes) =>
      bytes.isEmpty ? null : SensorStatus.fromCode(bytes[0]);

  static String? mac(List<int> bytes) {
    final text = ascii
        .decode(bytes.where((b) => b != 0).toList(), allowInvalid: true)
        .trim();
    return text.isEmpty ? null : text.toUpperCase();
  }

  static bool? configMode(List<int> bytes) =>
      bytes.isEmpty ? null : bytes[0] == 1;

  static const calibrateCommand = [1];
  static List<int> configModeCommand(bool enabled) => [enabled ? 1 : 0];
}
