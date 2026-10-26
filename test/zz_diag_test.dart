import 'package:dosti_app/app.dart';
import 'package:dosti_app/features/call/call_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('DIAG pop behaviour', (tester) async {
    final transport = FakeTransport();
    await tester.pumpWidget(ProviderScope(
      overrides: homeOverrides(savedToken: 't', transport: transport),
      child: const DostiApp(),
    ));
    await tester.pumpAndSettle();
    transport.listener!.onConnected();
    await tester.pumpAndSettle();
    final log = StringBuffer();
    Future<void> step(String name) async {
      final ctx = tester.element(find.byType(Scaffold).first);
      final router = GoRouter.of(ctx);
      log.writeln('$name: routes=${router.routerDelegate.currentConfiguration.matches.length} '
          'canPop=${router.canPop()} callScreens=${find.byKey(const Key('call_screen')).evaluate().length} '
          'phase=${ProviderScope.containerOf(ctx).read(callProvider).phase}');
    }

    await tester.tap(find.byKey(const Key('start_match_button')));
    for (var i = 0; i < 10; i++) { await tester.pump(const Duration(milliseconds: 50)); }
    await step('after start');
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first)).read(callProvider.notifier).cancelSearch();
    await tester.pump();
    await step('after cancel+1 frame');
    await tester.pump();
    await step('after 2 frames');
    for (var i = 0; i < 10; i++) { await tester.pump(const Duration(milliseconds: 50)); }
    await step('after 500ms');
    try {
      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).pop();
      log.writeln('manual pop ok');
    } catch (e) {
      log.writeln('manual pop threw: $e');
    }
    for (var i = 0; i < 10; i++) { await tester.pump(const Duration(milliseconds: 50)); }
    await step('after manual pop');
    await tester.pumpWidget(const SizedBox());
    fail('DIAGNOSTIC\n$log');
  });
}
