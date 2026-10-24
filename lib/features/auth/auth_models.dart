/// Details a new user fills in after verifying their phone.
class ProfileInput {
  const ProfileInput({
    required this.name,
    required this.age,
    required this.gender,
    required this.city,
  });

  final String name;
  final int age;
  final String gender;
  final String city;

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'age': age,
        'gender': gender,
        'city': city.trim(),
      };
}

/// What the backend answered to "verify this OTP".
class AuthResult {
  const AuthResult._({this.token, required this.profileRequired});

  /// Phone verified, but this is a new user: ask for the profile and verify again.
  const AuthResult.profileRequired() : this._(profileRequired: true);

  /// Logged in (existing user) or account created (new user).
  const AuthResult.loggedIn(String token) : this._(token: token, profileRequired: false);

  final String? token;
  final bool profileRequired;
}

/// Backend error codes the auth screens react to.
class AuthErrorCodes {
  AuthErrorCodes._();

  static const otpInvalid = 'OTP_INVALID';
  static const otpExpired = 'OTP_EXPIRED';
  static const otpTooManyAttempts = 'OTP_TOO_MANY_ATTEMPTS';
  static const otpCooldown = 'OTP_COOLDOWN';

  /// The code can no longer be used: the user has to ask for a new one.
  static bool needsNewOtp(String? code) => code == otpExpired || code == otpTooManyAttempts;
}
