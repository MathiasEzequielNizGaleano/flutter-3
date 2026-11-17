import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/policy_card.dart';

class _PolicySection {
  const _PolicySection(this.title, this.body);

  final String title;
  final String body;
}

const _policySections = [
  _PolicySection(
    '1. Objeto',
    'Esta Política explica cómo se tratan los datos personales en HeadMouse '
        'Pro, un sistema de asistencia que permite usar ordenadores sin las '
        'manos. Un dispositivo colocado en la cabeza controla el cursor, y '
        'una aplicación móvil permite configurarlo y darle seguimiento. El '
        'responsable de la aplicación y del tratamiento de los datos es '
        'Fernando Adrian Ortiz Sosa.',
  ),
  _PolicySection(
    '2. Datos que recopilamos',
    'Datos de cuenta: nombres, apellidos, documento de identidad, correo '
        'electrónico, rol y contraseña (almacenada cifrada). Datos de salud y '
        'funcionales: la información sobre tu condición motora necesaria para '
        'configurar y calibrar el dispositivo. Datos técnicos: identificador '
        'Bluetooth, nivel de batería, estado del sensor, parámetros de '
        'calibración y telemetría de movimiento. Datos de uso: registros de '
        'acceso y auditoría, y el historial de facturación del Plan Premium.',
  ),
  _PolicySection(
    '3. Datos que no recopilamos',
    'El sistema no solicita tu ubicación ni recopila datos biométricos. Los '
        'movimientos de cabeza que registra el sensor se usan solo para mover '
        'el cursor y calibrar el dispositivo, nunca para identificarte. Solo '
        'se piden los datos estrictamente necesarios para las finalidades '
        'descritas.',
  ),
  _PolicySection(
    '4. Para qué usamos tus datos',
    'Gestionar tu registro y tu cuenta, vincular pacientes con cuidadores, '
        'calibrar y diagnosticar el dispositivo, administrar el Plan Premium '
        'y la facturación, mantener registros de auditoría, garantizar la '
        'seguridad del sistema, atender tus consultas y mejorar el '
        'funcionamiento del sistema a partir de estadísticas de uso '
        'anonimizadas. No se usan para finalidades incompatibles con estas.',
  ),
  _PolicySection(
    '5. Base jurídica',
    'El tratamiento se realiza conforme a la Ley N.º 7593/2025 de Protección '
        'de Datos Personales. Por tratarse de datos de salud, se requiere tu '
        'consentimiento libre, previo, específico, informado e inequívoco, '
        'que otorgás al registrarte.',
  ),
  _PolicySection(
    '6. Conservación',
    'Los datos de cuenta y de salud se conservan mientras tu cuenta esté '
        'activa. La telemetría del dispositivo es temporal y se elimina una '
        'vez cumplida su función de calibración o diagnóstico. Al cerrar tu '
        'cuenta, los datos se eliminan o anonimizan, salvo que exista una '
        'obligación legal de conservarlos.',
  ),
  _PolicySection(
    '7. Quién puede ver tus datos',
    'Solo tú, tu cuidador asignado y el administrador autorizado, según tu '
        'rol. Tus datos no se venden ni se comunican a terceros, salvo '
        'obligación legal, tu consentimiento expreso o cuando sea necesario '
        'para prestar el servicio, como el alojamiento en Firebase.',
  ),
  _PolicySection(
    '8. Dónde se almacenan y cómo se protegen',
    'Los datos se almacenan en Firebase: Cloud Firestore para la '
        'información estructurada, Realtime Database para la telemetría '
        'temporal y Firebase Authentication para el acceso. Se protegen con '
        'autenticación, control de acceso por roles, reglas de seguridad, '
        'cifrado de contraseñas, gestión de sesiones, registros de auditoría '
        'y copias de seguridad.',
  ),
  _PolicySection(
    '9. Tus derechos',
    'Podés acceder a tus datos, rectificarlos o actualizarlos, solicitar su '
        'supresión, oponerte a su tratamiento en los casos previstos por la '
        'ley y revocar tu consentimiento. Podés editar tus datos desde '
        'Perfil o enviar tu solicitud al contacto indicado en esta Política.',
  ),
  _PolicySection(
    '10. Tecnologías de sesión',
    'La aplicación no usa cookies publicitarias ni herramientas de '
        'rastreo. Solo utiliza los identificadores de sesión de Firebase '
        'Authentication para mantener tu sesión iniciada de forma segura.',
  ),
  _PolicySection(
    '11. Actualizaciones de esta Política',
    'Esta Política puede actualizarse por cambios normativos, funcionales o '
        'tecnológicos. Cada nueva versión se publica en la aplicación con su '
        'fecha de actualización.',
  ),
  _PolicySection(
    '12. Contacto',
    'Para consultas sobre el tratamiento de tus datos: Fernando Adrian Ortiz '
        'Sosa · ortizsosa003@gmail.com.',
  ),
  _PolicySection(
    '13. Aceptación y disposición final',
    'Al registrarte declarás haber sido informado sobre esta Política y '
        'otorgás tu consentimiento mediante la casilla correspondiente. Esta '
        'Política se revisa periódicamente para mantenerla conforme a la Ley '
        'N.º 7593/2025.',
  ),
];

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          'Política de privacidad',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu privacidad es parte del cuidado.',
                style: AppTextStyles.display(fontSize: 19),
              ),
              const SizedBox(height: 2),
              Text(
                'Versión 1.0 · Última actualización: septiembre de 2026',
                style: AppTextStyles.body(
                  fontSize: 11,
                  color: AppColors.textMute,
                ),
              ),
              const SizedBox(height: 16),
              for (final section in _policySections)
                PolicyCard(title: section.title, body: section.body),
            ],
          ),
        ),
      ),
    );
  }
}
