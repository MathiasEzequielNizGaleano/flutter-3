// Verifica que la app arma y lee los bytes igual que el firmware del ESP32.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:headmouse_pro/ble/headmouse_protocol.dart';

/// Igual que el memcpy del firmware (ESP32 es little-endian).
List<int> int16le(List<int> values) {
  final data = ByteData(values.length * 2);
  for (var i = 0; i < values.length; i++) {
    data.setInt16(i * 2, values[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

List<int> int32le(List<int> values) {
  final data = ByteData(values.length * 4);
  for (var i = 0; i < values.length; i++) {
    data.setInt32(i * 4, values[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  group('CONFIG (5 bytes)', () {
    test(
      'ejemplo del documento: umbral 4, velocidad 15, delay 12, LEFT/BACK',
      () {
        const config = DeviceConfig(
          umbralMovimiento: 4,
          velocidadMax: 15,
          delayMovimiento: 12,
          boton1: ButtonAction.mouseLeft,
          boton2: ButtonAction.mouseBack,
        );
        expect(config.toBytes(), [4, 15, 12, 1, 8]);
        expect(DeviceConfig.fromBytes([4, 15, 12, 1, 8]), config);
      },
    );

    test('valores de fábrica iguales a los del firmware', () {
      expect(DeviceConfig.defaults.toBytes(), [3, 20, 13, 1, 2]);
    });

    test('nunca manda valores que el ESP32 descartaría', () {
      const fueraDeRango = DeviceConfig(
        umbralMovimiento: 0,
        velocidadMax: 25,
        delayMovimiento: 30,
        boton1: ButtonAction.mouseForward,
        boton2: ButtonAction.mouseRight,
      );
      expect(fueraDeRango.toBytes(), [3, 20, 16, 16, 2]);
    });

    test('paquete corto o botón inválido → null', () {
      expect(DeviceConfig.fromBytes([4, 15, 12, 1]), isNull);
      expect(DeviceConfig.fromBytes([4, 15, 12, 4, 2]), isNull);
    });

    test('formato Firebase con número y nombre del botón', () {
      expect(DeviceConfig.defaults.toFirestore(), {
        'umbralMovimiento': 3,
        'velocidadMax': 20,
        'delayMovimiento': 13,
        'boton1': 1,
        'boton1Nombre': 'MOUSE_LEFT',
        'boton2': 2,
        'boton2Nombre': 'MOUSE_RIGHT',
      });
    });
  });

  group('lecturas del sensor', () {
    test('RAW: dos int16 little-endian, con negativos', () {
      expect(
        HeadMouseCodec.sensorRaw(int16le([3245, -1520])),
        const AxisSample(3245, -1520),
      );
    });

    test('CALIBRADO: dos int32 little-endian', () {
      expect(
        HeadMouseCodec.sensorCalibrado(int32le([220, -105])),
        const AxisSample(220, -105),
      );
    });

    test('centro = raw - calibrado (ejemplo del documento)', () {
      const raw = AxisSample(3245, -1520);
      const calibrado = AxisSample(220, -105);
      expect(raw - calibrado, const AxisSample(3025, -1415));
    });

    test('paquetes incompletos → null', () {
      expect(HeadMouseCodec.sensorRaw([1, 2, 3]), isNull);
      expect(HeadMouseCodec.sensorCalibrado([1, 2, 3, 4]), isNull);
    });
  });

  group('otros', () {
    test('estado MPU6050', () {
      expect(HeadMouseCodec.sensorStatus([0]), SensorStatus.error);
      expect(HeadMouseCodec.sensorStatus([1]), SensorStatus.ready);
      expect(HeadMouseCodec.sensorStatus([2]), SensorStatus.calibrating);
      expect(HeadMouseCodec.sensorStatus([9]), isNull);
    });

    test('batería', () {
      expect(HeadMouseCodec.battery([85]), 85);
      expect(HeadMouseCodec.battery([]), isNull);
    });

    test('MAC en texto ASCII', () {
      expect(
        HeadMouseCodec.mac('aa:bb:cc:dd:ee:ff'.codeUnits),
        'AA:BB:CC:DD:EE:FF',
      );
      expect(HeadMouseCodec.mac([]), isNull);
    });

    test('comandos', () {
      expect(HeadMouseCodec.calibrateCommand, [1]);
      expect(HeadMouseCodec.configModeCommand(true), [1]);
      expect(HeadMouseCodec.configModeCommand(false), [0]);
      expect(HeadMouseCodec.configMode([1]), isTrue);
      expect(HeadMouseCodec.configMode([0]), isFalse);
    });
  });
}
