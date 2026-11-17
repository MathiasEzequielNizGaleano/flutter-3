import 'package:headmouse_pro/services/auth_service.dart';
import 'package:headmouse_pro/services/two_factor_service.dart';

/// TwoFactorService sin Firebase: el código siempre es 123456.
class FakeTwoFactorService extends TwoFactorService {
  /// Acciones recibidas, para verificarlas en los tests.
  final calls = <String>[];

  @override
  String newCode() => '123456';

  @override
  Future<void> recordAttempt(
    AppUser user, {
    required bool ok,
    required TwoFactorChannel channel,
  }) async =>
      calls.add('intento ${user.uid} ${ok ? 'ok' : 'mal'} ${channel.id}');

  @override
  Future<void> saveSettings(AppUser user, TwoFactorSettings settings) async =>
      calls.add('guardar ${settings.channel.id} ${settings.telefono}');
}
