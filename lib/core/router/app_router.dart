import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_flow.dart';
import '../../features/call/call_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/profile_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../session/session_controller.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const otp = '/otp';
  static const profile = '/profile';
  static const home = '/home';
  static const editProfile = '/edit-profile';
  static const call = '/call';

  /// Screens a logged-out user may open.
  static const publicRoutes = <String>{login, otp, profile};
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
          if (!isPublic) return AppRoutes.login;
          // The code and profile screens only make sense in the middle of a login attempt
          // (e.g. not after the app was restarted on them).
          final flow = ref.read(authFlowProvider);
          if (location == AppRoutes.otp && flow.phone == null) return AppRoutes.login;
          if (location == AppRoutes.profile) {
            if (flow.phone == null) return AppRoutes.login;
            if (flow.otp == null) return AppRoutes.otp;
          }
          return null;
        case SessionStatus.authenticated:
          return (location == AppRoutes.splash || isPublic) ? AppRoutes.home : null;
      }
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.otp, builder: (_, __) => const OtpScreen()),
      GoRoute(path: AppRoutes.profile, builder: (_, __) => const ProfileScreen()),
      GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
      GoRoute(path: AppRoutes.call, builder: (_, __) => const CallScreen()),
      GoRoute(path: AppRoutes.editProfile, builder: (_, __) => const EditProfileScreen()),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
