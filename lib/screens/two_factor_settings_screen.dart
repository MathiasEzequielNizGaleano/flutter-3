import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/two_factor_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/validators.dart';
import '../widgets/form_fields.dart';
import '../widgets/gradient_button.dart';
import '../widgets/selectable_tile.dart';
import '../widgets/unsaved_changes_guard.dart';

/// "Correo · ma•••@gmail.com" o "SMS · ••• ••• 567".
String twoFactorSummary(AppUser user) {
  final settings = user.twoFactor;
  return settings.effectiveChannel == TwoFactorChannel.sms
      ? 'SMS · ${maskPhone(settings.telefono)}'
      : 'Correo · ${maskEmail(user.email)}';
}

/// Dónde recibe el usuario el código de la verificación en dos pasos.
/// Vuelve con un mensaje si guardó cambios.
class TwoFactorSettingsScreen extends StatefulWidget {
  const TwoFactorSettingsScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<TwoFactorSettingsScreen> createState() =>
      _TwoFactorSettingsScreenState();
}

class _TwoFactorSettingsScreenState extends State<TwoFactorSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TwoFactorChannel _channel = widget.user.twoFactor.channel;
  late final _phone = TextEditingController(
    text: widget.user.twoFactor.telefono,
  );
  bool _saving = false;

  TwoFactorSettings get _settings =>
      TwoFactorSettings(channel: _channel, telefono: _phone.text);

  bool get _changed => _settings != widget.user.twoFactor;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (_channel != TwoFactorChannel.sms) {
      return Validators.optionalPhone(value);
    }
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa el número donde vas a recibir el SMS.';
    }
    return Validators.optionalPhone(value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await TwoFactorService.instance.saveSettings(widget.user, _settings);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      _channel == TwoFactorChannel.sms
          ? 'Listo. Los próximos códigos te llegan por SMS.'
          : 'Listo. Los próximos códigos te llegan por correo.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      hasChanges: () => _changed && !_saving,
      listenable: _phone,
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: AppBar(
          backgroundColor: AppColors.bgDeep,
          foregroundColor: AppColors.text,
          title: Text(
            'Verificación en dos pasos',
            style: AppTextStyles.display(fontSize: 18),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cada vez que entrás, además de la contraseña te pedimos '
                    'un código de 6 dígitos. Elegí dónde querés recibirlo.',
                    style: AppTextStyles.body(
                      fontSize: 12.5,
                      color: AppColors.textMute,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final channel in TwoFactorChannel.values)
                    SelectableTile(
                      title: channel.label,
                      subtitle: channel == TwoFactorChannel.correo
                          ? maskEmail(widget.user.email)
                          : 'Al número que escribas abajo',
                      selected: _channel == channel,
                      onTap: () => setState(() => _channel = channel),
                      leading: Icon(
                        channel == TwoFactorChannel.sms
                            ? Icons.sms_outlined
                            : Icons.mail_outline,
                        color: AppColors.cyan,
                      ),
                    ),
                  if (_channel == TwoFactorChannel.sms) ...[
                    const SizedBox(height: 4),
                    AppTextField(
                      controller: _phone,
                      hint: 'Número de celular',
                      icon: Icons.phone_iphone,
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                    ),
                  ],
                  const SizedBox(height: 12),
                  ListenableBuilder(
                    listenable: _phone,
                    builder: (context, _) => GradientButton(
                      label: _saving ? 'Guardando…' : 'Guardar',
                      onPressed: _changed && !_saving ? _save : null,
                    ),
                  ),
                  const FormFootnote(
                    'El envío del código es simulado: Firebase manda SMS y '
                    'correos con códigos solo en el plan pago (Blaze). El '
                    'código aparece dentro de la app al entrar.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
