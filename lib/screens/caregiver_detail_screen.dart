import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../services/auth_service.dart';
import '../services/care_service.dart';
import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/info_card.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/profile_parts.dart';
import '../widgets/status_badge.dart';

/// Un cuidador visto por su paciente: permisos y opción de quitarle el
/// acceso. Si lo quita, vuelve con el mensaje a mostrar.
class CaregiverDetailScreen extends StatefulWidget {
  const CaregiverDetailScreen({super.key, required this.assignment});

  final CareAssignment assignment;

  @override
  State<CaregiverDetailScreen> createState() => _CaregiverDetailScreenState();
}

class _CaregiverDetailScreenState extends State<CaregiverDetailScreen> {
  bool _removing = false;
  late final Stream<CaregiverRecord> _contact = RecordsService.instance
      .watchCaregiver(widget.assignment.idCuidador);

  CareAssignment get _a => widget.assignment;

  InfoRow _permission(String label, bool granted) => InfoRow(
    label,
    trailing: StatusBadge(
      text: granted ? 'Sí' : 'No',
      tone: granted ? StatusBadgeTone.ok : StatusBadgeTone.warn,
    ),
  );

  Future<void> _confirmRemoval() async {
    final firstName = _a.nombreCuidador.split(' ').first;
    final confirmed = await confirmAction(
      context,
      title: '¿Quitar a ${_a.nombreCuidador} como tu cuidador?',
      message:
          '$firstName perderá acceso a tus datos y ya no podrá configurar ni '
          'calibrar tu dispositivo. Esta acción no elimina su cuenta, solo '
          'termina su asignación como tu cuidador. Para volver a asignarlo, '
          'pedíselo al administrador.',
      confirmLabel: 'Sí, quitar acceso',
    );
    if (!confirmed || !mounted) return;
    setState(() => _removing = true);
    try {
      await CareService.instance.end(_a);
      if (mounted) {
        Navigator.pop(context, '${_a.nombreCuidador} ya no es tu cuidador.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _removing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AuthService.describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text('Cuidador', style: AppTextStyles.display(fontSize: 18)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  spacing: 8,
                  children: [
                    InitialsAvatar(initialsOf(_a.nombreCuidador), size: 56),
                    Text(
                      _a.nombreCuidador,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.display(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    StatusBadge(text: _a.relation, tone: StatusBadgeTone.warn),
                  ],
                ),
              ),
              const ProfileSectionTitle('Permisos otorgados'),
              InfoCard(
                rows: [
                  _permission('Ver mis datos', _a.permisos.verDatos),
                  _permission('Editar mis datos', _a.permisos.editarDatos),
                  _permission('Configurar dispositivo', _a.permisos.configurar),
                  _permission('Calibrar dispositivo', _a.permisos.calibrar),
                ],
              ),
              const ProfileSectionTitle('Asignación'),
              InfoCard(
                rows: [
                  InfoRow(
                    'Parentesco',
                    value: _a.parentesco.isEmpty ? '—' : _a.parentesco,
                  ),
                  InfoRow('Responsabilidad', value: _a.responsabilidad.label),
                  InfoRow(
                    'Asignado desde',
                    value: _a.fechaAsignacion == null
                        ? '—'
                        : formatShortDate(_a.fechaAsignacion!),
                  ),
                  InfoRow(
                    'Estado',
                    trailing: StatusBadge(
                      text: _a.activo ? 'Activo' : 'Terminado',
                      tone: _a.activo
                          ? StatusBadgeTone.ok
                          : StatusBadgeTone.mute,
                    ),
                  ),
                ],
              ),
              StreamBuilder<CaregiverRecord>(
                stream: _contact,
                builder: (context, snapshot) {
                  final record = snapshot.data;
                  // Sin datos cargados (o sin acceso) no se muestra.
                  if (record == null ||
                      (record.telefono.isEmpty &&
                          record.correoAlternativo.isEmpty)) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ProfileSectionTitle('Contacto'),
                      InfoCard(
                        rows: [
                          if (record.telefono.isNotEmpty)
                            InfoRow('Teléfono', value: record.telefono),
                          if (record.correoAlternativo.isNotEmpty)
                            InfoRow('Correo', value: record.correoAlternativo),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              if (_a.activo)
                OutlineActionButton(
                  label: _removing ? 'Quitando…' : 'Quitar cuidador',
                  onPressed: _removing ? null : _confirmRemoval,
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: patientBottomNav(PatientTab.cuidadores),
    );
  }
}
