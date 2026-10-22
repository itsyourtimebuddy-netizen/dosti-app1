import 'package:dosti_app/app.dart';
import 'package:dosti_app/core/session/session_controller.dart';
import 'package:dosti_app/core/storage/token_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Starts the real app with an in-memory token store instead of the phone's secure storage.
Future<ProviderContainer> _pumpApp(WidgetTester tester, {String? savedToken}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore(savedToken)),
      ],
      child: const DostiApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(DostiApp)));
}

void main() {
  testWidgets('no saved login: opens the login screen', (tester) async {
    await _pumpApp(tester);

    expect(find.byKey(const Key('login_screen')), findsOneWidget);
    expect(find.byKey(const Key('home_screen')), findsNothing);
    expect(find.byKey(const Key('session_banner')), findsNothing);
  });

  testWidgets('saved login: skips login and opens home', (tester) async {
    await _pumpApp(tester, savedToken: 'saved.token');

    expect(find.byKey(const Key('home_screen')), findsOneWidget);
    expect(find.byKey(const Key('login_screen')), findsNothing);
  });

  testWidgets('logging out returns to login without a warning banner', (tester) async {
    await _pumpApp(tester, savedToken: 'saved.token');

    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_screen')), findsOneWidget);
    expect(find.byKey(const Key('session_banner')), findsNothing);
  });

  testWidgets('a banned account lands on login with an explanation', (tester) async {
    final container = await _pumpApp(tester, savedToken: 'saved.token');

    await container.read(sessionProvider.notifier).signOut(reason: SessionEndReason.banned);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_screen')), findsOneWidget);
    expect(find.byKey(const Key('session_banner')), findsOneWidget);
    expect(find.textContaining('banned'), findsOneWidget);
  });

  testWidgets('an expired session lands on login with an explanation', (tester) async {
    final container = await _pumpApp(tester, savedToken: 'saved.token');

    await container.read(sessionProvider.notifier).signOut(reason: SessionEndReason.expired);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_screen')), findsOneWidget);
    expect(find.textContaining('expired'), findsOneWidget);
  });

  testWidgets('logging in from the login screen moves to home', (tester) async {
    final container = await _pumpApp(tester);
    expect(find.byKey(const Key('login_screen')), findsOneWidget);

    await container.read(sessionProvider.notifier).signedIn('new.token');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_screen')), findsOneWidget);
  });
}
