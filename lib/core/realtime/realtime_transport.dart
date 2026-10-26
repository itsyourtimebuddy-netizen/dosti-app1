import 'package:socket_io_client/socket_io_client.dart' as sio;

/// What the app wants to hear from the live connection.
class RealtimeListener {
  const RealtimeListener({
    required this.onConnected,
    required this.onDisconnected,
    required this.onError,
    required this.onOnlineCount,
    required this.onEvent,
  });

  final void Function() onConnected;
  final void Function() onDisconnected;
  final void Function(String message) onError;
  final void Function(int count) onOnlineCount;

  /// Every other server event the app subscribes to (see [RealtimeEvents.incoming]).
  final void Function(String event, dynamic data) onEvent;
}

/// Event names used between the app and the backend's Socket.IO server.
class RealtimeEvents {
  RealtimeEvents._();

  // app -> server
  static const startMatch = 'start_match';
  static const cancelMatch = 'cancel_match';

  // server -> app
  static const matchStatus = 'match_status';
  static const matchFound = 'match_found';
  static const matchError = 'match_error';
  static const incoming = [matchStatus, matchFound, matchError];
}

/// The wire underneath the live connection. Kept behind an interface so tests (and later
/// steps) never need a real server.
abstract class RealtimeTransport {
  void connect({required String url, required String token, required RealtimeListener listener});
  void disconnect();

  /// Sends an event to the server. Returns false when there is no live connection to send on.
  bool emit(String event, [Object? data]);
}

/// Socket.IO implementation. The backend reads the JWT from the handshake's `auth.token`.
class SocketIoTransport implements RealtimeTransport {
  sio.Socket? _socket;

  @override
  void connect({required String url, required String token, required RealtimeListener listener}) {
    disconnect();

    final socket = sio.io(
      url,
      sio.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) => listener.onConnected());
    socket.onDisconnect((_) => listener.onDisconnected());
    socket.onConnectError((error) => listener.onError('$error'));
    socket.on('online_count', (data) {
      if (data is num) listener.onOnlineCount(data.toInt());
    });

    for (final event in RealtimeEvents.incoming) {
      socket.on(event, (data) => listener.onEvent(event, data));
    }

    _socket = socket;
    socket.connect();
  }

  @override
  bool emit(String event, [Object? data]) {
    final socket = _socket;
    if (socket == null || !socket.connected) return false;
    socket.emit(event, data);
    return true;
  }

  @override
  void disconnect() {
    final socket = _socket;
    _socket = null;
    if (socket == null) return;
    socket.disconnect();
    socket.dispose();
  }
}
