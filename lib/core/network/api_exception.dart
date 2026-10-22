import 'dart:io' show SocketException;

import 'package:dio/dio.dart';

enum ApiErrorType {
  network,
  timeout,
  unauthorized,
  banned,
  forbidden,
  validation,
  notFound,
  conflict,
  rateLimited,
  server,
  unknown,
}

/// What every failed backend call turns into. Screens only ever catch this type,
/// and can show [message] to the user as it is.
class ApiException implements Exception {
  const ApiException({
    required this.type,
    required this.message,
    this.statusCode,
    this.code,
    this.details = const [],
  });

  final ApiErrorType type;

  /// Safe to show to the user.
  final String message;
  final int? statusCode;

  /// Machine-readable code from the backend, when it sends one (e.g. INVALID_TOKEN).
  final String? code;
  final List<String> details;

  /// True when the login itself is no longer valid, so the app must sign the user out.
  /// A plain 401 is NOT enough: a wrong OTP or a failed payment signature also answer
  /// 401, and those must keep the user logged in.
  bool get isSessionEnding =>
      type == ApiErrorType.banned ||
      (type == ApiErrorType.unauthorized && (code == 'NO_TOKEN' || code == 'INVALID_TOKEN'));

  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          type: ApiErrorType.timeout,
          message: 'The server is taking too long to respond. Please try again.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          type: ApiErrorType.network,
          message: 'No internet connection. Please check your network and try again.',
        );
      case DioExceptionType.badCertificate:
        return const ApiException(
          type: ApiErrorType.network,
          message: 'Could not make a secure connection to the server.',
        );
      case DioExceptionType.cancel:
        return const ApiException(
          type: ApiErrorType.unknown,
          message: 'The request was cancelled.',
        );
      case DioExceptionType.badResponse:
        return _fromResponse(e.response);
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return const ApiException(
            type: ApiErrorType.network,
            message: 'No internet connection. Please check your network and try again.',
          );
        }
        return const ApiException(
          type: ApiErrorType.unknown,
          message: 'Something went wrong. Please try again.',
        );
    }
  }

  static ApiException _fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode;
    final body = response?.data;

    String? backendMessage;
    String? code;
    var details = <String>[];

    // The body is normally {"error": "...", "code": "...", "details": [...]}, but a proxy
    // or crash page can return HTML, so never assume the shape.
    if (body is Map) {
      final error = body['error'];
      if (error is String && error.isNotEmpty) backendMessage = error;
      final c = body['code'];
      if (c is String && c.isNotEmpty) code = c;
      final d = body['details'];
      if (d is List) details = d.whereType<String>().toList();
    }

    ApiErrorType type;
    String message;

    if (status == 429) {
      type = ApiErrorType.rateLimited;
      message = backendMessage ?? 'Too many attempts. Please wait a moment and try again.';
    } else if (status == 401) {
      type = ApiErrorType.unauthorized;
      message = backendMessage ?? 'Please log in again.';
    } else if (status == 403) {
      type = code == 'ACCOUNT_BANNED' ? ApiErrorType.banned : ApiErrorType.forbidden;
      message = backendMessage ?? 'You do not have access to this.';
    } else if (status == 400 || status == 422) {
      type = ApiErrorType.validation;
      message = details.isNotEmpty
          ? details.first
          : (backendMessage ?? 'Please check the details and try again.');
    } else if (status == 404) {
      type = ApiErrorType.notFound;
      message = backendMessage ?? 'We could not find what you were looking for.';
    } else if (status == 409) {
      type = ApiErrorType.conflict;
      message = backendMessage ?? 'This was already done.';
    } else if (status == 503) {
      type = ApiErrorType.server;
      message = 'The server is temporarily unavailable. Please try again shortly.';
    } else if (status != null && status >= 500) {
      // Never show raw server text for 5xx: it can contain internal details.
      type = ApiErrorType.server;
      message = 'Something went wrong on our side. Please try again.';
    } else {
      type = ApiErrorType.unknown;
      message = backendMessage ?? 'Something went wrong. Please try again.';
    }

    return ApiException(
      type: type,
      message: message,
      statusCode: status,
      code: code,
      details: details,
    );
  }

  @override
  String toString() => 'ApiException($type, status: $statusCode, code: $code, $message)';
}
