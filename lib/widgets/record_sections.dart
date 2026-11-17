import 'package:flutter/material.dart';

import '../screens/access_history_screen.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import 'info_card.dart';
import 'profile_parts.dart';

String orDash(String value) => value.trim().isEmpty ? '—' : value.trim();

String yesNo(bool value) => value ? 'Sí' : 'No';

/// "14 mar 1998 (28 años)"
String birthLabel(DateTime? date) =>
    date == null ? '—' : '${formatLongDate(date)} (${ageOn(date)} años)';

/// Datos personales, SENADIS, contacto de emergencia y estado funcional.
class PatientRecordSections extends StatelessWidget {
  const PatientRecordSections({super.key, required this.record, this.account});

  final PatientRecord record;

  /// Para el documento. `null` si no se pudo leer la cuenta.
  final ManagedUser? account;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionTitle('Datos personales'),
        InfoCard(
          rows: [
            if (account != null)
              InfoRow('Documento', value: orDash(account!.documento)),
            InfoRow(
              'Fecha de nacimiento',
              value: birthLabel(record.fechaNacimiento),
            ),
            InfoRow('Sexo', value: record.sexo?.label ?? '—'),
            InfoRow('Teléfono', value: orDash(record.telefono)),
            InfoRow('Dirección', value: orDash(record.direccion)),
          ],
        ),
        const ProfileSectionTitle('Registro SENADIS'),
        InfoCard(
          rows: [
            InfoRow('N° de registro', value: orDash(record.registroSenadis)),
          ],
        ),
        const ProfileSectionTitle('Contacto de emergencia'),
        InfoCard(
          rows: [
            InfoRow('Nombre', value: orDash(record.contactoEmergencia)),
            InfoRow('Teléfono', value: orDash(record.telefonoEmergencia)),
          ],
        ),
        const ProfileSectionTitle('Estado funcional'),
        FunctionalStateCard(state: record.estadoFuncional),
      ],
    );
  }
}

class FunctionalStateCard extends StatelessWidget {
  const FunctionalStateCard({super.key, required this.state});

  final FunctionalState? state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: glassCardDecoration(radius: 14),
        child: Text(
          'Todavía no se registró la evaluación funcional.',
          style: AppTextStyles.body(fontSize: 12, color: AppColors.textMute),
        ),
      );
    }
    final evaluated = [
      if (s.nombreEvaluador.isNotEmpty) s.nombreEvaluador,
      if (s.fechaEvaluacion != null) formatLongDate(s.fechaEvaluacion!),
    ].join(' · ');
    return InfoCard(
      rows: [
        InfoRow('Movilidad cervical', value: s.movilidadCervical?.label ?? '—'),
        InfoRow(
          'Movilidad miofacial',
          value: s.movilidadMiofacial?.label ?? '—',
        ),
        InfoRow('Control cefálico', value: s.controlCefalico?.label ?? '—'),
        InfoRow(
          'Movimientos involuntarios',
          value: yesNo(s.movimientosInvoluntarios),
        ),
        InfoRow(
          'Miembros superiores',
          value: s.limitacionMiembrosSuperiores
              ? 'Con limitación'
              : 'Sin limitación',
        ),
        InfoRow('Activa el clip izquierdo', value: yesNo(s.puedeClipIzquierdo)),
        InfoRow('Activa el clip derecho', value: yesNo(s.puedeClipDerecho)),
        InfoRow('Nivel de asistencia', value: s.nivelAsistencia?.label ?? '—'),
        if (s.observaciones.isNotEmpty)
          InfoRow('Observaciones', value: s.observaciones, stacked: true),
        if (evaluated.isNotEmpty) InfoRow('Evaluado por', value: evaluated),
      ],
    );
  }
}

/// Datos personales y de contacto del cuidador.
class CaregiverRecordSections extends StatelessWidget {
  const CaregiverRecordSections({
    super.key,
    required this.record,
    this.account,
  });

  final CaregiverRecord record;
  final ManagedUser? account;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionTitle('Datos personales'),
        InfoCard(
          rows: [
            if (account != null)
              InfoRow('Documento', value: orDash(account!.documento)),
            InfoRow(
              'Fecha de nacimiento',
              value: birthLabel(record.fechaNacimiento),
            ),
            InfoRow('Sexo', value: record.sexo?.label ?? '—'),
            InfoRow('Ocupación', value: orDash(record.ocupacion)),
          ],
        ),
        const ProfileSectionTitle('Contacto'),
        InfoCard(
          rows: [
            InfoRow('Teléfono', value: orDash(record.telefono)),
            InfoRow(
              'Correo alternativo',
              value: orDash(record.correoAlternativo),
            ),
            InfoRow('Dirección', value: orDash(record.direccion)),
          ],
        ),
        if (record.observaciones.isNotEmpty) ...[
          const ProfileSectionTitle('Observaciones'),
          InfoCard(
            rows: [
              InfoRow(
                'Información relevante',
                value: record.observaciones,
                stacked: true,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Correo, último acceso y fecha de alta de una cuenta.
class AccountSection extends StatelessWidget {
  const AccountSection({
    super.key,
    required this.account,
    this.title = 'Cuenta',
  });

  final ManagedUser account;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionTitle(title),
        InfoCard(
          rows: [
            InfoRow('Correo', value: orDash(account.email)),
            InfoRow(
              'Último acceso',
              value: account.ultimoIngreso == null
                  ? '—'
                  : formatEventTime(account.ultimoIngreso!),
            ),
            InfoRow(
              'Miembro desde',
              value: account.fechaRegistro == null
                  ? '—'
                  : formatLongDate(account.fechaRegistro!),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GhostButton(
          'Ver historial de ingresos',
          onPressed: () {
            final own = account.uid == AuthService.instance.currentUid;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AccessHistoryScreen(
                  uid: account.uid,
                  name: own ? null : account.fullName,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
