import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/session/session_controller.dart';

/// Placeholder for step 1. Step 2 replaces the body with the phone + OTP login.
/// The server check below stays useful until then: it tells you at once whether
/// the phone can reach your backend.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _checking = false;
  bool _serverOk = false;
  String? _serverResult;

  Future<void> _checkServer() async {
    setState(() {
      _checking = true;
      _serverResult = null;
    });

    try {
      final data = await ref.read(apiClientProvider).getJson('/health');
      final mongo = data['mongo'] == true;
      final redis = data['redis'] == true;
      if (!mounted) return;
      setState(() {
        _serverOk = true;
        _serverResult = 'Server reachable\n'
            'MongoDB: ${mongo ? 'OK' : 'down'}  |  '
            'Redis: ${redis ? 'OK' : 'not connected (fallback in use)'}';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverOk = false;
        _serverResult = e.message;
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String? _bannerText(SessionEndReason? reason) {
    switch (reason) {
      case SessionEndReason.banned:
        return 'Your account has been banned. Contact support if you think this is a mistake.';
      case SessionEndReason.expired:
        return 'Your session expired. Please log in again.';
      case SessionEndReason.loggedOut:
      case null:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final banner = _bannerText(ref.watch(sessionProvider).endReason);

    return Scaffold(
      key: const Key('login_screen'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (banner != null) ...[
                  Container(
                    key: const Key('session_banner'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(banner, style: TextStyle(color: scheme.onErrorContainer)),
                  ),
                  const SizedBox(height: 24),
                ],
                Icon(Icons.favorite, size: 64, color: scheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Dosti',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Phone login arrives in the next step.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 40),
                Text(
                  'Backend: ${AppConfig.baseUrl}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('check_server_button'),
                  onPressed: _checking ? null : _checkServer,
                  child: Text(_checking ? 'Checking...' : 'Test server connection'),
                ),
                if (_serverResult != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _serverResult!,
                    key: const Key('server_result'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _serverOk ? Colors.green : scheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
