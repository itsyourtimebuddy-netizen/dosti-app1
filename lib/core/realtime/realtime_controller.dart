import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/token_store.dart';
import 'realtime_transport.dart';

enum RealtimeStatus { disconnected, connecting, connected }

class RealtimeState {
  const RealtimeState({this.status = RealtimeStatus.disconnected, this.onlineCount});

  final RealtimeStatus status;

  /// How many people are online, as last broadcast by the server. Null until the first broadcast.
  final int? onlineCount;

  RealtimeState copyWith({RealtimeStatus? status, int? onlineCount}) =>
      RealtimeState(status: status ?? this.status, onlineCount: onlineCount ?? this.onlineCount);
}

final realtimeTransportProvider = Provider<RealtimeTransport>((ref) => SocketIoTransport());

/// Owns the live connection while the user is inside the app. Auto-disposed with the home area,
/// which disconnects the socket on logout. Socket.IO reconnects by itself after drops.
class RealtimeController extends AutoDisposeNotifier<RealtimeState> {
  bool _alive = true;

  @override
  RealtimeState build() {
    _alive = true;
    final transport = ref.read(realtimeTransportProvider);
    ref.onDispose(() {
      _alive = false;
      transport.disconnect();
    });
    return const RealtimeState();
  }

  void _set(RealtimeState Function(RealtimeState) change) {
    if (_alive) state = change(state);
  }

  Future<void> start() async {
    if (state.status != RealtimeStatus.disconnected) return;
    final token = await ref.read(tokenStoreProvider).read();
    if (!_alive || token == null || token.isEmpty) return;

    _set((s) => s.copyWith(status: RealtimeStatus.connecting));
    ref.read(realtimeTransportProvider).connect(
          url: AppConfig.baseUrl,
          token: token,
          listener: RealtimeListener(
            onConnected: () => _set((s) => s.copyWith(status: RealtimeStatus.connected)),
            // While the library retries, "connecting" is the honest status.
            onDisconnected: () => _set((s) => s.copyWith(status: RealtimeStatus.connecting)),
            onError: (_) => _set((s) => s.copyWith(status: RealtimeStatus.connecting)),
            onOnlineCount: (count) => _set((s) => s.copyWith(onlineCount: count)),
          ),
        );
  }

  void stop() {
    ref.read(realtimeTransportProvider).disconnect();
    _set((s) => const RealtimeState());
  }
}

final realtimeProvider =
    NotifierProvider.autoDispose<RealtimeController, RealtimeState>(RealtimeController.new);
