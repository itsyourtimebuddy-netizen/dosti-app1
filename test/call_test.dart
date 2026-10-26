import 'package:dosti_app/app.dart';
import 'package:dosti_app/core/network/api_exception.dart';
import 'package:dosti_app/core/realtime/realtime_transport.dart';
import 'package:dosti_app/core/session/session_controller.dart';
import 'package:dosti_app/features/call/call_controller.dart';
import 'package:dosti_app/features/call/call_models.dart';
import 'package:dosti_app/features/call/mic_permission.dart';
import 'package:dosti_app/features/call/voice_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

/// Everything one test needs: the fakes and the running app.
class Harness {
  Harness(this.tester)
      : transport = FakeTransport(),
        voice = FakeVoiceEngine(),
        calls = FakeCallRepository(),
        mic = FakeMic(),
        clock = FakeClock();

  final WidgetTester tester;
  final FakeTransport transport;
  final FakeVoiceEngine voice;
  final FakeCallRepository calls;
  final FakeMic mic;
  final FakeClock clock;
  late final ProviderContainer container;

  static Map<String, dynamic> matchPayload({String appId = 'app123'}) => {
        'status': 'matched',
        'matchId': 'm1',
        'channelId': 'ch1',
        'agoraToken': 'tok',
        'agoraUid': 11,
        'agoraAppId': appId,
        'matchedUser': {'id': 'p1', 'name': 'Bhavin', 'age': 26, 'city': 'Rajkot'},
      };

  Future<void> open({bool connected = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: homeOverrides(
          savedToken: 'saved.token',
          transport: transport,
          voice: voice,
          calls: calls,
          mic: mic,
          clock: clock,
        ),
        child: const DostiApp(),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(tester.element(find.byType(DostiApp)));
    if (connected) {
      transport.listener!.onConnected();
      await tester.pumpAndSettle();
    }
  }

  CallState get call => container.read(callProvider);

  /// A bounded stand-in for pumpAndSettle: the searching and connecting screens show a spinner that
  /// animates forever, so "wait until nothing moves" would never finish.
  Future<void> settle() async {
    // 1.2s of fake time: long enough for the slowest page transition (Android's fade-forwards is ~0.8s).
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tapStart() async {
    await tester.tap(find.byKey(const Key('start_match_button')));
    await settle();
  }

  Future<void> tap(String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await settle();
  }

  void serverEvent(String name, dynamic data) => transport.listener!.onEvent(name, data);

  /// Search -> match found -> both people in the channel.
  Future<void> reachCall() async {
    await tapStart();
    serverEvent(RealtimeEvents.matchFound, matchPayload());
    await settle();
    voice.emit(VoiceEventType.joined);
    await settle();
    voice.emit(VoiceEventType.remoteJoined);
    await settle();
  }

  /// Moves the fake clock, then lets one tick run so the controller notices.
  Future<void> pass(Duration d) async {
    clock.advance(d);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
  }

  /// Removes the app so no timer is left running when the test ends.
  Future<void> close() async {
    await tester.pumpWidget(const SizedBox());
  }
}

void main() {
  group('starting a search', () {
    testWidgets('asks the server to match and shows the searching screen', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.tapStart();

      expect(h.transport.emitted, ['start_match']);
      expect(find.byKey(const Key('call_screen')), findsOneWidget);
      expect(find.text('Finding someone to talk to...'), findsOneWidget);
      expect(h.call.phase, CallPhase.searching);
      expect(h.mic.requests, 1);
      await h.close();
    });

    testWidgets('before the server connection is up it explains instead of searching', (tester) async {
      final h = Harness(tester);
      await h.open(connected: false);
      await h.tapStart();

      expect(find.byKey(const Key('call_screen')), findsNothing);
      expect(find.textContaining('Not connected'), findsOneWidget);
      expect(h.transport.emitted, isEmpty);
      await h.close();
    });

    testWidgets('microphone refused: a message, and no search', (tester) async {
      final h = Harness(tester)..mic.result = MicPermission.denied;
      await h.open();
      await h.tapStart();

      expect(find.textContaining('Microphone permission is needed'), findsOneWidget);
      expect(h.transport.emitted, isEmpty);
      expect(h.call.phase, CallPhase.idle);
      await h.close();
    });

    testWidgets('microphone blocked for good: offers the settings page', (tester) async {
      final h = Harness(tester)..mic.result = MicPermission.permanentlyDenied;
      await h.open();
      await h.tapStart();

      expect(find.text('Microphone is off'), findsOneWidget);
      await h.tap('mic_open_settings_button');
      expect(h.mic.settingsOpened, 1);
      expect(h.transport.emitted, isEmpty);
      await h.close();
    });

    testWidgets('Cancel leaves the queue and returns to the tabs', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.tapStart();
      await h.tap('cancel_search_button');

      expect(h.transport.emitted, ['start_match', 'cancel_match']);
      expect(find.byKey(const Key('call_screen')), findsNothing);
      expect(find.byKey(const Key('home_screen')), findsOneWidget);
      expect(h.call.phase, CallPhase.idle);
      await h.close();
    });

    testWidgets('the phone back button also cancels the search', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.tapStart();
      await tester.binding.handlePopRoute();
      await h.settle();

      expect(h.transport.emitted, ['start_match', 'cancel_match']);
      expect(find.byKey(const Key('call_screen')), findsNothing);
      await h.close();
    });

    testWidgets('gives up after two minutes and tells the user', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.tapStart();

      await h.pass(const Duration(seconds: 121));
      await h.settle();

      expect(h.transport.emitted, ['start_match', 'cancel_match']);
      expect(find.byKey(const Key('call_screen')), findsNothing);
      expect(find.textContaining('No one is available'), findsOneWidget);
      await h.close();
    });

