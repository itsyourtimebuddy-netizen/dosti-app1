import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/router/app_router.dart';
import '../../core/session/session_controller.dart';
import 'auth_flow.dart';
import 'auth_models.dart';
import 'auth_repository.dart';
import 'auth_validators.dart';

/// Second screen: type the 6-digit SMS code.
/// Existing users are logged in here; new users continue to the profile screen.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _verifying = false;
  bool _resending = false;
  String? _error;
  String? _info;

  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _startCountdown(ref.read(authFlowProvider).resendIn);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft = _secondsLeft - 1);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    if (_verifying || !(_formKey.currentState?.validate() ?? false)) return;
    final phone = ref.read(authFlowProvider).phone;
    if (phone == null) return;

    setState(() {
      _verifying = true;
      _error = null;
      _info = null;
    });

    final otp = _codeController.text.trim();
    try {
      final result = await ref.read(authRepositoryProvider).verify(phone: phone, otp: otp);
      if (!mounted) return;

      if (result.profileRequired) {
        ref.read(authFlowProvider.notifier).profileNeeded(otp);
        context.go(AppRoutes.profile);
        return;
      }

      ref.read(authFlowProvider.notifier).reset();
      await ref.read(sessionProvider.notifier).signedIn(result.token!);
      // The router sees the new session and moves to home by itself.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        if (AuthErrorCodes.needsNewOtp(e.code)) _codeController.clear();
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    final phone = ref.read(authFlowProvider).phone;
    if (phone == null || _resending || _secondsLeft > 0) return;

    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      final resendIn = await ref.read(authRepositoryProvider).sendOtp(phone);
      if (!mounted) return;
      _codeController.clear();
      _startCountdown(resendIn);
      setState(() => _info = 'A new code was sent.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _changeNumber() {
    ref.read(authFlowProvider.notifier).reset();
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final phone = ref.watch(authFlowProvider).phone ?? '';

    return Scaffold(
      key: const Key('otp_screen'),
      appBar: AppBar(
        leading: BackButton(onPressed: _changeNumber),
        title: const Text('Verify your number'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Enter the 6-digit code we sent to', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  phone,
                  key: const Key('otp_phone_label'),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const Key('otp_field'),
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    hintText: '------',
                    border: OutlineInputBorder(),
                  ),
                  validator: AuthValidators.otp,
                  onFieldSubmitted: (_) => _verify(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, key: const Key('otp_error'), style: TextStyle(color: scheme.error)),
                ],
                if (_info != null) ...[
                  const SizedBox(height: 12),
                  Text(_info!, key: const Key('otp_info')),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('verify_button'),
                  onPressed: _verifying ? null : _verify,
                  child: _verifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('resend_button'),
                  onPressed: (_secondsLeft > 0 || _resending) ? null : _resend,
                  child: Text(
                    _secondsLeft > 0 ? 'Resend code in ${_secondsLeft}s' : 'Resend code',
                  ),
                ),
                TextButton(
                  key: const Key('change_number_button'),
                  onPressed: _changeNumber,
                  child: const Text('Change number'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
