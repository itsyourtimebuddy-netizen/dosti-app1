import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dosti_app/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _badResponse(int status, dynamic data) {
  final request = RequestOptions(path: '/x');
  return DioException(
    requestOptions: request,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(requestOptions: request, statusCode: status, data: data),
  );
}

void main() {
  group('ApiException.fromDio', () {
    test('429 keeps the backend message', () {
      final e = ApiException.fromDio(_badResponse(429, {'error': 'Too many OTP requests.'}));
      expect(e.type, ApiErrorType.rateLimited);
      expect(e.message, 'Too many OTP requests.');
      expect(e.isSessionEnding, isFalse);
    });

    test('401 with INVALID_TOKEN ends the session', () {
      final e = ApiException.fromDio(
        _badResponse(401, {'error': 'Invalid token!', 'code': 'INVALID_TOKEN'}),
      );
      expect(e.type, ApiErrorType.unauthorized);
      expect(e.isSessionEnding, isTrue);
    });

    test('401 with NO_TOKEN ends the session', () {
      final e = ApiException.fromDio(
        _badResponse(401, {'error': 'No token, access denied!', 'code': 'NO_TOKEN'}),
      );
      expect(e.isSessionEnding, isTrue);
    });

    test('401 without a code (wrong OTP, bad payment signature) does NOT end the session', () {
      final e = ApiException.fromDio(_badResponse(401, {'error': 'Incorrect OTP.'}));
      expect(e.type, ApiErrorType.unauthorized);
      expect(e.message, 'Incorrect OTP.');
      expect(e.isSessionEnding, isFalse);
    });

    test('403 ACCOUNT_BANNED is a ban and ends the session', () {
      final e = ApiException.fromDio(
        _badResponse(403, {'error': 'Account banned!', 'code': 'ACCOUNT_BANNED'}),
      );
      expect(e.type, ApiErrorType.banned);
      expect(e.isSessionEnding, isTrue);
    });

    test('403 without the ban code is just forbidden', () {
      final e = ApiException.fromDio(_badResponse(403, {'error': 'Nope'}));
      expect(e.type, ApiErrorType.forbidden);
      expect(e.isSessionEnding, isFalse);
    });

    test('400 validation shows the first detail', () {
      final e = ApiException.fromDio(
        _badResponse(400, {
          'error': 'Validation failed',
          'details': ['Valid phone number required', 'OTP must be 6 digits'],
        }),
      );
      expect(e.type, ApiErrorType.validation);
      expect(e.message, 'Valid phone number required');
      expect(e.details, hasLength(2));
    });

    test('404 and 409 are mapped', () {
      expect(ApiException.fromDio(_badResponse(404, {'error': 'Room not found'})).type, ApiErrorType.notFound);
      expect(ApiException.fromDio(_badResponse(409, {'error': 'Already reported'})).type, ApiErrorType.conflict);
    });

    test('500 never leaks the backend text', () {
      final e = ApiException.fromDio(
        _badResponse(500, {'error': 'connect ECONNREFUSED mongodb://admin:secret@db'}),
      );
      expect(e.type, ApiErrorType.server);
      expect(e.message, isNot(contains('secret')));
      expect(e.message, isNot(contains('mongodb')));
    });

    test('503 says the server is temporarily unavailable', () {
      final e = ApiException.fromDio(_badResponse(503, {'status': 'unavailable'}));
      expect(e.type, ApiErrorType.server);
      expect(e.message, contains('temporarily unavailable'));
    });

    test('an HTML error page does not crash the parser', () {
      final e = ApiException.fromDio(_badResponse(502, '<html>Bad gateway</html>'));
      expect(e.type, ApiErrorType.server);
    });

    test('timeouts and connection errors give friendly messages', () {
      final request = RequestOptions(path: '/x');
      final timeout = ApiException.fromDio(
        DioException(requestOptions: request, type: DioExceptionType.connectionTimeout),
      );
      final offline = ApiException.fromDio(
        DioException(requestOptions: request, type: DioExceptionType.connectionError),
      );
      final socket = ApiException.fromDio(
        DioException(
          requestOptions: request,
          type: DioExceptionType.unknown,
          error: const SocketException('Failed host lookup'),
        ),
      );
      expect(timeout.type, ApiErrorType.timeout);
      expect(offline.type, ApiErrorType.network);
      expect(socket.type, ApiErrorType.network);
    });
  });
}
