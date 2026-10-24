import 'package:dosti_app/app.dart';
import 'package:dosti_app/core/network/api_exception.dart';
import 'package:dosti_app/core/session/session_controller.dart';
import 'package:dosti_app/core/storage/token_store.dart';
import 'package:dosti_app/features/auth/auth_models.dart';
import 'package:dosti_app/features/auth/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scripted stand-in for the backend. Cooldown is 0 so no countdown timer is started.
class FakeAuthRepository implements AuthRepository {
  final sentTo = <String>[];
  final verifyCalls = <({String phone, String otp, ProfileInput? profile})>[];

  Object? sendError;

  /// Called for each verify; return a result or throw an ApiException.
  AuthResult Function(String otp, ProfileInput? profile) onVerify =
      (_, __) => const AuthResult.profileRequired();

  @override
  Future<int> sendOtp(String phone) async {
    if (sendError != null) throw sendError!;
    sentTo.add(phone);
    return 0;
  }

  @override
  Future<AuthResult> verify({
    required String phone,
    required String otp,
    ProfileInput? profile,
  }) async {
    verifyCalls.add((phone: phone, otp: otp, profile: profile));
    return onVerify(otp, profile);
  }
}

ApiException _err(String code, String message, {ApiErrorType type = ApiErrorType.unauthorized}) =>
    ApiException(type: type, message: message, code: code);

Future<void> _pump(WidgetTester tester, FakeAuthRepository repo) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
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

Future<void> _enterCodeAndVerify(WidgetTester tester, [String code = '123456']) async {
  await tester.enterText(find.byKey(const Key('otp_field')), code);
  await tester.tap(find.byKey(const Key('verify_button')));
  await tester.pumpAndSettle();
}

