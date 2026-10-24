import 'package:dosti_app/features/profile/user_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a full backend response', () {
    final p = UserProfile.fromJson({
      'id': 'abc',
      'name': 'Rahul',
      'age': 25,
      'gender': 'male',
      'city': 'Surat',
      'phone': '+919876543210',
      'language': 'gujarati',
      'interests': ['music', 'comedy'],
      'preferredGender': 'female',
      'preferredAgeRange': {'min': 21, 'max': 29},
      'totalCalls': 3,
      'totalMinutes': 12,
      'rating': 4,
      'coins': 250,
    });
    expect(p.id, 'abc');
    expect(p.interests, ['music', 'comedy']);
    expect(p.preferredGender, 'female');
    expect(p.preferredMinAge, 21);
    expect(p.preferredMaxAge, 29);
    expect(p.rating, 4.0);
    expect(p.coins, 250);
  });

  test('a sparse response gets safe defaults instead of crashing', () {
    final p = UserProfile.fromJson({'id': 'abc', 'name': 'Rahul'});
    expect(p.interests, isEmpty);
    expect(p.preferredGender, 'any');
    expect(p.preferredMinAge, 18);
    expect(p.coins, 0);
    expect(p.rating, 0);
  });

  test('wrong types are ignored rather than thrown', () {
    final p = UserProfile.fromJson({
      'id': 5,
      'interests': 'music',
      'preferredAgeRange': 'x',
      'coins': 'lots',
    });
    expect(p.id, '5');
    expect(p.interests, isEmpty);
    expect(p.coins, 0);
  });

  test('copyWith changes only the coins', () {
    final p = UserProfile.fromJson({'id': 'a', 'name': 'R', 'coins': 1, 'city': 'Surat'});
    final q = p.copyWith(coins: 9);
    expect(q.coins, 9);
    expect(q.name, 'R');
    expect(q.city, 'Surat');
  });

  test('ProfileUpdate sends trimmed text and the age range as an object', () {
    const u = ProfileUpdate(
      name: ' Raj ',
      city: ' Surat ',
      interests: ['music'],
      preferredGender: 'any',
      preferredMinAge: 20,
      preferredMaxAge: 30,
    );
    expect(u.toJson(), {
      'name': 'Raj',
      'city': 'Surat',
      'interests': ['music'],
      'preferredGender': 'any',
      'preferredAgeRange': {'min': 20, 'max': 30},
    });
  });
}
