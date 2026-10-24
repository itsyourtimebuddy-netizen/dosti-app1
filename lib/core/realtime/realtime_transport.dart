import 'package:socket_io_client/socket_io_client.dart' as sio;

/// What the app wants to hear from the live connection.
class RealtimeListener {
  const RealtimeListener({
    required this.onConnected,
    required this.onDisconnected,
    required this.onError,
    required this.onOnlineCount,
  });

  final void Function() onConnected;
  final void Function() onDisconnected;
  final void Function(String message) onError;
  final void Function(int count) onOnlineCount;
}

/// The wire underneath the live connection. Kept behind an interface so tests (and later
/// steps) never need a real server.
abstract class RealtimeTransport {
  void connect({required String url, required String token, required RealtimeListener listener});
  void disconnect();
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

    _socket = socket;
    socket.connect();
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
