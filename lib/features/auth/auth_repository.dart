import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import 'auth_models.dart';

/// Everything the auth screens need from the backend. Screens depend on this interface,
/// so tests can swap in a fake without any HTTP.
abstract class AuthRepository {
  /// Sends the SMS code. Returns how many seconds until another code may be requested.
  Future<int> sendOtp(String phone);

  /// Checks the code. Without [profile] a new user gets [AuthResult.profileRequired];
  /// with it the account is created. Existing users log in either way.
  Future<AuthResult> verify({
    required String phone,
    required String otp,
    ProfileInput? profile,
  });
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);

  final ApiClient _api;

  @override
  Future<int> sendOtp(String phone) async {
    final data = await _api.postJson('/api/auth/send-otp', body: {'phone': phone});
    final cooldown = data['cooldown'];
    return cooldown is num ? cooldown.toInt() : 60;
  }

  @override
  Future<AuthResult> verify({
    required String phone,
    required String otp,
    ProfileInput? profile,
  }) async {
    final data = await _api.postJson(
      '/api/auth/register',
      body: {'phone': phone, 'otp': otp, if (profile != null) ...profile.toJson()},
    );

    if (data['status'] == 'profile_required') return const AuthResult.profileRequired();

    final token = data['token'];
    if (token is String && token.isNotEmpty) return AuthResult.loggedIn(token);

    throw const ApiException(
      type: ApiErrorType.unknown,
      message: 'Unexpected response from the server.',
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(ref.watch(apiClientProvider)),
);
