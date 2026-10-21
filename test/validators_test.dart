import 'package:flutter_test/flutter_test.dart';
import 'package:headmouse_pro/l10n/app_strings.dart';
import 'package:headmouse_pro/utils/validators.dart';
import 'package:headmouse_pro/widgets/password_strength_meter.dart';

void main() {
  group('Validators.email', () {
    test('acepta correos válidos', () {
      expect(Validators.email('ana@correo.com'), isNull);
      expect(Validators.email('  ana.perez@uni.edu.py '), isNull);
    });

    test('rechaza vacío y formatos inválidos', () {
      expect(Validators.email(''), AppStrings.fieldRequired);
      expect(Validators.email('ana'), AppStrings.invalidEmail);
      expect(Validators.email('ana@correo'), AppStrings.invalidEmail);
      expect(Validators.email('ana @correo.com'), AppStrings.invalidEmail);
    });
  });

  group('Validators.userOrEmail', () {
    test('un usuario sin @ solo debe no estar vacío', () {
      expect(Validators.userOrEmail('admin_root'), isNull);
      expect(Validators.userOrEmail(' '), AppStrings.userRequired);
    });

    test('con @ se valida como correo', () {
      expect(Validators.userOrEmail('a@b'), AppStrings.invalidEmail);
      expect(Validators.userOrEmail('a@b.com'), isNull);
    });
  });

  group('Validators.personName', () {
    test('acepta nombres con tildes, espacios y guiones', () {
      expect(Validators.personName('María José'), isNull);
      expect(Validators.personName('Ñandú'), isNull);
      expect(Validators.personName("D'Angelo"), isNull);
      expect(Validators.personName('Pérez-Gómez'), isNull);
    });

    test('rechaza números y símbolos', () {
      expect(Validators.personName('Ana2'), AppStrings.invalidName);
      expect(Validators.personName('@na'), AppStrings.invalidName);
      expect(Validators.personName(''), AppStrings.fieldRequired);
    });
  });

  group('Validators.document', () {
    test('acepta cédula de 6 a 8 dígitos, con o sin puntos', () {
      expect(Validators.document('123456'), isNull);
      expect(Validators.document('4.123.456'), isNull);
      expect(Validators.document('12345678'), isNull);
    });

    test('acepta pasaporte con al menos una letra y un número', () {
      expect(Validators.document('AB123456'), isNull);
      expect(Validators.document('ab123456'), isNull);
    });

    test('rechaza largos y formatos inválidos', () {
      expect(Validators.document('12345'), AppStrings.invalidDocument);
      expect(Validators.document('123456789'), AppStrings.invalidDocument);
      expect(Validators.document('ABCDEF'), isNotNull);
      expect(Validators.document(''), AppStrings.fieldRequired);
    });
  });

  group('Validators.newPassword', () {
    test('exige largo mínimo y fuerza mínima', () {
      expect(Validators.newPassword(''), AppStrings.passwordRequired);
      expect(Validators.newPassword('Ab1!'), AppStrings.passwordTooShort);
      expect(Validators.newPassword('abcdefgh'), AppStrings.passwordTooWeak);
      expect(Validators.newPassword('abcdefgh1'), isNull);
      expect(Validators.newPassword('Abcdefg1!'), isNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('compara con la contraseña original', () {
      final validate = Validators.confirmPassword(() => 'Secreta123');
      expect(validate('Secreta123'), isNull);
      expect(validate('otra'), AppStrings.passwordMismatch);
      expect(validate(''), AppStrings.passwordRequired);
    });
  });

  group('passwordStrength', () {
    test('puntúa de 0 a 4', () {
      expect(passwordStrength(''), 0);
      expect(passwordStrength('abc'), 0);
      expect(passwordStrength('abcdefgh'), 1);
      expect(passwordStrength('abcdefgh1'), 2);
      expect(passwordStrength('Abcdefgh1'), 3);
      expect(passwordStrength('Abcdefgh1!'), 4);
    });

    test('una contraseña corta nunca pasa de 1', () {
      expect(passwordStrength('Ab1!'), 1);
    });
  });
}
