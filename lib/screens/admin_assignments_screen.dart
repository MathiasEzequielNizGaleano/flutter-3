import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/care_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';
import 'assignment_form_screen.dart';

/// Vínculos de un paciente (sus cuidadores) o de un cuidador (sus
/// pacientes), vigentes y terminados. Solo para el administrador.
class AdminAssignmentsScreen extends StatefulWidget {
  const AdminAssignmentsScreen({super.key, required this.user});

  final ManagedUser user;

  @override
  State<AdminAssignmentsScreen> createState() => _AdminAssignmentsScreenState();
}

class _AdminAssignmentsScreenState extends State<AdminAssignmentsScreen> {
  late final bool _isPatient = widget.user.role == UserRole.paciente;
  late Stream<List<CareAssignment>> _links = _watch();
  List<CareAssignment> _current = const [];

  Stream<List<CareAssignment>> _watch() => _isPatient
      ? CareService.instance.watchForPatient(
          widget.user.uid,
          includeEnded: true,
        )
      : CareService.instance.watchForCaregiver(
          widget.user.uid,
          includeEnded: true,
        );

  String _otherName(CareAssignment a) =>
      _isPatient ? a.nombreCuidador : a.nombrePaciente;

  Future<void> _open({CareAssignment? existing}) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AssignmentFormScreen(
          fixed: widget.user,
          existing: existing,
          // No ofrecer a quien ya tiene un vínculo vigente con este usuario.
          excludeUids: {
            for (final a in _current)
              if (a.activo) _isPatient ? a.idCuidador : a.idPaciente,
          },
        ),
      ),
    );
    if (message != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          _isPatient ? 'Cuidadores' : 'Pacientes',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<CareAssignment>>(
          stream: _links,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(
                onRetry: () => setState(() => _links = _watch()),
                message: AuthService.describeError(snapshot.error!),
              );
            }
            if (!snapshot.hasData) return const LoadingView();
            _current = snapshot.data!;
            final active = _current.where((a) => a.activo).toList();
            final ended = _current.where((a) => !a.activo).toList();
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isPatient
                        ? 'Quiénes cuidan a ${widget.user.fullName} y qué '
                              'pueden hacer.'
                        : 'Pacientes a cargo de ${widget.user.fullName}.',
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.textMute,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (active.isEmpty)
                    EmptyState(
                      title: _isPatient
                          ? 'Sin cuidadores asignados'
                          : 'Sin pacientes asignados',
                      message: _isPatient
                          ? 'Usá "Asignar cuidador" para vincular a alguien.'
                          : 'Usá "Asignar paciente" para vincular a alguien.',
                      icon: Icons.link_off,
                    ),
                  for (final a in active)
                    _LinkTile(
                      name: _otherName(a),
                      assignment: a,
                      onTap: () => _open(existing: a),
                    ),
                  if (ended.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'TERMINADOS',
                      style: AppTextStyles.mono(
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final a in ended)
                      _LinkTile(
                        name: _otherName(a),
                        assignment: a,
                        onTap: () => _open(existing: a),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _open,
        backgroundColor: AppColors.cyan,
        foregroundColor: AppColors.bgPanel2,
        icon: const Icon(Icons.add_link),
        label: Text(
          _isPatient ? 'Asignar cuidador' : 'Asignar paciente',
          style: AppTextStyles.body(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.bgPanel2,
          ),
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.name,
    required this.assignment,
    required this.onTap,
  });

  final String name;
  final CareAssignment assignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final since = a.activo
        ? (a.fechaAsignacion == null
              ? ''
              : 'Desde ${formatShortDate(a.fechaAsignacion!)}')
        : (a.fechaFin == null
              ? 'Terminado'
              : 'Terminado el ${formatShortDate(a.fechaFin!)}');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: glassCardDecoration(radius: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              spacing: 12,
              children: [
                InitialsAvatar(initialsOf(name), dimmed: !a.activo),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.body(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        a.relation,
                        style: AppTextStyles.body(
                          fontSize: 11,
                          color: AppColors.textMute,
                        ),
                      ),
                      Text(
                        a.activo ? a.permisos.summary : since,
                        style: AppTextStyles.body(
                          fontSize: 11,
                          color: AppColors.textMute,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  text: a.activo ? 'Vigente' : 'Terminado',
                  tone: a.activo ? StatusBadgeTone.ok : StatusBadgeTone.mute,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
