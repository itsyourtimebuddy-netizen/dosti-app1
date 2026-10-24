import 'package:dio/dio.dart';
import 'package:dosti_app/core/network/api_client.dart';
import 'package:dosti_app/core/network/api_exception.dart';
import 'package:dosti_app/core/storage/token_store.dart';
import 'package:dosti_app/features/auth/auth_models.dart';
import 'package:dosti_app/features/auth/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with a canned response and remembers what was sent.
class _Canned implements HttpClientAdapter {
  _Canned(this.status, this.body);
  final int status;
  final String body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

ApiAuthRepository _repo(_Canned adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
  return ApiAuthRepository(
    ApiClient(tokenStore: InMemoryTokenStore(), onSessionEnded: (_) {}, dio: dio),
  );
}

void main() {
  test('sendOtp posts the phone and returns the cooldown', () async {
    final adapter = _Canned(200, '{"message":"ok","expiresIn":300,"cooldown":45}');
    final seconds = await _repo(adapter).sendOtp('+919876543210');
    expect(seconds, 45);
    expect(adapter.last!.path, '/api/auth/send-otp');
    expect(adapter.last!.data, {'phone': '+919876543210'});
  });

  test('verify without a profile sends only phone and otp', () async {
    final adapter = _Canned(200, '{"status":"profile_required"}');
    final result = await _repo(adapter).verify(phone: '+919876543210', otp: '123456');
    expect(result.profileRequired, isTrue);
    expect(result.token, isNull);
    expect(adapter.last!.data, {'phone': '+919876543210', 'otp': '123456'});
  });

  test('verify with a profile sends the profile fields and returns the token', () async {
    final adapter = _Canned(201, '{"token":"jwt.token","user":{"id":"1"}}');
    final result = await _repo(adapter).verify(
      phone: '+919876543210',
      otp: '123456',
      profile: const ProfileInput(name: ' Rahul ', age: 25, gender: 'male', city: 'Surat '),
    );
    expect(result.profileRequired, isFalse);
    expect(result.token, 'jwt.token');
    expect(adapter.last!.data, {
      'phone': '+919876543210',
      'otp': '123456',
      'name': 'Rahul',
      'age': 25,
      'gender': 'male',
      'city': 'Surat',
    });
  });

  test('a success body without a token is an error, not a silent login', () async {
    final adapter = _Canned(200, '{"message":"hi"}');
    expect(
      () => _repo(adapter).verify(phone: '+919876543210', otp: '123456'),
      throwsA(isA<ApiException>()),
    );
  });

  test('a wrong code surfaces the backend code and does not end the session', () async {
    final adapter = _Canned(401, '{"error":"Incorrect OTP.","code":"OTP_INVALID"}');
    try {
      await _repo(adapter).verify(phone: '+919876543210', otp: '000000');
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.code, AuthErrorCodes.otpInvalid);
      expect(e.message, 'Incorrect OTP.');
      expect(e.isSessionEnding, isFalse);
    }
  });

  test('a banned account is reported as banned', () async {
    final adapter = _Canned(403, '{"error":"Account banned!","code":"ACCOUNT_BANNED"}');
    try {
      await _repo(adapter).verify(phone: '+919876543210', otp: '123456');
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.type, ApiErrorType.banned);
    }
  });

  test('needsNewOtp is true only for expired and locked-out codes', () {
    expect(AuthErrorCodes.needsNewOtp('OTP_EXPIRED'), isTrue);
    expect(AuthErrorCodes.needsNewOtp('OTP_TOO_MANY_ATTEMPTS'), isTrue);
    expect(AuthErrorCodes.needsNewOtp('OTP_INVALID'), isFalse);
    expect(AuthErrorCodes.needsNewOtp(null), isFalse);
  });
}
