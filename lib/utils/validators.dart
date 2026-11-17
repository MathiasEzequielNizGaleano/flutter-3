import '../l10n/app_strings.dart';
import '../widgets/password_strength_meter.dart';

class Validators {
  Validators._();

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _name = RegExp(r"^\p{L}[\p{L} '’.\-]*$", unicode: true);
  static final _cedula = RegExp(r'^\d{6,8}$');
  static final _passport = RegExp(r'^(?=.*[A-Z])(?=.*\d)[A-Z0-9]{6,9}$');
  static final _phone = RegExp(r'^\+?[0-9 ()\-]{6,20}$');

  static String? required(String? value, [String? message]) {
    if (value == null || value.trim().isEmpty) {
      return message ?? AppStrings.fieldRequired;
    }
    return null;
  }

  static String? email(String? value) {
    final missing = required(value);
    if (missing != null) return missing;
    return _email.hasMatch(value!.trim()) ? null : AppStrings.invalidEmail;
  }

  /// Correo opcional: vacío es válido.
  static String? optionalEmail(String? value) =>
      (value == null || value.trim().isEmpty) ? null : email(value);

  /// Teléfono opcional: dígitos, espacios, guiones, paréntesis y "+".
  static String? optionalPhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return _phone.hasMatch(text) ? null : 'Ingresa un teléfono válido.';
  }

  static String? userOrEmail(String? value) {
    final missing = required(value, AppStrings.userRequired);
    if (missing != null) return missing;
    return value!.contains('@') ? email(value) : null;
  }

  static String? personName(String? value) {
    final missing = required(value);
    if (missing != null) return missing;
    return _name.hasMatch(value!.trim()) ? null : AppStrings.invalidName;
  }

  static String normalizeDocument(String value) =>
      value.replaceAll(RegExp(r'[.\-\s]'), '').toUpperCase();

  static String? document(String? value) {
    final missing = required(value);
    if (missing != null) return missing;
    final doc = normalizeDocument(value!);
    return _cedula.hasMatch(doc) || _passport.hasMatch(doc)
        ? null
        : AppStrings.invalidDocument;
  }

  static String? loginPassword(String? value) =>
      (value == null || value.isEmpty) ? AppStrings.passwordRequired : null;

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return AppStrings.passwordRequired;
    if (value.length < 8) return AppStrings.passwordTooShort;
    if (passwordStrength(value) < 2) return AppStrings.passwordTooWeak;
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) {
    return (value) {
      if (value == null || value.isEmpty) return AppStrings.passwordRequired;
      return value == original() ? null : AppStrings.passwordMismatch;
    };
  }
}
