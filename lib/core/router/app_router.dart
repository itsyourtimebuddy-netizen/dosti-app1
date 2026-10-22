import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../session/session_controller.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const home = '/home';

  /// Screens a logged-out user may open. Later steps add the OTP and sign-up screens here.
  static const publicRoutes = <String>{login};
}

/// Tells the router to re-run its redirect whenever the login state changes.
class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    ref.listen<SessionState>(sessionProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh(ref);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;
      final isPublic = AppRoutes.publicRoutes.contains(location);

      switch (session.status) {
        case SessionStatus.unknown:
          // Still reading the saved token: stay on the splash screen.
          return location == AppRoutes.splash ? null : AppRoutes.splash;
        case SessionStatus.unauthenticated:
          return isPublic ? null : AppRoutes.login;
        case SessionStatus.authenticated:
          return (location == AppRoutes.splash || isPublic) ? AppRoutes.home : null;
      }
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
