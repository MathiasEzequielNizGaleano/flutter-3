import 'package:flutter/material.dart';

import '../services/records_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_input_decoration.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';

/// Título de una sección dentro de un formulario.
class FormSectionLabel extends StatelessWidget {
  const FormSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: AppTextStyles.mono(fontSize: 11, letterSpacing: 0.8),
    ),
  );
}

/// Campo de texto con el estilo de la app.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.capitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final FormFieldValidator<String>? validator;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      textCapitalization: capitalization,
      style: AppTextStyles.body(fontSize: 13),
      decoration: appFieldDecoration(hintText: hint, icon: icon),
    ),
  );
}

/// Fecha elegida con el calendario. Se puede borrar.
class DatePickerField extends StatelessWidget {
  const DatePickerField({
    super.key,
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  final DateTime? value;
  final String hint;
  final ValueChanged<DateTime?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: hint,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final date = value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          isEmpty: date == null,
          decoration: appFieldDecoration(
            hintText: hint,
            icon: Icons.calendar_today_outlined,
            suffixIcon: date == null
                ? null
                : IconButton(
                    tooltip: 'Borrar fecha',
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.textMute,
                    ),
                    onPressed: () => onChanged(null),
                  ),
          ),
          child: Text(
            date == null ? '' : formatLongDate(date),
            style: AppTextStyles.body(fontSize: 13),
          ),
        ),
      ),
    );
  }
}

/// Lista desplegable de opciones fijas ([Sex], [Mobility], ...).
class ChoiceDropdown<T extends Choice> extends StatelessWidget {
  const ChoiceDropdown({
    super.key,
    required this.value,
    required this.values,
    required this.hint,
    required this.onChanged,
    this.icon,
  });

  final T? value;
  final List<T> values;
  final String hint;
  final IconData? icon;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: AppColors.bgPanel,
      decoration: appFieldDecoration(hintText: hint, icon: icon),
      style: AppTextStyles.body(fontSize: 13),
      items: [
        for (final option in values)
          DropdownMenuItem(value: option, child: Text(option.label)),
      ],
      onChanged: onChanged,
    ),
  );
}

/// Interruptor Sí/No dentro de una tarjeta.
class YesNoSwitch extends StatelessWidget {
  const YesNoSwitch(this.label, this.value, this.onChanged, {super.key});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    value: value,
    onChanged: onChanged,
    activeThumbColor: AppColors.cyan,
    title: Text(label, style: AppTextStyles.body(fontSize: 13)),
  );
}

/// Pie de un formulario: quién queda registrado como autor.
class FormFootnote extends StatelessWidget {
  const FormFootnote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: AppTextStyles.body(fontSize: 11, color: AppColors.textMute),
    ),
  );
}
