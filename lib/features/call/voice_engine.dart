import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'agora_voice_engine.dart';

enum VoiceEventType {
  /// We are in the channel.
  joined,
  remoteJoined,
  remoteLeft,
  reconnecting,
  reconnected,

  /// The connection could not be recovered.
  connectionFailed,

  /// The token is about to run out: ask the server for a new one.
  tokenExpiring,
  error,
}

class VoiceEvent {
  const VoiceEvent(this.type, [this.message]);

  final VoiceEventType type;
  final String? message;
}

/// The voice channel behind an interface. The real one uses Agora; tests use a fake.
abstract class VoiceEngine {
  Stream<VoiceEvent> get events;

  /// Joins the channel with the microphone on. Throws if the engine cannot start.
  Future<void> join({
    required String appId,
    required String token,
    required String channelId,
    required int uid,
  });

  /// Hands the running call a fresh token (the first one lasts about an hour).
  Future<void> renewToken(String token);

  Future<void> setMuted(bool muted);
  Future<void> setSpeaker(bool on);

  /// Leaves the channel and frees the engine. Safe to call when not joined.
  Future<void> leave();
}

final voiceEngineProvider = Provider<VoiceEngine>((ref) {
  final engine = AgoraVoiceEngine();
  ref.onDispose(engine.close);
  return engine;
});
