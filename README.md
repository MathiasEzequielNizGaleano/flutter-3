# HeadMouse Pro

Aplicación móvil del sistema **HeadMouse Pro**, un mouse controlado con
movimientos de la cabeza para personas con movilidad reducida en los miembros
superiores.

El dispositivo (ESP32-C3 + MPU6050 + dos pulsadores) funciona como mouse
Bluetooth para la computadora. Esta aplicación se conecta a él por Bluetooth LE
para configurarlo y calibrarlo, y gestiona en Firebase la información clínica
y administrativa de pacientes, cuidadores y equipos.

## Funcionalidades

**Paciente**
- Conexión con el HeadMouse, ajuste de umbral, velocidad, retardo y acción de
  cada pulsador.
- Calibración guiada del sensor e historial de configuraciones y calibraciones.
- Ficha personal, cuidadores asignados e historial de ingresos.
- Plan Premium y comprobantes de pago.

**Cuidador**
- Pacientes vinculados con permisos individuales (ver, editar, configurar,
  calibrar).
- Ficha clínica, estado funcional, diagnósticos con documentación de respaldo
  (PDF, JPG, PNG) e historial de evaluaciones.
- Alta de pacientes nuevos.

**Administrador**
- Altas, bajas y roles de cuentas; vínculos cuidador-paciente.
- Registro de dispositivos por MAC y configuración de fábrica remota.
- Tarifas, planes y confirmación de pagos.
- Auditoría de cambios, historial de accesos y reportes de pacientes,
  dispositivos y calibraciones.

**Seguridad**
- Verificación en dos pasos, cierre de sesión en otros dispositivos y cierre
  automático al dar de baja una cuenta.
- Reglas de Firestore con control de acceso por rol y por vínculo.
- Toda modificación se registra en `auditoria` en la misma operación; los
  datos no se borran, se anulan o desactivan.

## Arquitectura

| Capa | Tecnología |
| --- | --- |
| Interfaz | Flutter 3 (Material 3), tema claro y oscuro |
| Bluetooth | `flutter_blue_plus` |
| Autenticación | Firebase Authentication (correo y contraseña) |
| Datos | Cloud Firestore (`southamerica-east1`) |
| Seguridad | `firestore.rules`, `firestore.indexes.json` |

El proyecto funciona en el plan gratuito de Firebase (Spark), sin Cloud
Functions ni Cloud Storage:

- Los adjuntos de los diagnósticos se guardan en Firestore divididos en partes
  de hasta 700 KB (máximo 5 MB por archivo).
- El envío del código de verificación y la pasarela de pagos están simulados;
  el resto del flujo (planes, vencimientos, comprobantes, auditoría) es real.
- El cierre de sesiones remotas lo resuelve cada aplicación escuchando su
  documento en `usuarios`.

### Estructura

```
lib/
  ble/          Protocolo y conexión Bluetooth LE con el dispositivo
  l10n/         Textos de la interfaz
  navigation/   Barras de navegación por rol y control de sesión
  screens/      Pantallas
  services/     Acceso a Firebase (un servicio por dominio)
  theme/        Colores, tipografías y estilos
  utils/        Validaciones, fechas y utilidades
  widgets/      Componentes reutilizables
test/           Pruebas unitarias y de widgets, con servicios en memoria
```

Cada servicio expone una instancia reemplazable (`Service.instance`), lo que
permite probar las pantallas sin Firebase.

### Protocolo BLE

Servicio `a1fa9db1-821e-4b8b-bc99-ac78ef017e1e`:

| Característica | Contenido | Propiedades |
| --- | --- | --- |
| Batería | 1 byte, porcentaje | READ, NOTIFY |
| Sensor | AX, AY en crudo (`int16` LE) | READ, NOTIFY |
| Sensor calibrado | AX, AY (`int32` LE) | READ, NOTIFY |
| Estado del sensor | 0 error, 1 listo, 2 calibrando | READ, NOTIFY |
| MAC | Texto `AA:BB:CC:DD:EE:FF` | READ |
| Configuración | umbral, velocidad, retardo, botón 1, botón 2 | READ, WRITE, NOTIFY |
| Calibrar | escribir `1` | WRITE |
| Modo configuración | `1` entra, `0` sale | READ, WRITE, NOTIFY |

Los UUID de cada característica están en `lib/ble/headmouse_protocol.dart`.

## Puesta en marcha

Requisitos: Flutter 3.44 o superior, Android 7.0 o superior con Bluetooth LE.

```bash
flutter pub get
flutter run
```

Para usar otro proyecto de Firebase:

```bash
flutterfire configure
firebase deploy --only firestore:rules,firestore:indexes
```

Las cuentas de administrador se asignan desde la consola de Firebase
(`usuarios/{uid}.rol = "admin"`); pacientes y cuidadores se registran desde la
aplicación.

## Pruebas

```bash
flutter analyze
flutter test
```

## Compilación

```bash
flutter build apk --release
```

La versión de release se firma con la clave de depuración. Para publicar en
Play Store hay que configurar una clave propia en `android/app/build.gradle.kts`.
