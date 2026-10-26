import 'dart:async';

import 'package:dosti_app/core/realtime/realtime_controller.dart';
import 'package:dosti_app/core/realtime/realtime_transport.dart';
import 'package:dosti_app/core/storage/token_store.dart';
import 'package:dosti_app/features/call/call_controller.dart';
import 'package:dosti_app/features/call/call_repository.dart';
import 'package:dosti_app/features/call/mic_permission.dart';
import 'package:dosti_app/features/call/voice_engine.dart';
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

  /// Everything the app emitted: ('start_match', null), ('cancel_match', null), ...
  final emitted = <String>[];
  bool connected = true;

  @override
  bool emit(String event, [Object? data]) {
    if (!connected) return false;
    emitted.add(event);
    return true;
  }
}

/// Voice channel double: records what the app asked for and lets a test play Agora events.
class FakeVoiceEngine implements VoiceEngine {
  final _controller = StreamController<VoiceEvent>.broadcast();
  Object? joinError;
  Map<String, Object?>? joinArgs;
  int leaves = 0;
  bool? muted;
  bool? speaker;
  final renewedTokens = <String>[];

  @override
  Future<void> renewToken(String token) async => renewedTokens.add(token);

  @override
  Stream<VoiceEvent> get events => _controller.stream;

  @override
  Future<void> join({
    required String appId,
    required String token,
    required String channelId,
    required int uid,
  }) async {
    if (joinError != null) throw joinError!;
    joinArgs = {'appId': appId, 'token': token, 'channelId': channelId, 'uid': uid};
  }

  @override
  Future<void> setMuted(bool value) async => muted = value;

  @override
  Future<void> setSpeaker(bool on) async => speaker = on;

  @override
  Future<void> leave() async => leaves++;

  void emit(VoiceEventType type) => _controller.add(VoiceEvent(type));
}

/// Records the REST calls made around a call; errors can be scripted per call.
class FakeCallRepository implements CallRepository {
  final ends = <(String, int)>[];
  final ratings = <(String, int)>[];
  final reports = <(String, String, String)>[]; // reportedUserId, matchId, reason
  final blocks = <String>[];
  Object? endError;
  Object? tokenError;
  int tokenFetches = 0;
  Object? rateError;
  Object? reportError;
  Object? blockError;

  @override
  Future<void> endMatch({required String matchId, required int durationSeconds}) async {
    if (endError != null) throw endError!;
    ends.add((matchId, durationSeconds));
  }

  @override
  Future<String> fetchCallToken(String matchId) async {
    tokenFetches++;
    if (tokenError != null) throw tokenError!;
    return 'fresh.token';
  }

  @override
  Future<void> rate({required String matchId, required int stars}) async {
    if (rateError != null) throw rateError!;
    ratings.add((matchId, stars));
  }

  @override
  Future<void> report({
    required String reportedUserId,
    required String matchId,
    required String reason,
    String? details,
  }) async {
    if (reportError != null) throw reportError!;
    reports.add((reportedUserId, matchId, reason));
  }

  @override
  Future<void> block(String userId) async {
    if (blockError != null) throw blockError!;
    blocks.add(userId);
  }
}

class FakeMic implements MicPermissionGateway {
  MicPermission result = MicPermission.granted;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<MicPermission> request() async {
    requests++;
    return result;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

/// A clock the test moves by hand, so "two minutes later" costs no real time.
class FakeClock {
  DateTime _now = DateTime(2026, 1, 1, 12);

  DateTime now() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

/// Overrides every network edge, so widget tests never touch a real server or secure storage.
List<Override> homeOverrides({
  String? savedToken,
  FakeProfileRepository? profiles,
  FakeTransport? transport,
  FakeVoiceEngine? voice,
  FakeCallRepository? calls,
  FakeMic? mic,
  FakeClock? clock,
}) =>
    [
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore(savedToken)),
      profileRepositoryProvider.overrideWithValue(profiles ?? FakeProfileRepository()),
      realtimeTransportProvider.overrideWithValue(transport ?? FakeTransport()),
      voiceEngineProvider.overrideWithValue(voice ?? FakeVoiceEngine()),
      callRepositoryProvider.overrideWithValue(calls ?? FakeCallRepository()),
      micPermissionProvider.overrideWithValue(mic ?? FakeMic()),
      callTimingsProvider.overrideWithValue(
        CallTimings(tick: const Duration(milliseconds: 5), clock: (clock ?? FakeClock()).now),
      ),
    ];
