import 'package:dosti_app/app.dart';
import 'package:dosti_app/core/network/api_exception.dart';
import 'package:dosti_app/features/auth/auth_models.dart';
import 'package:dosti_app/features/auth/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

/// Scriptable stand-in for the backend. No timers: resendIn is 0.
class FakeAuthRepository implements AuthRepository {
  bool newUser = true;
  ApiException? sendError;
  ApiException? verifyError;
  final sent = <String>[];
  final verifies = <Map<String, Object?>>[];

  @override
  Future<int> sendOtp(String phone) async {
    if (sendError != null) throw sendError!;
    sent.add(phone);
    return 0;
  }

  @override
  Future<AuthResult> verify({required String phone, required String otp, ProfileInput? profile}) async {
    verifies.add({'phone': phone, 'otp': otp, 'profile': profile});
    if (verifyError != null) throw verifyError!;
    if (newUser && profile == null) return const AuthResult.profileRequired();
    return const AuthResult.loggedIn('fake.token');
  }
}

Future<void> _pump(WidgetTester tester, FakeAuthRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...homeOverrides(),
        authRepositoryProvider.overrideWithValue(repo),
      ],
      child: const DostiApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterPhoneAndSend(WidgetTester tester, [String phone = '9876543210']) async {
  await tester.enterText(find.byKey(const Key('phone_field')), phone);
  await tester.tap(find.byKey(const Key('send_code_button')));
  await tester.pumpAndSettle();
}

