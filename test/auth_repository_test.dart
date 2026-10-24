import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dosti_app/core/network/api_client.dart';
import 'package:dosti_app/core/network/api_exception.dart';
import 'package:dosti_app/core/storage/token_store.dart';
import 'package:dosti_app/features/auth/auth_models.dart';
import 'package:dosti_app/features/auth/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final ResponseBody Function(RequestOptions) respond;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return respond(options);
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

(ApiAuthRepository, _Adapter) _repo(ResponseBody Function(RequestOptions) respond) {
  final adapter = _Adapter(respond);
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))..httpClientAdapter = adapter;
  final client = ApiClient(tokenStore: InMemoryTokenStore(), onSessionEnded: (_) {}, dio: dio);
  return (ApiAuthRepository(client), adapter);
}

void main() {
  group('sendOtp', () {
    test('posts the phone and returns the cooldown', () async {
      final (repo, adapter) = _repo((_) => _json(200, {'message': 'ok', 'cooldown': 45}));
      expect(await repo.sendOtp('+919876543210'), 45);
      expect(adapter.last!.path, '/api/auth/send-otp');
      expect(adapter.last!.data, {'phone': '+919876543210'});
    });

    test('falls back to 60 seconds if the backend omits the cooldown', () async {
      final (repo, _) = _repo((_) => _json(200, {'message': 'ok'}));
      expect(await repo.sendOtp('+919876543210'), 60);
    });

    test('cooldown error keeps its code', () async {
      final (repo, _) = _repo((_) => _json(429, {'error': 'wait', 'code': 'OTP_COOLDOWN'}));
      await expectLater(
        repo.sendOtp('+919876543210'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', AuthErrorCodes.otpCooldown)),
      );
    });
  });

  group('verify', () {
    test('profile_required for a new user', () async {
      final (repo, adapter) = _repo((_) => _json(200, {'status': 'profile_required'}));
      final r = await repo.verify(phone: '+919876543210', otp: '123456');
      expect(r.profileRequired, isTrue);
      expect(r.token, isNull);
      expect(adapter.last!.path, '/api/auth/register');
      expect(adapter.last!.data, {'phone': '+919876543210', 'otp': '123456'});
    });

    test('sends the profile and returns the token', () async {
      final (repo, adapter) = _repo((_) => _json(201, {'token': 'jwt.abc', 'user': {'id': '1'}}));
      final r = await repo.verify(
        phone: '+919876543210',
        otp: '123456',
        profile: const ProfileInput(name: ' Rahul ', age: 25, gender: 'male', city: ' Surat '),
      );
      expect(r.profileRequired, isFalse);
      expect(r.token, 'jwt.abc');
      expect(adapter.last!.data, {
        'phone': '+919876543210',
        'otp': '123456',
        'name': 'Rahul',
        'age': 25,
        'gender': 'male',
        'city': 'Surat',
      });
    });

    test('existing user: token without a profile', () async {
      final (repo, _) = _repo((_) => _json(200, {'token': 'jwt.xyz'}));
      expect((await repo.verify(phone: '+919876543210', otp: '123456')).token, 'jwt.xyz');
    });

    test('a 200 without a token is an error, not a silent login', () async {
      final (repo, _) = _repo((_) => _json(200, {'message': 'hmm'}));
      await expectLater(
        repo.verify(phone: '+919876543210', otp: '123456'),
        throwsA(isA<ApiException>()),
      );
    });

    test('wrong code: unauthorized with OTP_INVALID, not a session-ending error', () async {
      final (repo, _) = _repo((_) => _json(401, {'error': 'Incorrect OTP.', 'code': 'OTP_INVALID'}));
      await expectLater(
        repo.verify(phone: '+919876543210', otp: '000000'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', AuthErrorCodes.otpInvalid)
              .having((e) => e.isSessionEnding, 'isSessionEnding', isFalse),
        ),
      );
    });

    test('banned account is reported as banned', () async {
      final (repo, _) = _repo((_) => _json(403, {'error': 'Account banned!', 'code': 'ACCOUNT_BANNED'}));
      await expectLater(
        repo.verify(phone: '+919876543210', otp: '123456'),
        throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.banned)),
      );
    });
  });

  test('needsNewOtp is true only for expired and too-many-attempts', () {
    expect(AuthErrorCodes.needsNewOtp('OTP_EXPIRED'), isTrue);
    expect(AuthErrorCodes.needsNewOtp('OTP_TOO_MANY_ATTEMPTS'), isTrue);
    expect(AuthErrorCodes.needsNewOtp('OTP_INVALID'), isFalse);
    expect(AuthErrorCodes.needsNewOtp(null), isFalse);
  });
}
