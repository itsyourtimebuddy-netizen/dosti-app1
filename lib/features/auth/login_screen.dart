import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/router/app_router.dart';
import '../../core/session/session_controller.dart';
import 'auth_flow.dart';
import 'auth_repository.dart';
import 'auth_validators.dart';

/// First screen for a logged-out user: enter the mobile number, get an SMS code.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  bool _sending = false;
  String? _error;

  bool _checking = false;
  bool _serverOk = false;
  String? _serverResult;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_sending || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _sending = true;
      _error = null;
    });

    final phone = AuthValidators.toE164(_phoneController.text);
    try {
      final resendIn = await ref.read(authRepositoryProvider).sendOtp(phone);
      if (!mounted) return;
      ref.read(authFlowProvider.notifier).codeSent(phone, resendIn);
      context.go(AppRoutes.otp);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == AuthErrorCodes.otpCooldown) {
        // A code was sent a moment ago and is still valid: go straight to entering it.
        ref.read(authFlowProvider.notifier).codeSent(phone, 0);
        context.go(AppRoutes.otp);
        return;
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

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
            child: Form(
              key: _formKey,
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
                    'Log in or sign up with your mobile number',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    key: const Key('phone_field'),
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumberNational],
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9 \-]')),
                      LengthLimitingTextInputFormatter(13),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Mobile number',
                      prefixText: '${AuthValidators.countryCode} ',
                      border: OutlineInputBorder(),
                    ),
                    validator: AuthValidators.phone,
                    onFieldSubmitted: (_) => _sendCode(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      key: const Key('login_error'),
                      style: TextStyle(color: scheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('send_code_button'),
                    onPressed: _sending ? null : _sendCode,
                    child: _sending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send code'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'By continuing you confirm you are 18 or older.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Backend: ${AppConfig.baseUrl}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  TextButton(
                    key: const Key('check_server_button'),
                    onPressed: _checking ? null : _checkServer,
                    child: Text(_checking ? 'Checking...' : 'Test server connection'),
                  ),
                  if (_serverResult != null)
                    Text(
                      _serverResult!,
                      key: const Key('server_result'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _serverOk ? Colors.green : scheme.error),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