Future<void> _enterOtpAndVerify(WidgetTester tester, [String otp = '123456']) async {
  await tester.enterText(find.byKey(const Key('otp_field')), otp);
  await tester.tap(find.byKey(const Key('verify_button')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an invalid phone number is rejected before anything is sent', (tester) async {
    final repo = FakeAuthRepository();
    await _pump(tester, repo);

    await _enterPhoneAndSend(tester, '12345');

    expect(find.byKey(const Key('login_screen')), findsOneWidget);
    expect(find.text('Enter a 10-digit mobile number'), findsOneWidget);
    expect(repo.sent, isEmpty);
  });

  testWidgets('a server error on send is shown and the user stays on login', (tester) async {
    final repo = FakeAuthRepository()
      ..sendError = const ApiException(type: ApiErrorType.server, message: 'Something went wrong on our side. Please try again.');
    await _pump(tester, repo);

    await _enterPhoneAndSend(tester);

    expect(find.byKey(const Key('login_screen')), findsOneWidget);
    expect(find.byKey(const Key('login_error')), findsOneWidget);
  });

  testWidgets('a code requested a moment ago (cooldown) still opens the code screen', (tester) async {
    final repo = FakeAuthRepository()
      ..sendError = const ApiException(
        type: ApiErrorType.rateLimited,
        message: 'OTP already sent.',
        statusCode: 429,
        code: AuthErrorCodes.otpCooldown,
      );
    await _pump(tester, repo);

    await _enterPhoneAndSend(tester);

    expect(find.byKey(const Key('otp_screen')), findsOneWidget);
  });

  testWidgets('existing user: phone, code, then home', (tester) async {
    final repo = FakeAuthRepository()..newUser = false;
    await _pump(tester, repo);

    await _enterPhoneAndSend(tester);
    expect(find.byKey(const Key('otp_screen')), findsOneWidget);
    expect(find.text('+919876543210'), findsOneWidget);
    expect(repo.sent, ['+919876543210']);

    await _enterOtpAndVerify(tester);
    expect(find.byKey(const Key('home_screen')), findsOneWidget);
  });

  testWidgets('new user: phone, code, profile, then home', (tester) async {
    final repo = FakeAuthRepository();
    await _pump(tester, repo);

    await _enterPhoneAndSend(tester);
    await _enterOtpAndVerify(tester);
    expect(find.byKey(const Key('profile_screen')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('name_field')), 'Rahul');
    await tester.enterText(find.byKey(const Key('age_field')), '25');
    await tester.enterText(find.byKey(const Key('city_field')), 'Surat');
    await tester.tap(find.byKey(const Key('gender_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Male').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('create_account_button')));
    await tester.tap(find.byKey(const Key('create_account_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_screen')), findsOneWidget);
    // The second call carried the same code plus the profile.
    expect(repo.verifies, hasLength(2));
    expect(repo.verifies[1]['otp'], '123456');
    final profile = repo.verifies[1]['profile'] as ProfileInput;
    expect(profile.name, 'Rahul');
    expect(profile.age, 25);
    expect(profile.gender, 'male');
    expect(profile.city, 'Surat');
  });

  testWidgets('wrong code: message shown, still on the code screen', (tester) async {
    final repo = FakeAuthRepository()
      ..verifyError = const ApiException(
        type: ApiErrorType.unauthorized,
        message: 'Incorrect OTP.',
        statusCode: 401,
        code: AuthErrorCodes.otpInvalid,
      );
    await _pump(tester, repo);
    await _enterPhoneAndSend(tester);

    await _enterOtpAndVerify(tester, '000000');

    expect(find.byKey(const Key('otp_screen')), findsOneWidget);
    expect(find.text('Incorrect OTP.'), findsOneWidget);
    expect(find.byKey(const Key('home_screen')), findsNothing);
  });

  testWidgets('a banned account stays on the code screen with the ban message', (tester) async {
    final repo = FakeAuthRepository()
      ..newUser = false
      ..verifyError = const ApiException(
        type: ApiErrorType.banned,
        message: 'Account banned!',
        statusCode: 403,
        code: 'ACCOUNT_BANNED',
      );
    await _pump(tester, repo);
    await _enterPhoneAndSend(tester);

    await _enterOtpAndVerify(tester);

    expect(find.byKey(const Key('otp_screen')), findsOneWidget);
    expect(find.text('Account banned!'), findsOneWidget);
  });

  testWidgets('a short code is rejected before anything is sent', (tester) async {
    final repo = FakeAuthRepository();
    await _pump(tester, repo);
    await _enterPhoneAndSend(tester);

    await _enterOtpAndVerify(tester, '123');

    expect(find.text('The code is 6 digits'), findsOneWidget);
    expect(repo.verifies, isEmpty);
  });

  testWidgets('resend sends a new code', (tester) async {
    final repo = FakeAuthRepository();
    await _pump(tester, repo);
    await _enterPhoneAndSend(tester);

    await tester.tap(find.byKey(const Key('resend_button')));
    await tester.pumpAndSettle();

    expect(repo.sent, ['+919876543210', '+919876543210']);
    expect(find.byKey(const Key('otp_info')), findsOneWidget);
  });

  testWidgets('change number goes back to login', (tester) async {
    final repo = FakeAuthRepository();
    await _pump(tester, repo);
    await _enterPhoneAndSend(tester);

    await tester.tap(find.byKey(const Key('change_number_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_screen')), findsOneWidget);
  });

  testWidgets('code expired while filling the profile: offers to start again', (tester) async {
    final repo = FakeAuthRepository();
    await _pump(tester, repo);
    await _enterPhoneAndSend(tester);
    await _enterOtpAndVerify(tester);

    repo.verifyError = const ApiException(
      type: ApiErrorType.validation,
      message: 'OTP expired or not requested. Please request a new one.',
      statusCode: 400,
      code: AuthErrorCodes.otpExpired,
    );
    await tester.enterText(find.byKey(const Key('name_field')), 'Rahul');
    await tester.enterText(find.byKey(const Key('age_field')), '25');
    await tester.enterText(find.byKey(const Key('city_field')), 'Surat');
    await tester.tap(find.byKey(const Key('gender_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Female').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('create_account_button')));
    await tester.tap(find.byKey(const Key('create_account_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('start_again_button')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('start_again_button')));
    await tester.tap(find.byKey(const Key('start_again_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_screen')), findsOneWidget);
  });
}
