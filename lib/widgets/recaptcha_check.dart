import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Casilla "No soy un robot" (SIMULADA).
///
/// El reCAPTCHA real necesita un servidor que valide cada respuesta con la
/// clave secreta, y el plan gratuito de Firebase no permite tener ese
/// servidor. La casilla imita el comportamiento: al tocarla verifica un
/// momento y queda marcada; sin marcarla no se puede entrar ni registrarse.
class RecaptchaCheck extends StatefulWidget {
  const RecaptchaCheck({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<RecaptchaCheck> createState() => _RecaptchaCheckState();
}

class _RecaptchaCheckState extends State<RecaptchaCheck> {
  static const _checkTime = Duration(milliseconds: 800);

  Timer? _timer;

  bool get _checking => _timer?.isActive ?? false;

  void _check() {
    if (widget.value || _checking) return;
    setState(() {
      _timer = Timer(_checkTime, () {
        if (!mounted) return;
        setState(() {});
        widget.onChanged(true);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checked = widget.value;
    return Semantics(
      checked: checked,
      button: true,
      label: 'No soy un robot',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _check,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: checked
                    ? AppColors.cyan.withValues(alpha: 0.6)
                    : AppColors.line,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: 12,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 10,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: checked ? AppColors.cyan : AppColors.line,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _checking
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.cyan,
                                ),
                              )
                            : checked
                            ? Icon(Icons.check, color: AppColors.cyan)
                            : null,
                      ),
                      Flexible(
                        child: Text(
                          _checking ? 'Verificando…' : 'No soy un robot',
                          style: AppTextStyles.body(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.cyan, AppColors.violet],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'reCAPTCHA',
                      style: AppTextStyles.mono(
                        fontSize: 10,
                        color: AppColors.text,
                      ),
                    ),
                    Text('simulado', style: AppTextStyles.mono(fontSize: 8.5)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
