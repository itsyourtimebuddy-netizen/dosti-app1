import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

/// Backend calls around a finished call. Screens and the controller use this interface so tests can fake it.
abstract class CallRepository {
  /// Tells the server the call is over. Safe to repeat: the backend counts a call once.
  Future<void> endMatch({required String matchId, required int durationSeconds});

  Future<void> rate({required String matchId, required int stars});

  Future<void> report({
    required String reportedUserId,
    required String matchId,
    required String reason,
    String? details,
  });

  Future<void> block(String userId);
}

class ApiCallRepository implements CallRepository {
  ApiCallRepository(this._api);

  final ApiClient _api;

  @override
  Future<void> endMatch({required String matchId, required int durationSeconds}) async {
    await _api.postJson('/api/match/end', body: {'matchId': matchId, 'durationSeconds': durationSeconds});
  }

  @override
  Future<void> rate({required String matchId, required int stars}) async {
    await _api.postJson('/api/match/rate', body: {'matchId': matchId, 'stars': stars});
  }

  @override
  Future<void> report({
    required String reportedUserId,
    required String matchId,
    required String reason,
    String? details,
  }) async {
    final text = details?.trim() ?? '';
    await _api.postJson('/api/match/report', body: {
      'reportedUserId': reportedUserId,
      'matchId': matchId,
      'reason': reason,
      if (text.isNotEmpty) 'details': text,
    });
  }

  @override
  Future<void> block(String userId) async {
    await _api.postJson('/api/match/block', body: {'userId': userId});
  }
}

final callRepositoryProvider = Provider<CallRepository>(
  (ref) => ApiCallRepository(ref.watch(apiClientProvider)),
);
