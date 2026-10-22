import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_store.dart';

enum SessionStatus {
  /// App just started, still reading the saved token.
  unknown,
  authenticated,
  unauthenticated,
}

/// Why the user ended up logged out. Lets the login screen explain it.
enum SessionEndReason { loggedOut, expired, banned }

class SessionState {
  const SessionState(this.status, [this.endReason]);

  final SessionStatus status;
  final SessionEndReason? endReason;
}

/// Single source of truth for "is the user logged in?".
/// The router listens to it, and the API client signs the user out through it.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    _restore();
    return const SessionState(SessionStatus.unknown);
  }

  TokenStore get _store => ref.read(tokenStoreProvider);

  Future<void> _restore() async {
    final token = await _store.read();
    state = (token == null || token.isEmpty)
        ? const SessionState(SessionStatus.unauthenticated)
        : const SessionState(SessionStatus.authenticated);
  }

  /// Call after a successful login/registration with the token the backend returned.
  Future<void> signedIn(String token) async {
    await _store.write(token);
    state = const SessionState(SessionStatus.authenticated);
  }

  /// Safe to call many times: several requests failing at once only log out once.
  Future<void> signOut({SessionEndReason reason = SessionEndReason.loggedOut}) async {
    if (state.status == SessionStatus.unauthenticated) return;
    await _store.clear();
    state = SessionState(SessionStatus.unauthenticated, reason);
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
