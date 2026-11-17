import 'package:flutter/material.dart';

import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import 'status_badge.dart';

StatusBadgeTone diagnosisTone(DiagnosisType type) => switch (type) {
  DiagnosisType.principal => StatusBadgeTone.ok,
  DiagnosisType.secundario => StatusBadgeTone.violet,
  DiagnosisType.antecedente => StatusBadgeTone.warn,
};

/// "Vigente", "No vigente" o "Anulado".
String diagnosisStatus(Diagnosis d) => d.anulado
    ? 'Anulado'
    : d.esActual
    ? 'Vigente'
    : 'No vigente';

/// Un diagnóstico en una lista. Con [patientName] lo muestra arriba (listas
/// de varios pacientes).
class DiagnosisCard extends StatelessWidget {
  const DiagnosisCard({
    super.key,
    required this.diagnosis,
    this.patientName,
    this.onTap,
  });

  final Diagnosis diagnosis;
  final String? patientName;
  final VoidCallback? onTap;

  Widget _meta(String left, String right, {String? bold}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      Flexible(
        child: Text.rich(
          TextSpan(
            text: left,
            children: [
              if (bold != null)
                TextSpan(
                  text: bold,
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          style: AppTextStyles.body(fontSize: 10.5, color: AppColors.textMute),
        ),
      ),
      Flexible(
        child: Text(
          right,
          textAlign: TextAlign.right,
          style: AppTextStyles.body(fontSize: 10.5, color: AppColors.textMute),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final d = diagnosis;
    final title = patientName ?? d.diagnostico;
    final date = d.fechaDiagnostico;
    final registered = d.fechaRegistro == null
        ? ''
        : formatShortDate(d.fechaRegistro!);

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 8,
            children: [
              Flexible(
                child: Text(
                  title,
                  style:
                      AppTextStyles.body(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ).copyWith(
                        decoration: d.anulado
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                ),
              ),
              StatusBadge(
                text: d.tipo.label,
                tone: d.anulado ? StatusBadgeTone.mute : diagnosisTone(d.tipo),
              ),
            ],
          ),
          if (patientName != null)
            Text(d.diagnostico, style: AppTextStyles.body(fontSize: 12)),
          if (d.descripcion.isNotEmpty)
            Text(
              d.descripcion,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(fontSize: 12),
            ),
          _meta(
            d.tipo == DiagnosisType.antecedente ? 'Fecha: ' : 'Diagnosticado: ',
            diagnosisStatus(d),
            bold: date == null ? 'sin fecha' : formatLongDate(date),
          ),
          if (d.profesional.isNotEmpty || d.source.isNotEmpty)
            _meta(d.profesional, d.source),
          if (d.nombreRegistrador.isNotEmpty)
            _meta('Registrado por: ', registered, bold: d.nombreRegistrador),
          if (d.adjuntos > 0)
            Row(
              spacing: 4,
              children: [
                Icon(Icons.attach_file, size: 13, color: AppColors.textMute),
                Text(
                  d.adjuntos == 1
                      ? '1 documento de respaldo'
                      : '${d.adjuntos} documentos de respaldo',
                  style: AppTextStyles.body(
                    fontSize: 10.5,
                    color: AppColors.textMute,
                  ),
                ),
              ],
            ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.overlay,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }
}
