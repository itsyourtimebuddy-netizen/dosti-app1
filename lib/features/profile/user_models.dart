import 'profile_options.dart';

int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

/// The logged-in user's own profile plus coin balance, as sent by GET /api/user/me.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.city,
    required this.phone,
    this.language = 'gujarati',
    this.interests = const [],
    this.preferredGender = 'any',
    this.preferredMinAge = ProfileOptions.minAge,
    this.preferredMaxAge = 35,
    this.totalCalls = 0,
    this.totalMinutes = 0,
    this.rating = 0,
    this.coins = 0,
  });

  final String id;
  final String name;
  final int age;
  final String gender;
  final String city;
  final String phone;
  final String language;
  final List<String> interests;
  final String preferredGender;
  final int preferredMinAge;
  final int preferredMaxAge;
  final int totalCalls;
  final int totalMinutes;
  final double rating;
  final int coins;

  /// Reads the server JSON defensively: a missing optional field must not crash the home screen.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final range = json['preferredAgeRange'];
    final interests = json['interests'];
    return UserProfile(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      age: _int(json['age']),
      gender: (json['gender'] ?? 'other').toString(),
      city: (json['city'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      language: (json['language'] ?? 'gujarati').toString(),
      interests: interests is List ? interests.whereType<String>().toList() : const [],
      preferredGender: (json['preferredGender'] ?? 'any').toString(),
      preferredMinAge: range is Map ? _int(range['min'], ProfileOptions.minAge) : ProfileOptions.minAge,
      preferredMaxAge: range is Map ? _int(range['max'], 35) : 35,
      totalCalls: _int(json['totalCalls']),
      totalMinutes: _int(json['totalMinutes']),
      rating: json['rating'] is num ? (json['rating'] as num).toDouble() : 0,
      coins: _int(json['coins']),
    );
  }

  UserProfile copyWith({int? coins}) => UserProfile(
        id: id,
        name: name,
        age: age,
        gender: gender,
        city: city,
        phone: phone,
        language: language,
        interests: interests,
        preferredGender: preferredGender,
        preferredMinAge: preferredMinAge,
        preferredMaxAge: preferredMaxAge,
        totalCalls: totalCalls,
        totalMinutes: totalMinutes,
        rating: rating,
        coins: coins ?? this.coins,
      );
}

/// What the edit screen sends. Age, gender and phone are not editable.
class ProfileUpdate {
  const ProfileUpdate({
    required this.name,
    required this.city,
    required this.interests,
    required this.preferredGender,
    required this.preferredMinAge,
    required this.preferredMaxAge,
  });

  final String name;
  final String city;
  final List<String> interests;
  final String preferredGender;
  final int preferredMinAge;
  final int preferredMaxAge;

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'city': city.trim(),
        'interests': interests,
        'preferredGender': preferredGender,
        'preferredAgeRange': {'min': preferredMinAge, 'max': preferredMaxAge},
      };
}
