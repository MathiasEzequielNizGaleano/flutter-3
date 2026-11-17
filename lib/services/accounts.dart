// Alta de cuentas de Firebase Auth desde una sesión ya iniciada.
//
// Si la cuenta se creara con la sesión principal, Firebase entraría como el
// usuario nuevo y cerraría la de quien lo está dando de alta. Por eso se usa
// una app de Firebase aparte ("altas") solo para crear cuentas.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth_service.dart';

const _altasAppName = 'altas';

Future<FirebaseApp> _altasApp() async {
  for (final app in Firebase.apps) {
    if (app.name == _altasAppName) return app;
  }
  return Firebase.initializeApp(
    name: _altasAppName,
    options: Firebase.app().options,
  );
}

/// Crea la cuenta y llama a [writeProfile] con ella para guardar su perfil
/// (con la sesión principal). Si [writeProfile] falla, borra la cuenta para
/// que se pueda reintentar con el mismo correo.
Future<T> createAccount<T>({
  required String email,
  required String password,
  required Future<T> Function(User account) writeProfile,
}) async {
  final FirebaseAuth auth;
  final UserCredential cred;
  try {
    auth = FirebaseAuth.instanceFor(app: await _altasApp());
    cred = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  } catch (e) {
    throw AuthException(AuthService.describeError(e));
  }
  final account = cred.user!;
  try {
    return await writeProfile(account);
  } catch (_) {
    try {
      await account.delete();
    } catch (_) {}
    rethrow;
  } finally {
    try {
      await auth.signOut();
    } catch (_) {}
  }
}
