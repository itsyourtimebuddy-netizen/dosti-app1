import 'package:dosti_app/app.dart';
import 'package:dosti_app/core/network/api_exception.dart';
import 'package:dosti_app/core/realtime/realtime_controller.dart';
import 'package:dosti_app/features/profile/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

Future<ProviderContainer> _pumpHome(
  WidgetTester tester, {
  FakeProfileRepository? profiles,
  FakeTransport? transport,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: homeOverrides(savedToken: 'saved.token', profiles: profiles, transport: transport),
      child: const DostiApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(DostiApp)));
}

Future<void> _openProfileTab(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tab_profile')));
  await tester.pumpAndSettle();
}

void main() {
  group('home', () {
    testWidgets('shows the coin balance and a greeting', (tester) async {
      await _pumpHome(tester);

      expect(find.byKey(const Key('home_screen')), findsOneWidget);
      expect(find.byKey(const Key('coin_balance')), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('Hi Rahul!'), findsOneWidget);
    });

    testWidgets('tabs switch between match, rooms and profile', (tester) async {
      await _pumpHome(tester);

      await tester.tap(find.byKey(const Key('tab_rooms')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rooms_placeholder')), findsOneWidget);

      await _openProfileTab(tester);
      expect(find.byKey(const Key('profile_name')), findsOneWidget);
      expect(find.text('25 - Male - Surat'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tab_match')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('greeting')), findsOneWidget);
    });

    testWidgets('a failed first load shows the message and Try again recovers', (tester) async {
      final repo = FakeProfileRepository()
        ..fetchError = const ApiException(type: ApiErrorType.network, message: 'No internet connection.');
      await _pumpHome(tester, profiles: repo);

      expect(find.byKey(const Key('home_error')), findsOneWidget);
      expect(find.text('No internet connection.'), findsOneWidget);
      expect(find.byKey(const Key('coin_chip')), findsNothing);

      repo.fetchError = null;
      await tester.tap(find.byKey(const Key('home_retry_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_error')), findsNothing);
      expect(find.text('Hi Rahul!'), findsOneWidget);
    });

    testWidgets('refreshCoins updates the balance, and a failure keeps the old one', (tester) async {
      final repo = FakeProfileRepository()..coinsOnServer = 340;
      final container = await _pumpHome(tester, profiles: repo);

      await container.read(profileProvider.notifier).refreshCoins();
      await tester.pumpAndSettle();
      expect(find.text('340'), findsOneWidget);

      repo.fetchError = null;
      // Make only the balance call fail.
      final failing = _CoinsFail(repo);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ProviderScope(
          overrides: homeOverrides(savedToken: 'saved.token', profiles: failing),
          child: const DostiApp(),
        ),
      );
      await tester.pumpAndSettle();
      final c2 = ProviderScope.containerOf(tester.element(find.byType(DostiApp)));
      await c2.read(profileProvider.notifier).refreshCoins();
      await tester.pumpAndSettle();
      expect(find.text('340'), findsOneWidget);
    });

    testWidgets('returning to the app refreshes the coin balance', (tester) async {
      final repo = FakeProfileRepository()..coinsOnServer = 500;
      await _pumpHome(tester, profiles: repo);
      expect(find.text('100'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(repo.fetchCoinsCalls, 1);
      expect(find.text('500'), findsOneWidget);
    });
  });

  group('live connection', () {
    testWidgets('connects with the saved token and shows the online count', (tester) async {
      final transport = FakeTransport();
      await _pumpHome(tester, transport: transport);

      expect(transport.connects, 1);
      expect(transport.token, 'saved.token');
      expect(find.byKey(const Key('connection_connecting')), findsOneWidget);
      expect(find.text('Connecting...'), findsOneWidget);

      transport.listener!.onConnected();
      transport.listener!.onOnlineCount(42);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('connection_connected')), findsOneWidget);
      expect(find.text('42 people online now'), findsOneWidget);
    });

    testWidgets('a dropped connection shows connecting again and recovers', (tester) async {
      final transport = FakeTransport();
      await _pumpHome(tester, transport: transport);
      transport.listener!.onConnected();
      await tester.pumpAndSettle();

      transport.listener!.onDisconnected();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('connection_connecting')), findsOneWidget);

      transport.listener!.onConnected();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('connection_connected')), findsOneWidget);
    });

    testWidgets('logging out disconnects the socket', (tester) async {
      final transport = FakeTransport();
      await _pumpHome(tester, transport: transport);
      expect(transport.disconnects, 0);

      await _openProfileTab(tester);
      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_logout_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_screen')), findsOneWidget);
      expect(transport.disconnects, greaterThanOrEqualTo(1));
    });

    testWidgets('events arriving after logout are ignored', (tester) async {
      final transport = FakeTransport();
      final container = await _pumpHome(tester, transport: transport);
      final listener = transport.listener!;

      await _openProfileTab(tester);
      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_logout_button')));
      await tester.pumpAndSettle();

      listener.onConnected();
      listener.onOnlineCount(7);
      await tester.pumpAndSettle();
      expect(container.exists(realtimeProvider), isFalse);
    });
  });

  group('logout', () {
    testWidgets('Cancel keeps the user logged in', (tester) async {
      await _pumpHome(tester);
      await _openProfileTab(tester);

      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cancel_logout_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_screen')), findsOneWidget);
      expect(find.byKey(const Key('login_screen')), findsNothing);
    });
  });

  group('edit profile', () {
    Future<void> openEdit(WidgetTester tester) async {
      await _openProfileTab(tester);
      await tester.ensureVisible(find.byKey(const Key('edit_profile_button')));
      await tester.tap(find.byKey(const Key('edit_profile_button')));
      await tester.pumpAndSettle();
    }

    testWidgets('starts with the current values', (tester) async {
      await _pumpHome(tester);
      await openEdit(tester);

      expect(find.byKey(const Key('edit_profile_screen')), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Rahul'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Surat'), findsOneWidget);
      expect(find.text('Age range: 20 - 30'), findsOneWidget);
    });

    testWidgets('saving sends the changes and the profile tab shows them', (tester) async {
      final repo = FakeProfileRepository();
      await _pumpHome(tester, profiles: repo);
      await openEdit(tester);

      await tester.enterText(find.byKey(const Key('edit_name_field')), 'Raj');
      await tester.enterText(find.byKey(const Key('edit_city_field')), 'Rajkot');
      await tester.tap(find.byKey(const Key('interest_gaming')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('save_profile_button')));
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit_profile_screen')), findsNothing);
      expect(repo.lastUpdate!.name, 'Raj');
      expect(repo.lastUpdate!.city, 'Rajkot');
      expect(repo.lastUpdate!.interests, ['music', 'comedy', 'gaming']);
      expect(find.text('Raj'), findsOneWidget);
      expect(find.text('25 - Male - Rajkot'), findsOneWidget);
    });

    testWidgets('an invalid name is blocked before sending', (tester) async {
      final repo = FakeProfileRepository();
      await _pumpHome(tester, profiles: repo);
      await openEdit(tester);

      await tester.enterText(find.byKey(const Key('edit_name_field')), 'R');
      await tester.ensureVisible(find.byKey(const Key('save_profile_button')));
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit_profile_screen')), findsOneWidget);
      expect(repo.lastUpdate, isNull);
    });

    testWidgets('removing every interest is blocked', (tester) async {
      final repo = FakeProfileRepository();
      await _pumpHome(tester, profiles: repo);
      await openEdit(tester);

      await tester.tap(find.byKey(const Key('interest_music')));
      await tester.tap(find.byKey(const Key('interest_comedy')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('save_profile_button')));
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();

      expect(find.text('Pick at least one interest.'), findsOneWidget);
      expect(repo.lastUpdate, isNull);
    });

    testWidgets('a server error is shown and the form stays open', (tester) async {
      final repo = FakeProfileRepository()
        ..updateError = const ApiException(type: ApiErrorType.server, message: 'Something went wrong on our side.');
      await _pumpHome(tester, profiles: repo);
      await openEdit(tester);

      await tester.ensureVisible(find.byKey(const Key('save_profile_button')));
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit_profile_error')), findsOneWidget);
      expect(find.byKey(const Key('edit_profile_screen')), findsOneWidget);
    });
  });
}

/// Same profile data, but the balance endpoint always fails.
class _CoinsFail extends FakeProfileRepository {
  _CoinsFail(FakeProfileRepository from) : super(profile: from.profile.copyWith(coins: 340));

  @override
  Future<int> fetchCoins() async =>
      throw const ApiException(type: ApiErrorType.network, message: 'offline');
}
