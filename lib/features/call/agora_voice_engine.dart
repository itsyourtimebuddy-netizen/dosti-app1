import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import 'voice_engine.dart';

/// Agora implementation of [VoiceEngine]. A fresh engine is created for every call and released
/// when the call ends, so nothing is left running (or holding the microphone) between calls.
class AgoraVoiceEngine implements VoiceEngine {
  final _controller = StreamController<VoiceEvent>.broadcast();
  RtcEngine? _engine;

  @override
  Stream<VoiceEvent> get events => _controller.stream;

  void _emit(VoiceEventType type, [String? message]) {
    if (!_controller.isClosed) _controller.add(VoiceEvent(type, message));
  }

  @override
  Future<void> join({
    required String appId,
    required String token,
    required String channelId,
    required int uid,
  }) async {
    await leave(); // never keep a previous engine around

    final engine = createAgoraRtcEngine();
    _engine = engine;

    await engine.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) => _emit(VoiceEventType.joined),
      onUserJoined: (connection, remoteUid, elapsed) => _emit(VoiceEventType.remoteJoined),
      onUserOffline: (connection, remoteUid, reason) => _emit(VoiceEventType.remoteLeft),
      onConnectionStateChanged: (connection, state, reason) {
        if (state == ConnectionStateType.connectionStateReconnecting) {
          _emit(VoiceEventType.reconnecting);
        } else if (state == ConnectionStateType.connectionStateConnected) {
          _emit(VoiceEventType.reconnected);
        } else if (state == ConnectionStateType.connectionStateFailed) {
          _emit(VoiceEventType.connectionFailed);
        }
      },
      onTokenPrivilegeWillExpire: (connection, token) => _emit(VoiceEventType.tokenExpiring),
      onError: (err, msg) => _emit(VoiceEventType.error, msg),
    ));

    await engine.enableAudio();
    await engine.setEnableSpeakerphone(true);
    await engine.joinChannel(
      token: token,
      channelId: channelId,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );
  }

  @override
  Future<void> setMuted(bool muted) async => _engine?.muteLocalAudioStream(muted);

  @override
  Future<void> setSpeaker(bool on) async => _engine?.setEnableSpeakerphone(on);

  @override
  Future<void> leave() async {
    final engine = _engine;
    _engine = null;
    if (engine == null) return;
    try {
      await engine.leaveChannel();
    } finally {
      await engine.release();
    }
  }

  /// Called when the app drops the provider (logout).
  void close() {
    leave();
    _controller.close();
  }
}
