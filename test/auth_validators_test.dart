import 'package:dosti_app/features/auth/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('phone', () {
    test('accepts a 10-digit Indian mobile, with spaces or dashes', () {
      expect(AuthValidators.phone('9876543210'), isNull);
      expect(AuthValidators.phone('98765 43210'), isNull);
      expect(AuthValidators.phone('98765-43210'), isNull);
    });
    test('rejects empty, short, long, wrong start and letters', () {
      expect(AuthValidators.phone(''), isNotNull);
      expect(AuthValidators.phone(null), isNotNull);
      expect(AuthValidators.phone('98765'), isNotNull);
      expect(AuthValidators.phone('98765432100'), isNotNull);
      expect(AuthValidators.phone('1234567890'), isNotNull);
      expect(AuthValidators.phone('98765abcde'), isNotNull);
    });
    test('toE164 builds the format the backend expects', () {
      expect(AuthValidators.toE164('98765 43210'), '+919876543210');
    });
  });

  group('otp', () {
    test('needs exactly 6 digits', () {
      expect(AuthValidators.otp('123456'), isNull);
      expect(AuthValidators.otp(' 123456 '), isNull);
      expect(AuthValidators.otp(''), isNotNull);
      expect(AuthValidators.otp('12345'), isNotNull);
      expect(AuthValidators.otp('1234567'), isNotNull);
      expect(AuthValidators.otp('12345a'), isNotNull);
    });
  });

  group('profile fields', () {
    test('name', () {
      expect(AuthValidators.name('Rahul'), isNull);
      expect(AuthValidators.name(' R '), isNotNull);
      expect(AuthValidators.name(''), isNotNull);
      expect(AuthValidators.name('a' * 51), isNotNull);
    });
    test('age is 18 to 60', () {
      expect(AuthValidators.age('18'), isNull);
      expect(AuthValidators.age('60'), isNull);
      expect(AuthValidators.age('17'), contains('18'));
      expect(AuthValidators.age('61'), isNotNull);
      expect(AuthValidators.age(''), isNotNull);
      expect(AuthValidators.age('abc'), isNotNull);
    });
    test('gender must be one of the allowed values', () {
      expect(AuthValidators.gender('male'), isNull);
      expect(AuthValidators.gender('other'), isNull);
      expect(AuthValidators.gender(null), isNotNull);
      expect(AuthValidators.gender('robot'), isNotNull);
    });
    test('city', () {
      expect(AuthValidators.city('Surat'), isNull);
      expect(AuthValidators.city('  '), isNotNull);
      expect(AuthValidators.city('a' * 51), isNotNull);
    });
  });
}