    testWidgets('losing the server connection while searching ends the search', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.tapStart();

      h.transport.listener!.onDisconnected();
      await h.settle();

      expect(find.byKey(const Key('call_screen')), findsNothing);
      expect(find.textContaining('Connection lost'), findsOneWidget);
      expect(h.call.phase, CallPhase.idle);
      await h.close();
    });

    testWidgets('a server error while searching is shown', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.tapStart();

      h.serverEvent(RealtimeEvents.matchError, {'error': 'Something went wrong. Please try again.'});
      await h.settle();

      expect(find.byKey(const Key('call_screen')), findsNothing);
      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
      await h.close();
    });

    testWidgets('a banned account is signed out', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.tapStart();

      h.serverEvent(RealtimeEvents.matchError, {'error': 'Account banned!', 'code': 'ACCOUNT_BANNED'});
      await h.settle();

      expect(find.byKey(const Key('login_screen')), findsOneWidget);
      expect(find.textContaining('banned'), findsWidgets);
      await h.close();
    });

    testWidgets('a match_found nobody asked for is ignored', (tester) async {
      final h = Harness(tester);
      await h.open();

      h.serverEvent(RealtimeEvents.matchFound, Harness.matchPayload());
      await h.settle();

      expect(find.byKey(const Key('call_screen')), findsNothing);
      expect(h.voice.joinArgs, isNull);
      await h.close();
    });
  });

  group('a bad match_found', () {
    testWidgets('unusable payload: message instead of a crash', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.tapStart();

      h.serverEvent(RealtimeEvents.matchFound, {'matchId': 'm1'});
      await h.settle();

      expect(find.byKey(const Key('call_screen')), findsNothing);
      expect(find.textContaining('Something went wrong while matching'), findsOneWidget);
      expect(h.voice.joinArgs, isNull);
      await h.close();
    });

    testWidgets('server without Agora set up: says so', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.tapStart();

      h.serverEvent(RealtimeEvents.matchFound, Harness.matchPayload(appId: ''));
      await h.settle();

      expect(find.textContaining('not set up on the server'), findsOneWidget);
      expect(h.voice.joinArgs, isNull);
      await h.close();
    });
  });

  group('the call', () {
    testWidgets('a match joins the voice channel with the details from the server', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.tapStart();
      h.serverEvent(RealtimeEvents.matchFound, Harness.matchPayload());
      await h.settle();

      expect(h.voice.joinArgs, {'appId': 'app123', 'token': 'tok', 'channelId': 'ch1', 'uid': 11});
      expect(h.call.phase, CallPhase.connecting);
      expect(find.byKey(const Key('connecting_label')), findsOneWidget);
      expect(find.text('Bhavin'), findsOneWidget);
      await h.close();
    });

    testWidgets('when the other person joins the timer starts', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.reachCall();

      expect(h.call.phase, CallPhase.inCall);
      expect(find.text('00:00'), findsOneWidget);

      await h.pass(const Duration(seconds: 65));
      expect(find.text('01:05'), findsOneWidget);
      await h.close();
    });

    testWidgets('mute and speaker buttons reach the voice engine', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.reachCall();

      await h.tap('mute_button');
      expect(h.voice.muted, isTrue);
      expect(find.text('Unmute'), findsOneWidget);
      await h.tap('mute_button');
      expect(h.voice.muted, isFalse);

      await h.tap('speaker_button');
      expect(h.voice.speaker, isFalse);
      expect(find.text('Earpiece'), findsOneWidget);
      await h.close();
    });

    testWidgets('ending the call tells the server the length and shows the summary', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.reachCall();
      await h.pass(const Duration(seconds: 65));

      await h.tap('end_call_button');

      expect(find.text('Call ended'), findsOneWidget);
      expect(find.text('Call length 01:05'), findsOneWidget);
      expect(h.calls.ends, [('m1', 65)]);
      expect(h.voice.leaves, 1);
      await h.close();
    });

    testWidgets('the other person hanging up ends it for us too', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.reachCall();
      await h.pass(const Duration(seconds: 10));

      h.voice.emit(VoiceEventType.remoteLeft);
      await h.settle();

      expect(find.text('Bhavin ended the call'), findsOneWidget);
      expect(h.calls.ends, [('m1', 10)]);
      await h.close();
    });

    testWidgets('a failed "call ended" request does not break the summary', (tester) async {
      final h = Harness(tester)
        ..calls.endError = const ApiException(type: ApiErrorType.network, message: 'offline');
      await h.open();
      await h.reachCall();
      await h.tap('end_call_button');

      expect(find.byKey(const Key('summary_title')), findsOneWidget);
      await h.close();
    });

    testWidgets('a dropped connection shows Reconnecting and recovers', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.reachCall();

      h.voice.emit(VoiceEventType.reconnecting);
      await h.settle();
      expect(find.byKey(const Key('reconnecting_label')), findsOneWidget);

      h.voice.emit(VoiceEventType.reconnected);
      await h.settle();
      expect(find.byKey(const Key('reconnecting_label')), findsNothing);
      expect(h.call.phase, CallPhase.inCall);
      await h.close();
    });

    testWidgets('a connection that cannot recover ends the call', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.reachCall();

      h.voice.emit(VoiceEventType.connectionFailed);
      await h.settle();

      expect(find.text('The connection was lost'), findsOneWidget);
      await h.close();
    });

    testWidgets('the one-hour token running out ends the call politely', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.reachCall();

      h.voice.emit(VoiceEventType.tokenExpiring);
      await h.settle();

      expect(find.text('Call time limit reached'), findsOneWidget);
      await h.close();
    });

    testWidgets('a match that never joins is closed after a while and not counted', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.tapStart();
      h.serverEvent(RealtimeEvents.matchFound, Harness.matchPayload());
      await h.settle();
      h.voice.emit(VoiceEventType.joined);
      await h.settle();

      await h.pass(const Duration(seconds: 46));
      await h.settle();

      expect(find.text('Your match did not join'), findsOneWidget);
      expect(find.byKey(const Key('summary_duration')), findsNothing);
      expect(find.byKey(const Key('star_1')), findsNothing); // nothing to rate
      expect(h.calls.ends, isEmpty);
      await h.close();
    });

    testWidgets('failing to join the channel is reported', (tester) async {
      final h = Harness(tester)..voice.joinError = Exception('engine failed');
      await h.open();
      await h.tapStart();
      h.serverEvent(RealtimeEvents.matchFound, Harness.matchPayload());
      await h.settle();

      expect(find.text('Could not connect the call'), findsOneWidget);
      expect(h.calls.ends, isEmpty);
      await h.close();
    });

    testWidgets('never being able to join times out', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.tapStart();
      h.serverEvent(RealtimeEvents.matchFound, Harness.matchPayload());
      await h.settle();

      await h.pass(const Duration(seconds: 21));
      await h.settle();

      expect(find.text('Could not connect the call'), findsOneWidget);
      await h.close();
    });

    testWidgets('the back button asks before ending a call, and Stay keeps it', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.reachCall();

      await tester.binding.handlePopRoute();
      await h.settle();
      expect(find.text('End the call?'), findsOneWidget);

      await h.tap('keep_call_button');
      expect(h.call.phase, CallPhase.inCall);

      await tester.binding.handlePopRoute();
      await h.settle();
      await h.tap('confirm_end_call_button');
      expect(h.call.phase, CallPhase.ended);
      await h.close();
    });

    testWidgets('logging out in the middle of a call leaves the channel', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.reachCall();

      await h.container.read(sessionProvider.notifier).signOut();
      await h.settle();

      expect(find.byKey(const Key('login_screen')), findsOneWidget);
      expect(h.voice.leaves, 1);
      expect(h.call.phase, CallPhase.idle);
      await h.close();
    });
  });

  group('after the call', () {
    testWidgets('rating sends the stars once and thanks the user', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.reachCall();
      await h.tap('end_call_button');

      await h.tap('star_4');

      expect(h.calls.ratings, [('m1', 4)]);
      expect(find.text('Thanks for rating!'), findsOneWidget);
      // The stars are locked after a successful rating.
      await h.tap('star_5');
      expect(h.calls.ratings, hasLength(1));
      await h.close();
    });

    testWidgets('a rating the server refuses shows its message and can be retried', (tester) async {
      final h = Harness(tester)
        ..calls.rateError = const ApiException(
          type: ApiErrorType.conflict,
          message: 'You already rated this call.',
          statusCode: 409,
        );
      await h.open();
      await h.reachCall();
      await h.tap('end_call_button');

      await h.tap('star_2');
      expect(find.text('You already rated this call.'), findsOneWidget);
      expect(find.text('Thanks for rating!'), findsNothing);

      h.calls.rateError = null;
      await h.tap('star_2');
      expect(h.calls.ratings, [('m1', 2)]);
      await h.close();
    });

    testWidgets('reporting sends the chosen reason about the other person', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.reachCall();
      await h.tap('end_call_button');

      await h.tap('report_button');
      await h.tap('report_reason_harassment');

      expect(h.calls.reports, [('p1', 'm1', 'harassment')]);
      expect(find.text('Reported'), findsOneWidget);
      await h.close();
    });

    testWidgets('reporting twice shows the server message', (tester) async {
      final h = Harness(tester)
        ..calls.reportError = const ApiException(
          type: ApiErrorType.conflict,
          message: 'You already reported this user for this match.',
          statusCode: 409,
        );
      await h.open();
      await h.reachCall();
      await h.tap('end_call_button');

      await h.tap('report_button');
      await h.tap('report_reason_spam');

      expect(find.text('You already reported this user for this match.'), findsOneWidget);
      await h.close();
    });

    testWidgets('blocking sends the other person\'s id', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.reachCall();
      await h.tap('end_call_button');

      await h.tap('block_button');

      expect(h.calls.blocks, ['p1']);
      expect(find.text('Blocked'), findsOneWidget);
      await h.close();
    });

    testWidgets('Done returns to the tabs and a new search can start', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.reachCall();
      await h.tap('end_call_button');

      await h.tap('done_button');
      expect(find.byKey(const Key('call_screen')), findsNothing);
      expect(find.byKey(const Key('home_screen')), findsOneWidget);
      expect(h.call.phase, CallPhase.idle);
      expect(h.call.match, isNull);

      await h.tapStart();
      expect(h.call.phase, CallPhase.searching);
      expect(h.transport.emitted, ['start_match', 'start_match']);
      await h.close();
    });

    testWidgets('the phone back button on the summary also closes it', (tester) async {
      final h = Harness(tester);
      await h.open();
      await h.reachCall();
      await h.tap('end_call_button');

      await tester.binding.handlePopRoute();
      await h.settle();

      expect(find.byKey(const Key('call_screen')), findsNothing);
      expect(h.call.phase, CallPhase.idle);
      await h.close();
    });
  });
}
