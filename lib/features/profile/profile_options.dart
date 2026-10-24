/// Choices shared by sign-up, the profile tab and the edit screen. They mirror the backend's allowed values.
class ProfileOptions {
  ProfileOptions._();

  static const interests = <String>['music', 'shayari', 'comedy', 'romance', 'gaming', 'movies', 'travel'];
  static const preferredGenders = <String>['any', 'male', 'female'];
  static const minAge = 18;
  static const maxAge = 60;

  /// "shayari" -> "Shayari"
  static String label(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}
