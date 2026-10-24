import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import 'user_models.dart';

/// Backend access for the logged-in user's profile and coins. Screens use this interface,
/// so tests can swap in a fake.
abstract class ProfileRepository {
  Future<UserProfile> fetchMe();
  Future<UserProfile> updateMe(ProfileUpdate update);
  Future<int> fetchCoins();
}

class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository(this._api);

  final ApiClient _api;

  UserProfile _parseUser(Map<String, dynamic> data) {
    final user = data['user'];
    if (user is Map<String, dynamic>) return UserProfile.fromJson(user);
    throw const ApiException(
      type: ApiErrorType.unknown,
      message: 'Unexpected response from the server.',
    );
  }

  @override
  Future<UserProfile> fetchMe() async => _parseUser(await _api.getJson('/api/user/me'));

  @override
  Future<UserProfile> updateMe(ProfileUpdate update) async =>
      _parseUser(await _api.patchJson('/api/user/me', body: update.toJson()));

  @override
  Future<int> fetchCoins() async {
    final data = await _api.getJson('/api/wallet/balance');
    final coins = data['coins'];
    if (coins is num) return coins.toInt();
    throw const ApiException(
      type: ApiErrorType.unknown,
      message: 'Unexpected response from the server.',
    );
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ApiProfileRepository(ref.watch(apiClientProvider)),
);
