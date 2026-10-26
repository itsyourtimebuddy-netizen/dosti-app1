import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/realtime/realtime_controller.dart';
import '../../core/realtime/realtime_transport.dart';
import '../../core/session/session_controller.dart';
import '../profile/profile_controller.dart';
import 'call_models.dart';
import 'call_repository.dart';
import 'mic_permission.dart';
import 'voice_engine.dart';

/// Time limits and the clock. Overridden in tests so they do not have to wait real seconds.
class CallTimings {
  CallTimings({
    this.tick = const Duration(seconds: 1),
    this.searchTimeout = const Duration(seconds: 120),
    this.connectTimeout = const Duration(seconds: 20),
    this.partnerWait = const Duration(seconds: 45),
    DateTime Function()? clock,
  }) : _clock = clock;

  final Duration tick;

  /// Give up searching after this long.
  final Duration searchTimeout;

  /// Give up if we cannot join the voice channel within this long after a match.
  final Duration connectTimeout;

  /// Give up if the other person never joins, measured from the match.
  final Duration partnerWait;
  final DateTime Function()? _clock;

  DateTime now() => (_clock ?? DateTime.now)();
}

final callTimingsProvider = Provider<CallTimings>((ref) => CallTimings());

/// Runs the whole matching and calling flow:
/// idle -> searching -> connecting -> inCall -> ended -> idle.
///
/// Lives for the whole login session (not auto-disposed) because the call must survive
/// screen changes; it resets itself when the user logs out.
class CallController extends Notifier<CallState> {
  Timer? _ticker;
  StreamSubscription<RealtimeEvent>? _eventsSub;
  ProviderSubscription<RealtimeState>? _statusSub;
  StreamSubscription<VoiceEvent>? _voiceSub;

  DateTime? _phaseStartedAt;
  DateTime? _callStartedAt;
  bool _localJoined = false;
  Future<void>? _endRequest;

  /// Bumped on every reset, so a slow async step from an old call cannot touch a newer one.
  int _generation = 0;

  CallTimings get _timings => ref.read(callTimingsProvider);

  @override
  CallState build() {
    ref.listen<SessionState>(sessionProvider, (_, next) {
      if (next.status != SessionStatus.authenticated) _resetAfterLogout();
    });
    ref.onDispose(_stopListeners);
    return const CallState();
  }

  // --- starting and cancelling a search ------------------------------------------------

  Future<StartResult> startSearch() async {
    if (state.phase != CallPhase.idle) return StartResult.busy;
    if (!_isConnected) return StartResult.notConnected;

    final permission = await ref.read(micPermissionProvider).request();
    if (permission == MicPermission.permanentlyDenied) return StartResult.micPermanentlyDenied;
    if (permission == MicPermission.denied) return StartResult.micDenied;

    // The user may have done other things while the permission dialog was open.
    if (state.phase != CallPhase.idle) return StartResult.busy;
    if (!_isConnected) return StartResult.notConnected;

    final realtime = ref.read(realtimeProvider.notifier);
    _eventsSub = realtime.events.listen(_onRealtimeEvent);
    _statusSub = ref.container.listen<RealtimeState>(realtimeProvider, (_, next) {
      if (state.phase == CallPhase.searching && next.status != RealtimeStatus.connected) {
        _abortSearch('Connection lost. Please try again.', tellServer: false);
      }
    });

    if (!realtime.emit(RealtimeEvents.startMatch)) {
      _stopListeners();
      return StartResult.notConnected;
    }

    _phaseStartedAt = _timings.now();
    state = const CallState(phase: CallPhase.searching);
    _ensureTicker();
    return StartResult.started;
  }

  bool get _isConnected => ref.read(realtimeProvider).status == RealtimeStatus.connected;

  void cancelSearch() {
    if (state.phase != CallPhase.searching) return;
    _abortSearch(null, tellServer: true);
  }

