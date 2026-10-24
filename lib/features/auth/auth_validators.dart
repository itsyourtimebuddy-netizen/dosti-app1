/// Input checks for the login and sign-up forms. Each returns an error message,
/// or null when the value is fine (the shape Flutter's form fields expect).
/// The limits mirror the backend's Joi schema so users rarely hit a server-side rejection.
class AuthValidators {
  AuthValidators._();

  static const countryCode = '+91';
  static const minAge = 18;
  static const maxAge = 60;
  static const genders = <String>['male', 'female', 'other'];

  /// The user types the 10-digit Indian mobile number; spaces and dashes are ignored.
  static String digitsOnly(String? input) => (input ?? '').replaceAll(RegExp(r'[\s\-]'), '');

  static String? phone(String? input) {
    final digits = digitsOnly(input);
    if (digits.isEmpty) return 'Enter your mobile number';
    if (!RegExp(r'^\d+$').hasMatch(digits)) return 'Use digits only';
    if (digits.length != 10) return 'Enter a 10-digit mobile number';
    if (!RegExp(r'^[6-9]').hasMatch(digits)) return 'Enter a valid Indian mobile number';
    return null;
  }

  /// "98765 43210" -> "+919876543210", the format the backend expects.
  static String toE164(String input) => '$countryCode${digitsOnly(input)}';

  static String? otp(String? input) {
    final code = (input ?? '').trim();
    if (code.isEmpty) return 'Enter the 6-digit code';
    if (!RegExp(r'^\d{6}$').hasMatch(code)) return 'The code is 6 digits';
    return null;
  }

  static String? name(String? input) {
    final value = (input ?? '').trim();
    if (value.length < 2) return 'Enter your name (at least 2 letters)';
    if (value.length > 50) return 'Name is too long';
    return null;
  }

  static String? age(String? input) {
    final value = int.tryParse((input ?? '').trim());
    if (value == null) return 'Enter your age';
    if (value < minAge) return 'You must be $minAge or older';
    if (value > maxAge) return 'Age must be $maxAge or below';
    return null;
  }

  static String? gender(String? value) =>
      (value == null || !genders.contains(value)) ? 'Select your gender' : null;

  static String? city(String? input) {
    final value = (input ?? '').trim();
    if (value.isEmpty) return 'Enter your city';
    if (value.length > 50) return 'City name is too long';
    return null;
  }
}
