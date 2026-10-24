import 'package:dosti_app/core/realtime/realtime_controller.dart';
import 'package:dosti_app/core/realtime/realtime_transport.dart';
import 'package:dosti_app/core/storage/token_store.dart';
import 'package:dosti_app/features/profile/profile_repository.dart';
import 'package:dosti_app/features/profile/user_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const testProfile = UserProfile(
  id: 'u1',
  name: 'Rahul',
  age: 25,
  gender: 'male',
  city: 'Surat',
  phone: '+919876543210',
  interests: ['music', 'comedy'],
  preferredGender: 'any',
  preferredMinAge: 20,
  preferredMaxAge: 30,
  totalCalls: 4,
  totalMinutes: 37,
  rating: 4.5,
  coins: 100,
);

/// Scriptable stand-in for the backend's profile and wallet endpoints.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.profile = testProfile});

  UserProfile profile;
  Object? fetchError; // thrown by fetchMe while set
  Object? updateError;
  int? coinsOnServer;
  int fetchMeCalls = 0;
  int fetchCoinsCalls = 0;
  ProfileUpdate? lastUpdate;

  @override
  Future<UserProfile> fetchMe() async {
    fetchMeCalls++;
    if (fetchError != null) throw fetchError!;
    return profile;
  }

  @override
  Future<UserProfile> updateMe(ProfileUpdate update) async {
    if (updateError != null) throw updateError!;
    lastUpdate = update;
    profile = UserProfile(
      id: profile.id,
      name: update.name.trim(),
      age: profile.age,
      gender: profile.gender,
      city: update.city.trim(),
      phone: profile.phone,
      interests: update.interests,
      preferredGender: update.preferredGender,
      preferredMinAge: update.preferredMinAge,
      preferredMaxAge: update.preferredMaxAge,
      totalCalls: profile.totalCalls,
      totalMinutes: profile.totalMinutes,
      rating: profile.rating,
      coins: profile.coins,
    );
    return profile;
  }

  @override
  Future<int> fetchCoins() async {
    fetchCoinsCalls++;
    return coinsOnServer ?? profile.coins;
  }
}

/// Records connect/disconnect and lets a test play server events.
class FakeTransport implements RealtimeTransport {
  String? url;
  String? token;
  RealtimeListener? listener;
  int connects = 0;
  int disconnects = 0;

  @override
  void connect({required String url, required String token, required RealtimeListener listener}) {
    connects++;
    this.url = url;
    this.token = token;
    this.listener = listener;
  }

  @override
  void disconnect() => disconnects++;
}

/// Overrides every network edge, so widget tests never touch a real server or secure storage.
List<Override> homeOverrides({
  String? savedToken,
  FakeProfileRepository? profiles,
  FakeTransport? transport,
}) =>
    [
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore(savedToken)),
      profileRepositoryProvider.overrideWithValue(profiles ?? FakeProfileRepository()),
      realtimeTransportProvider.overrideWithValue(transport ?? FakeTransport()),
    ];
