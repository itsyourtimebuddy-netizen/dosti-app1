import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../session/session_controller.dart';
import '../storage/token_store.dart';
import 'api_exception.dart';

typedef SessionEndedCallback = void Function(SessionEndReason reason);

/// The only place that talks HTTP to the Dosti backend.
///
///  * adds the saved login token to every request
///  * turns every failure into an [ApiException] with a message fit for the user
///  * signs the user out when the backend says the session is over (expired token / ban)
///
/// Paths include the "/api" prefix, e.g. `getJson('/api/wallet/balance')`,
/// because `/health` lives outside it.
class ApiClient {
  ApiClient({
    required TokenStore tokenStore,
    required SessionEndedCallback onSessionEnded,
    Dio? dio,
  })  : _tokenStore = tokenStore,
        _onSessionEnded = onSessionEnded,
        dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.baseUrl,
                connectTimeout: AppConfig.connectTimeout,
                receiveTimeout: AppConfig.receiveTimeout,
                headers: {'Accept': 'application/json'},
                contentType: Headers.jsonContentType,
              ),
            ) {
    this.dio.interceptors.add(InterceptorsWrapper(onRequest: _attachToken));
  }

  final Dio dio;
  final TokenStore _tokenStore;
  final SessionEndedCallback _onSessionEnded;

  Future<void> _attachToken(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _tokenStore.read();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) {
    return _send(() => dio.get<dynamic>(path, queryParameters: query));
  }

  Future<Map<String, dynamic>> postJson(String path, {Object? body}) {
    return _send(() => dio.post<dynamic>(path, data: body));
  }

  Future<Map<String, dynamic>> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw const ApiException(
        type: ApiErrorType.unknown,
        message: 'Unexpected response from the server.',
      );
    } on DioException catch (e) {
      final error = ApiException.fromDio(e);
      // Only a request that actually carried a token can mean "your token is bad".
      final hadToken = e.requestOptions.headers.containsKey('Authorization');
      if (hadToken && error.isSessionEnding) {
        _onSessionEnded(
          error.type == ApiErrorType.banned ? SessionEndReason.banned : SessionEndReason.expired,
        );
      }
      throw error;
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenStore: ref.watch(tokenStoreProvider),
    onSessionEnded: (reason) => ref.read(sessionProvider.notifier).signOut(reason: reason),
  );
});