  void _abortSearch(String? notice, {required bool tellServer}) {
    if (tellServer) ref.read(realtimeProvider.notifier).emit(RealtimeEvents.cancelMatch);
    _stopListeners();
    state = CallState(notice: notice);
  }

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }

  // --- server events --------------------------------------------------------------------

  void _onRealtimeEvent(RealtimeEvent event) {
    if (state.phase != CallPhase.searching) return; // a stale or unexpected event: ignore

    if (event.name == RealtimeEvents.matchFound) {
      final info = MatchInfo.tryParse(event.data);
      if (info == null) {
        _abortSearch('Something went wrong while matching. Please try again.', tellServer: false);
      } else if (info.agoraAppId.isEmpty) {
        _abortSearch('Voice calling is not set up on the server yet.', tellServer: false);
      } else {
        _beginCall(info);
      }
    } else if (event.name == RealtimeEvents.matchError) {
      final data = event.data;
      final code = data is Map ? data['code'] : null;
      if (code == 'ACCOUNT_BANNED') {
        ref.read(sessionProvider.notifier).signOut(reason: SessionEndReason.banned);
        return;
      }
      final message = data is Map && data['error'] is String ? data['error'] as String : null;
      _abortSearch(message ?? 'Could not start matching. Please try again.', tellServer: false);
    }
  }

  // --- the call -------------------------------------------------------------------------

  Future<void> _beginCall(MatchInfo info) async {
    final generation = _generation;
    _eventsSub?.cancel();
    _eventsSub = null;
    _statusSub?.close();
    _statusSub = null;

    _localJoined = false;
    _callStartedAt = null;
    _endRequest = null;
    _phaseStartedAt = _timings.now();
    state = CallState(phase: CallPhase.connecting, match: info);
    _ensureTicker();

    final voice = ref.read(voiceEngineProvider);
    _voiceSub = voice.events.listen(_onVoiceEvent);
    try {
      await voice.join(
        appId: info.agoraAppId,
        token: info.agoraToken,
        channelId: info.channelId,
        uid: info.agoraUid,
      );
    } catch (_) {
      if (generation == _generation) await _finish(CallEndReason.failed);
    }
  }

  void _onVoiceEvent(VoiceEvent event) {
    final phase = state.phase;
    if (phase != CallPhase.connecting && phase != CallPhase.inCall) return;

    switch (event.type) {
      case VoiceEventType.joined:
        _localJoined = true;
        break;
      case VoiceEventType.remoteJoined:
        if (phase == CallPhase.connecting) {
          _callStartedAt = _timings.now();
          state = state.copyWith(phase: CallPhase.inCall, partnerPresent: true, elapsedSeconds: 0);
        }
        break;
      case VoiceEventType.remoteLeft:
        _finish(CallEndReason.partnerLeft);
        break;
      case VoiceEventType.reconnecting:
        state = state.copyWith(reconnecting: true);
        break;
      case VoiceEventType.reconnected:
        if (state.reconnecting) state = state.copyWith(reconnecting: false);
        break;
      case VoiceEventType.connectionFailed:
        _finish(CallEndReason.connectionLost);
        break;
      case VoiceEventType.tokenExpiring:
        _finish(CallEndReason.timeLimit);
        break;
      case VoiceEventType.error:
        break; // Agora reports many recoverable errors; real failures arrive as connection events
    }
  }

  Future<void> endCall() => _finish(CallEndReason.youEnded);

  Future<void> _finish(CallEndReason reason) async {
    final match = state.match;
    if ((state.phase != CallPhase.connecting && state.phase != CallPhase.inCall) || match == null) return;

    final hadCall = state.partnerPresent;
    final seconds = hadCall && _callStartedAt != null
        ? _timings.now().difference(_callStartedAt!).inSeconds
        : 0;

    _ticker?.cancel();
    _ticker = null;
    _voiceSub?.cancel();
    _voiceSub = null;
    state = state.copyWith(
      phase: CallPhase.ended,
      endReason: reason,
      elapsedSeconds: seconds,
      reconnecting: false,
    );

    try {
      await ref.read(voiceEngineProvider).leave();
    } catch (_) {
      // Leaving can fail if the engine never started; nothing more to clean up.
    }

    // Only a call that really happened is reported (and counted) by the server.
    if (hadCall) {
      final generation = _generation;
      _endRequest = _reportEnd(match.matchId, seconds);
      await _endRequest;
      if (generation == _generation && ref.exists(profileProvider)) {
        ref.read(profileProvider.notifier).reload();
      }
    }
  }

  Future<void> _reportEnd(String matchId, int seconds) async {
    try {
      await ref.read(callRepositoryProvider).endMatch(matchId: matchId, durationSeconds: seconds);
    } on ApiException {
      // The other person's app reports the end too, and the call itself is over either way.
    }
  }

  /// Leaves the summary screen.
  void dismiss() {
    if (state.phase != CallPhase.ended) return;
    _generation++;
    _stopListeners();
    state = const CallState();
  }

  Future<void> setMuted(bool muted) async {
    if (state.phase != CallPhase.inCall && state.phase != CallPhase.connecting) return;
    state = state.copyWith(muted: muted);
    try {
      await ref.read(voiceEngineProvider).setMuted(muted);
    } catch (_) {}
  }

  Future<void> setSpeaker(bool on) async {
    if (state.phase != CallPhase.inCall && state.phase != CallPhase.connecting) return;
    state = state.copyWith(speakerOn: on);
    try {
      await ref.read(voiceEngineProvider).setSpeaker(on);
    } catch (_) {}
  }

  // --- after the call: rate, report, block (throw ApiException for the screen to show) --

  Future<void> rate(int stars) async {
    final match = state.match;
    if (match == null) return;
    await _endRequest; // the server only accepts a rating once it knows the call ended
    await ref.read(callRepositoryProvider).rate(matchId: match.matchId, stars: stars);
  }

  Future<void> report(String reason, {String? details}) async {
    final match = state.match;
    if (match == null) return;
    await ref.read(callRepositoryProvider).report(
          reportedUserId: match.partner.id,
          matchId: match.matchId,
          reason: reason,
          details: details,
        );
  }

  Future<void> block() async {
    final match = state.match;
    if (match == null) return;
    await ref.read(callRepositoryProvider).block(match.partner.id);
  }

  // --- timers and cleanup ---------------------------------------------------------------

  void _ensureTicker() {
    _ticker ??= Timer.periodic(_timings.tick, (_) => _onTick());
  }

  void _onTick() {
    final now = _timings.now();
    switch (state.phase) {
      case CallPhase.searching:
        final seconds = now.difference(_phaseStartedAt!).inSeconds;
        if (seconds >= _timings.searchTimeout.inSeconds) {
          _abortSearch('No one is available right now. Please try again in a little while.', tellServer: true);
        } else if (seconds != state.searchSeconds) {
          state = state.copyWith(searchSeconds: seconds);
        }
        break;
      case CallPhase.connecting:
        final seconds = now.difference(_phaseStartedAt!).inSeconds;
        if (!_localJoined && seconds >= _timings.connectTimeout.inSeconds) {
          _finish(CallEndReason.failed);
        } else if (_localJoined && seconds >= _timings.partnerWait.inSeconds) {
          _finish(CallEndReason.noShow);
        }
        break;
      case CallPhase.inCall:
        final seconds = now.difference(_callStartedAt!).inSeconds;
        if (seconds != state.elapsedSeconds) state = state.copyWith(elapsedSeconds: seconds);
        break;
      case CallPhase.idle:
      case CallPhase.ended:
        _ticker?.cancel();
        _ticker = null;
        break;
    }
  }

  void _stopListeners() {
    _ticker?.cancel();
    _ticker = null;
    _eventsSub?.cancel();
    _eventsSub = null;
    _statusSub?.close();
    _statusSub = null;
    _voiceSub?.cancel();
    _voiceSub = null;
  }

  void _resetAfterLogout() {
    if (state.phase == CallPhase.idle) return;
    _generation++;
    _stopListeners();
    final inVoice = state.phase == CallPhase.connecting || state.phase == CallPhase.inCall;
    state = const CallState();
    if (inVoice) {
      ref.read(voiceEngineProvider).leave().catchError((_) {});
    }
  }
}

final callProvider = NotifierProvider<CallController, CallState>(CallController.new);
