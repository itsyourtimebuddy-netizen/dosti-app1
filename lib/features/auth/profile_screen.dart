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

/// Third screen, new users only: name, age, gender, city. Creates the account.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController();
  String? _gender;

  bool _saving = false;
  String? _error;
  bool _codeNoLongerValid = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final flow = ref.read(authFlowProvider);
    if (flow.phone == null || flow.otp == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final result = await ref.read(authRepositoryProvider).verify(
            phone: flow.phone!,
            otp: flow.otp!,
            profile: ProfileInput(
              name: _nameController.text,
              age: int.parse(_ageController.text.trim()),
              gender: _gender!,
              city: _cityController.text,
            ),
          );
      if (!mounted) return;

      final token = result.token;
      if (token == null) {
        // The backend still wants a profile although we sent one: do not loop, show a message.
        setState(() => _error = 'Could not create your account. Please try again.');
        return;
      }

      ref.read(authFlowProvider.notifier).reset();
      await ref.read(sessionProvider.notifier).signedIn(token);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _codeNoLongerValid = AuthErrorCodes.needsNewOtp(e.code);
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _startAgain() {
    ref.read(authFlowProvider.notifier).reset();
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      key: const Key('profile_screen'),
      appBar: AppBar(title: const Text('Create your profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your number is verified. Tell us a little about you.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const Key('name_field'),
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(50)],
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: AuthValidators.name,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('age_field'),
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Age (18+)',
                    border: OutlineInputBorder(),
                  ),
                  validator: AuthValidators.age,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('gender_field'),
                  value: _gender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) => setState(() => _gender = value),
                  validator: AuthValidators.gender,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('city_field'),
                  controller: _cityController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [LengthLimitingTextInputFormatter(50)],
                  decoration: const InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(),
                  ),
                  validator: AuthValidators.city,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    key: const Key('profile_error'),
                    style: TextStyle(color: scheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                if (_codeNoLongerValid)
                  FilledButton(
                    key: const Key('start_again_button'),
                    onPressed: _startAgain,
                    child: const Text('Start again'),
                  )
                else
                  FilledButton(
                    key: const Key('create_account_button'),
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create account'),
                  ),
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('profile_cancel_button'),
                  onPressed: _saving ? null : _startAgain,
                  child: const Text('Use a different number'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
