import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';

class InfoRow {
  const InfoRow(this.label, {this.value, this.trailing, this.stacked = false})
    : assert(value != null || trailing != null);

  final String label;
  final String? value;
  final Widget? trailing;

  final bool stacked;
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.rows});

  final List<InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: glassCardDecoration(radius: 14),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: AppColors.line)),
              ),
              child: rows[i].stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(
                          rows[i].label,
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: AppColors.textMute,
                          ),
                        ),
                        Text(
                          rows[i].value!,
                          style: AppTextStyles.body(
                            fontSize: 12.5,
                          ).copyWith(height: 1.4),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      spacing: 12,
                      children: [
                        Text(
                          rows[i].label,
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: AppColors.textMute,
                          ),
                        ),
                        Flexible(
                          child:
                              rows[i].trailing ??
                              Text(
                                rows[i].value!,
                                textAlign: TextAlign.right,
                                style: AppTextStyles.body(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}
