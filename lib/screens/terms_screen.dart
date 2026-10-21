import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/policy_card.dart';

class _TermsSection {
  const _TermsSection(this.title, this.body);

  final String title;
  final String body;
}

const _termsSections = [
  _TermsSection(
    '1. Objeto',
    'Estos Términos regulan el acceso y uso de la aplicación HeadMouse Pro y '
        'de su dispositivo de control del cursor sin manos. El responsable del '
        'sistema es Fernando Adrian Ortiz Sosa.',
  ),
  _TermsSection(
    '2. Aceptación',
    'Al crear tu cuenta y marcar la casilla correspondiente, declarás haber '
        'leído, comprendido y aceptado estos Términos. Sin esa aceptación no '
        'es posible usar el sistema.',
  ),
  _TermsSection(
    '3. Naturaleza del sistema',
    'HeadMouse Pro es una ayuda técnica de accesibilidad para controlar el '
        'cursor con movimientos de la cabeza. No es un dispositivo médico, no '
        'realiza diagnósticos y no reemplaza la atención de profesionales de '
        'la salud.',
  ),
  _TermsSection(
    '4. Cuentas y roles',
    'Cada cuenta tiene un rol: paciente o cuidador/tutor. Los administradores '
        'son habilitados por el responsable del sistema. Cada rol accede solo '
        'a la información que le corresponde.',
  ),
  _TermsSection(
    '5. Uso permitido',
    'Proporcionar información veraz y actualizada, mantener la '
        'confidencialidad de tus credenciales, usar el dispositivo según el '
        'manual de usuario y avisar de inmediato cualquier uso no autorizado '
        'de tu cuenta.',
  ),
  _TermsSection(
    '6. Usos prohibidos',
    'Usar el sistema con fines ilícitos, acceder sin autorización a cuentas '
        'o funciones restringidas, suplantar a otras personas, compartir '
        'credenciales personales, introducir software malicioso o afectar el '
        'funcionamiento de la plataforma.',
  ),
  _TermsSection(
    '7. Servicios y pagos',
    'La compra del dispositivo, el Plan Premium mensual y el soporte técnico '
        'se rigen por las condiciones y precios que se muestran en '
        'Facturación antes de confirmar cada operación. El Plan Premium es '
        'opcional y puede cancelarse en cualquier momento.',
  ),
  _TermsSection(
    '8. Disponibilidad',
    'El sistema puede tener interrupciones temporales por mantenimiento, '
        'actualizaciones, pruebas, fallas técnicas o causas ajenas a los '
        'desarrolladores. No se garantiza disponibilidad permanente.',
  ),
  _TermsSection(
    '9. Protección de datos',
    'El tratamiento de tus datos personales se rige por la Política de '
        'privacidad, que forma parte integrante de estos Términos.',
  ),
  _TermsSection(
    '10. Propiedad intelectual',
    'El software, el código fuente, el diseño del dispositivo, las '
        'interfaces, los manuales y la documentación técnica están protegidos '
        'por la legislación de propiedad intelectual. Usar el sistema no '
        'implica la cesión de ninguno de esos derechos.',
  ),
  _TermsSection(
    '11. Suspensión del acceso',
    'El acceso puede suspenderse de forma temporal o definitiva si se '
        'detectan acciones que comprometan la seguridad o el funcionamiento '
        'del sistema, o si se incumplen estos Términos.',
  ),
  _TermsSection(
    '12. Limitación de responsabilidad',
    'El responsable no se hace cargo de daños derivados del uso indebido del '
        'dispositivo, del incumplimiento del manual de usuario o de fallas '
        'ajenas a su control, como problemas del equipo o la conexión del '
        'usuario. Ante cualquier falla, el soporte técnico está disponible '
        'por los canales indicados en la aplicación.',
  ),
  _TermsSection(
    '13. Modificaciones',
    'Estos Términos pueden actualizarse por cambios funcionales, '
        'tecnológicos o normativos. Las nuevas versiones se publican en la '
        'aplicación con su fecha de vigencia.',
  ),
  _TermsSection(
    '14. Legislación aplicable',
    'Estos Términos se interpretan conforme a la legislación vigente en '
        'materia de tecnologías de la información, contratación electrónica, '
        'protección de datos personales y propiedad intelectual.',
  ),
  _TermsSection(
    '15. Contacto',
    'Para consultas sobre el funcionamiento del sistema: Fernando Adrian '
        'Ortiz Sosa · ortizsosa003@gmail.com.',
  ),
];

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          'Términos y Condiciones',
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
                'Reglas claras para usar HeadMouse Pro.',
                style: AppTextStyles.display(fontSize: 19),
              ),
              const SizedBox(height: 2),
              Text(
                'Versión 1.0 · Vigente desde septiembre de 2026',
                style: AppTextStyles.body(
                  fontSize: 11,
                  color: AppColors.textMute,
                ),
              ),
              const SizedBox(height: 16),
              for (final section in _termsSections)
                PolicyCard(title: section.title, body: section.body),
            ],
          ),
        ),
      ),
    );
  }
}
