import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../navigation/session_guard.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/two_factor_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_input_decoration.dart';
import '../theme/app_text_styles.dart';
import '../widgets/gradient_button.dart';
import '../widgets/status_badge.dart';
import 'login_screen.dart';

/// Segundo paso para entrar: el código de 6 dígitos que "llega" por SMS o
/// por correo. El envío es simulado (ver two_factor_service.dart): el
/// mensaje aparece arriba, como una notificación.
class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({
    super.key,
    required this.user,
    required this.destination,
  });

  final AppUser user;

  /// Pantalla a la que se entra después de verificar.
  final WidgetBuilder destination;

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  static const _sendTime = Duration(milliseconds: 900);

  final _code = TextEditingController();
  final _service = TwoFactorService.instance;
  late TwoFactorChannel _channel = widget.user.twoFactor.effectiveChannel;

  /// `null` mientras se "envía" el código.
  TwoFactorChallenge? _challenge;
  Timer? _sending;
  Timer? _ticker;
  int _wait = 0;
  String? _error;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _sending?.cancel();
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _send() {
    _sending?.cancel();
    _ticker?.cancel();
    setState(() {
      _challenge = null;
      _error = null;
      _code.clear();
    });
    _sending = Timer(_sendTime, () {
      if (!mounted) return;
      setState(() {
        _challenge = _service.start(
          widget.user.twoFactor,
          email: widget.user.email,
          channel: _channel,
        );
        _wait = TwoFactorService.resendDelay.inSeconds;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _wait--);
        if (_wait <= 0) timer.cancel();
      });
    });
  }

  void _switchChannel() {
    _channel = _channel == TwoFactorChannel.sms
        ? TwoFactorChannel.correo
        : TwoFactorChannel.sms;
    _send();
  }

  /// Como el autocompletado de códigos de Android: copia el código del
  /// mensaje al campo.
  void _fill() {
    final challenge = _challenge;
    if (challenge == null) return;
    _code.text = challenge.code;
    _verify();
  }

  Future<void> _verify() async {
    final challenge = _challenge;
    if (challenge == null || _verifying) return;
    final attempt =
        challenge.remainingAttempts > 0 &&
        !DateTime.now().isAfter(challenge.expiresAt);
    final result = challenge.verify(_code.text);
    final ok = result == VerifyResult.ok;
    setState(() => _verifying = true);
    if (attempt) {
      await _service.recordAttempt(
        widget.user,
        ok: ok,
        channel: challenge.channel,
      );
    }
    if (!mounted) return;
    if (ok) {
      SessionService.instance.begin();
      SessionGuard.start(widget.user);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: widget.destination),
        (_) => false,
      );
      return;
    }
    setState(() {
      _verifying = false;
      _error = switch (result) {
        VerifyResult.wrong =>
          'Código incorrecto. Te quedan ${challenge.remainingAttempts} '
              'intentos.',
        VerifyResult.expired => 'El código venció. Pedí uno nuevo.',
        VerifyResult.locked => 'Demasiados intentos. Pedí un código nuevo.',
        VerifyResult.ok => null,
      };
    });
  }

  Future<void> _cancel() async {
    final navigator = Navigator.of(context);
    SessionGuard.stop();
    await AuthService.instance.signOut();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String get _intro {
    final challenge = _challenge;
    final sms = _channel == TwoFactorChannel.sms;
    if (challenge == null) {
      return sms
          ? 'Enviando el código por SMS…'
          : 'Enviando el código por correo…';
    }
    return sms
        ? 'Te enviamos un código de 6 dígitos por SMS al '
              '${challenge.destination}.'
        : 'Te enviamos un código de 6 dígitos por correo a '
              '${challenge.destination}.';
  }

  @override
  Widget build(BuildContext context) {
    final challenge = _challenge;
    final ready = challenge != null && !_verifying;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: challenge == null
                      ? const SizedBox(height: 8)
                      : _SimulatedMessage(challenge: challenge, onFill: _fill),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.cyan, AppColors.violet],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    'Verificación en dos pasos',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.display(fontSize: 20),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _intro,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 12.5,
                    color: AppColors.textMute,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _code,
                  enabled: ready,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppTextStyles.display(
                    fontSize: 24,
                  ).copyWith(letterSpacing: 8),
                  decoration:
                      appFieldDecoration(
                        hintText: 'Código de 6 dígitos',
                      ).copyWith(
                        counterText: '',
                        errorText: _error,
                        errorMaxLines: 2,
                      ),
                  onChanged: (value) {
                    setState(() => _error = null);
                    if (value.length == 6) _verify();
                  },
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: _verifying ? 'Verificando…' : 'Verificar',
                  onPressed: ready && _code.text.length == 6 ? _verify : null,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: challenge == null || _wait > 0 ? null : _send,
                  child: Text(
                    _wait > 0
                        ? 'Reenviar código en $_wait s'
                        : 'Reenviar código',
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: challenge == null || _wait > 0
                          ? AppColors.textMute
                          : AppColors.cyan,
                    ),
                  ),
                ),
                if (widget.user.twoFactor.hasPhone)
                  TextButton(
                    onPressed: challenge == null ? null : _switchChannel,
                    child: Text(
                      _channel == TwoFactorChannel.sms
                          ? 'Recibirlo por correo'
                          : 'Recibirlo por SMS',
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.cyan,
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: _cancel,
                  child: Text(
                    'Cancelar y volver',
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.coral,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Envío simulado: Firebase manda SMS y correos con códigos '
                  'solo en el plan pago (Blaze). Por eso el mensaje aparece '
                  'arriba, dentro de la app.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.mono(fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El SMS o correo "recibido", como una notificación.
class _SimulatedMessage extends StatelessWidget {
  const _SimulatedMessage({required this.challenge, required this.onFill});

  final TwoFactorChallenge challenge;
  final VoidCallback onFill;

  @override
  Widget build(BuildContext context) {
    final sms = challenge.channel == TwoFactorChannel.sms;
    return Container(
      key: ValueKey(challenge),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
      decoration: BoxDecoration(
        color: AppColors.bgPanel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Row(
            spacing: 8,
            children: [
              Icon(
                sms ? Icons.sms_outlined : Icons.mail_outline,
                color: AppColors.cyan,
                size: 18,
              ),
              Expanded(
                child: Text(
                  sms ? 'SMS · HeadMouse Pro' : 'Correo · HeadMouse Pro',
                  style: AppTextStyles.body(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const StatusBadge(text: 'Simulado', tone: StatusBadgeTone.mute),
            ],
          ),
          Text(
            'Para ${challenge.destination}',
            style: AppTextStyles.body(fontSize: 11, color: AppColors.textMute),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              challenge.message,
              style: AppTextStyles.body(fontSize: 12.5),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onFill,
              icon: Icon(Icons.input, size: 16, color: AppColors.cyan),
              label: Text(
                'Completar código',
                style: AppTextStyles.body(fontSize: 12, color: AppColors.cyan),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
