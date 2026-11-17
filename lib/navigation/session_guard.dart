import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';

/// Cierra la sesión de este teléfono si la cuenta se da de baja o si la
/// persona cierra sus sesiones desde otro dispositivo, y vuelve al login
/// con el motivo.
class SessionGuard {
  SessionGuard._();

  /// Navegador de la app, para volver al login desde cualquier pantalla.
  static final navigatorKey = GlobalKey<NavigatorState>();

  static StreamSubscription<SessionEnd>? _sub;

  /// Empieza a vigilar la sesión de [user] (al terminar de ingresar).
  static void start(AppUser user) {
    stop();
    _sub = SessionService.instance.watchEnd(user).listen((reason) {
      _end(user, reason);
    });
  }

  static void stop() {
    _sub?.cancel();
    _sub = null;
  }

  static Future<void> _end(AppUser user, SessionEnd reason) async {
    stop();
    final auth = AuthService.instance;
    // Ya se había cerrado (o es otra cuenta): no hay nada que hacer.
    if (auth.current?.uid != user.uid) return;
    await auth.logAccess(user, reason.eventType);
    await auth.signOut(log: false);
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(notice: reason.message)),
      (route) => false,
    );
  }
}