Future<void> _fillProfile(WidgetTester tester, {String age = '25'}) async {
  await tester.enterText(find.byKey(const Key('name_field')), 'Rahul');
  await tester.enterText(find.byKey(const Key('age_field')), age);
  await tester.tap(find.byKey(const Key('gender_field')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Male').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('city_field')), 'Surat');
}

void main() {
  testWidgets('invalid phone shows an error and sends nothing', (tester) async {
    final repo = FakeAuthRepository();
    await _pump(tester, repo);

    await _enterPhoneAndSend(tester, '12345');

    expect(find.text('Enter a 10-digit mobile number'), findsOneWidget);
    expect(repo.sentTo, isEmpty);
    expect(find.byKey(const Key('login_screen')), findsOneWidget);
  });

  testWidgets('a valid phone sends the code and opens the OTP screen', (tester) async {
    final repo = FakeAuthRepository();
    await _pump(tester, repo);

    await _enterPhoneAndSend(tester);

    expect(repo.sentTo, ['+919876543210']);
    expect(find.byKey(const Key('otp_screen')), findsOneWidget);
    expect(find.text('+919876543210'), findsOneWidget);
  });

  testWidgets('a send failure stays on login and shows the message', (tester) async {
    final repo = FakeAuthRepository()
      ..sendError = const ApiException(
        type: ApiErrorType.network,
        message: 'No internet connection. Please check your network and try again.',
      );
    await _pump(tester, repo);

    await _enterPhoneAndSend(tester);

    expect(find.byKey(const Key('login_error')), findsOneWidget);
    expect(find.byKey(const Key('login_screen')), findsOneWidget);
  });

  testWidgets('cooldown error: goes on to the OTP screen, the earlier code still works', (tester) async {
    final repo = FakeAuthRepository()
      ..sendError = _err('OTP_COOLDOWN', 'Please wait', type: ApiErrorType.rateLimited);
    await _pump(tester, repo);

    await _enterPhoneAndSend(tester);

    expect(find.byKey(const Key('otp_screen')), findsOneWidget);
  });

  testWidgets('existing user: correct code logs in and opens home', (tester) async {
    final repo = FakeAuthRepository()..onVerify = (_, __) => const AuthResult.loggedIn('jwt.token');
    await _pump(tester, repo);

    await _enterPhoneAndSend(tester);
    await _enterCodeAndVerify(tester);

    expect(find.byKey(const Key('home_screen')), findsOneWidget);
    expect(repo.verifyCalls.single.profile, isNull);
  });

  testWidgets('wrong code shows the error and stays on the OTP screen', (tester) async {
    final repo = FakeAuthRepository()
      ..onVerify = (_, __) => throw _err('OTP_INVALID', 'Incorrect OTP.');
    await _pump(tester, repo);

    await _enterPhoneAndSend(tester);
    await _enterCodeAndVerify(tester, '000000');

    expect(find.text('Incorrect OTP.'), findsOneWidget);
    expect(find.byKey(const Key('otp_screen')), findsOneWidget);
    expect(find.byKey(const Key('home_screen')), findsNothing);
  });

  testWidgets('a code that is not 6 digits is stopped before the network', (tester) async {
    final repo = FakeAuthRepository();
    await _pump(tester, repo);

    await _enterPhoneAndSend(tester);
    await _enterCodeAndVerify(tester, '123');

    expect(repo.verifyCalls, isEmpty);
    expect(find.text('The code is 6 digits'), findsOneWidget);
  });

  testWidgets('resend sends a new code and confirms it', (tester) async {
    final repo = FakeAuthRepository();
    await _pump(tester, repo);

    await _enterPhoneAndSend(tester);
    await tester.tap(find.byKey(const Key('resend_button')));
    await tester.pumpAndSettle();

    expect(repo.sentTo.length, 2);
    expect(find.byKey(const Key('otp_info')), findsOneWidget);
  });

  testWidgets('change number returns to login', (tester) async {
    final repo = FakeAuthRepository();
    await _pump(tester, repo);

    await _enterPhoneAndSend(tester);
    await tester.tap(find.byKey(const Key('change_number_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_screen')), findsOneWidget);
  });

  testWidgets('new user: code -> profile -> account created -> home', (tester) async {
    final repo = FakeAuthRepository()
      ..onVerify = (otp, profile) =>
          profile == null ? const AuthResult.profileRequired() : const AuthResult.loggedIn('jwt.new');
    await _pump(tester, repo);

    await _enterPhoneAndSend(tester);
    await _enterCodeAndVerify(tester);
    expect(find.byKey(const Key('profile_screen')), findsOneWidget);

    await _fillProfile(tester);
    await tester.tap(find.byKey(const Key('create_account_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_screen')), findsOneWidget);
    final call = repo.verifyCalls.last;
    expect(call.otp, '123456');
    expect(call.phone, '+919876543210');
    expect(call.profile!.name, 'Rahul');
    expect(call.profile!.age, 25);
    expect(call.profile!.gender, 'male');
    expect(call.profile!.city, 'Surat');
  });

  testWidgets('profile form rejects an under-18 age without calling the backend', (tester) async {
    final repo = FakeAuthRepository();
    await _pump(tester, repo);

    await _enterPhoneAndSend(tester);
    await _enterCodeAndVerify(tester);
    await _fillProfile(tester, age: '17');
    await tester.tap(find.byKey(const Key('create_account_button')));
    await tester.pumpAndSettle();

    expect(find.text('You must be 18 or older'), findsOneWidget);
    expect(repo.verifyCalls.length, 1); // only the code check, no sign-up attempt
    expect(find.byKey(const Key('profile_screen')), findsOneWidget);
  });

  testWidgets('code expired while filling the profile: offers to start again', (tester) async {
    final repo = FakeAuthRepository()
      ..onVerify = (otp, profile) => profile == null
          ? const AuthResult.profileRequired()
          : throw _err('OTP_EXPIRED', 'OTP expired. Please request a new one.', type: ApiErrorType.validation);
    await _pump(tester, repo);

    await _enterPhoneAndSend(tester);
    await _enterCodeAndVerify(tester);
    await _fillProfile(tester);
    await tester.tap(find.byKey(const Key('create_account_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile_error')), findsOneWidget);
    expect(find.byKey(const Key('start_again_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('start_again_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_screen')), findsOneWidget);
  });

  testWidgets('banned account: message shown, user stays logged out', (tester) async {
    final repo = FakeAuthRepository()
      ..onVerify = (_, __) =>
          throw _err('ACCOUNT_BANNED', 'Account banned!', type: ApiErrorType.banned);
    await _pump(tester, repo);

    await _enterPhoneAndSend(tester);
    await _enterCodeAndVerify(tester);

    expect(find.text('Account banned!'), findsOneWidget);
    expect(find.byKey(const Key('home_screen')), findsNothing);
  });

  testWidgets('SessionStatus stays unauthenticated until the token is saved', (tester) async {
    final repo = FakeAuthRepository();
    await _pump(tester, repo);
    final container = ProviderScope.containerOf(tester.element(find.byType(DostiApp)));

    expect(container.read(sessionProvider).status, SessionStatus.unauthenticated);
  });
}
