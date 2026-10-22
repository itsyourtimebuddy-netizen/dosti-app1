import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dosti_app/core/network/api_client.dart';
import 'package:dosti_app/core/network/api_exception.dart';
import 'package:dosti_app/core/session/session_controller.dart';
import 'package:dosti_app/core/storage/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the network: answers every request with whatever [_respond] returns
/// (or throws) and remembers the last request so tests can inspect it.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _Setup {
  _Setup(this.client, this.adapter, this.ended);

  final ApiClient client;
  final _FakeAdapter adapter;
  final List<SessionEndReason> ended;
}

_Setup _setup({String? token, required ResponseBody Function(RequestOptions) respond}) {
  final adapter = _FakeAdapter(respond);
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))..httpClientAdapter = adapter;
  final ended = <SessionEndReason>[];
  final client = ApiClient(
    tokenStore: InMemoryTokenStore(token),
    onSessionEnded: ended.add,
    dio: dio,
  );
  return _Setup(client, adapter, ended);
}

void main() {
  group('requests', () {
    test('send the saved token as a Bearer header', () async {
      final s = _setup(token: 'abc123', respond: (_) => _json(200, {'ok': true}));
      await s.client.getJson('/api/wallet/balance');
      expect(s.adapter.last!.headers['Authorization'], 'Bearer abc123');
    });

    test('send no Authorization header when logged out', () async {
      final s = _setup(respond: (_) => _json(200, {'ok': true}));
      await s.client.postJson('/api/auth/send-otp', body: {'phone': '+919999999999'});
      expect(s.adapter.last!.headers.containsKey('Authorization'), isFalse);
    });

    test('return the decoded JSON body', () async {
      final s = _setup(token: 't', respond: (_) => _json(200, {'coins': 100}));
      final data = await s.client.getJson('/api/wallet/balance');
      expect(data['coins'], 100);
    });
  });

  group('session handling', () {
    test('an invalid token signs the user out as "expired"', () async {
      final s = _setup(
        token: 'old',
        respond: (_) => _json(401, {'error': 'Invalid token!', 'code': 'INVALID_TOKEN'}),
      );
      await expectLater(s.client.getJson('/api/wallet/balance'), throwsA(isA<ApiException>()));
      expect(s.ended, [SessionEndReason.expired]);
    });

    test('a banned account signs the user out as "banned"', () async {
      final s = _setup(
        token: 'abc',
        respond: (_) => _json(403, {'error': 'Account banned!', 'code': 'ACCOUNT_BANNED'}),
      );
      await expectLater(
        s.client.getJson('/api/match/blocked'),
        throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.banned)),
      );
      expect(s.ended, [SessionEndReason.banned]);
    });

    test('a wrong OTP (401, user not logged in) does not trigger a sign-out', () async {
      final s = _setup(respond: (_) => _json(401, {'error': 'Incorrect OTP.'}));
      await expectLater(
        s.client.postJson('/api/auth/register', body: {}),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Incorrect OTP.')),
      );
      expect(s.ended, isEmpty);
    });

    test('a failed payment signature (401 while logged in) keeps the user logged in', () async {
      final s = _setup(
        token: 'abc',
        respond: (_) => _json(401, {'error': 'Payment signature verification failed'}),
      );
      await expectLater(s.client.postJson('/api/wallet/purchase/verify', body: {}), throwsA(isA<ApiException>()));
      expect(s.ended, isEmpty);
    });

    test('a server error keeps the user logged in', () async {
      final s = _setup(token: 'abc', respond: (_) => _json(500, {'error': 'boom'}));
      await expectLater(s.client.getJson('/api/wallet/balance'), throwsA(isA<ApiException>()));
      expect(s.ended, isEmpty);
    });
  });

  group('failures', () {
    test('no connection becomes a friendly network error', () async {
      final s = _setup(
        token: 'abc',
        respond: (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(
        s.client.getJson('/api/wallet/balance'),
        throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.network)),
      );
      expect(s.ended, isEmpty);
    });

    test('a non-JSON success body is reported, not returned as garbage', () async {
      final s = _setup(
        token: 'abc',
        respond: (_) => ResponseBody.fromString(
          'ok',
          200,
          headers: {
            Headers.contentTypeHeader: ['text/plain'],
          },
        ),
      );
      await expectLater(s.client.getJson('/health'), throwsA(isA<ApiException>()));
    });
  });
}
