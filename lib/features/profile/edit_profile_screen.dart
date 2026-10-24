import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../auth/auth_validators.dart';
import 'profile_controller.dart';
import 'profile_options.dart';
import 'user_models.dart';

/// Edit name, city, interests and match preferences. Age, gender and phone cannot be changed.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _city;
  late Set<String> _interests;
  late String _preferredGender;
  late RangeValues _ageRange;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(profileProvider).requireValue;
    _name = TextEditingController(text: user.name);
    _city = TextEditingController(text: user.city);
    _interests = {...user.interests};
    _preferredGender = ProfileOptions.preferredGenders.contains(user.preferredGender)
        ? user.preferredGender
        : 'any';
    final min = user.preferredMinAge.clamp(ProfileOptions.minAge, ProfileOptions.maxAge).toDouble();
    final max = user.preferredMaxAge.clamp(ProfileOptions.minAge, ProfileOptions.maxAge).toDouble();
    _ageRange = RangeValues(min <= max ? min : max, max);
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    if (_interests.isEmpty) {
      setState(() => _error = 'Pick at least one interest.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileProvider.notifier).save(
            ProfileUpdate(
              name: _name.text,
              city: _city.text,
              // Keep the backend's list order, not the order the user tapped in.
              interests: [for (final i in ProfileOptions.interests) if (_interests.contains(i)) i],
              preferredGender: _preferredGender,
              preferredMinAge: _ageRange.start.round(),
              preferredMaxAge: _ageRange.end.round(),
            ),
          );
      if (!mounted) return;
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: const Key('edit_profile_screen'),
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('edit_name_field'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(50)],
                  decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                  validator: AuthValidators.name,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('edit_city_field'),
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(50)],
                  decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                  validator: AuthValidators.city,
                ),
                const SizedBox(height: 24),
                Text('Interests', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final interest in ProfileOptions.interests)
                      FilterChip(
                        key: Key('interest_$interest'),
                        label: Text(ProfileOptions.label(interest)),
                        selected: _interests.contains(interest),
                        onSelected: (on) => setState(() {
                          on ? _interests.add(interest) : _interests.remove(interest);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('I want to talk to', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  key: const Key('preferred_gender'),
                  segments: const [
                    ButtonSegment(value: 'any', label: Text('Anyone')),
                    ButtonSegment(value: 'male', label: Text('Men')),
                    ButtonSegment(value: 'female', label: Text('Women')),
                  ],
                  selected: {_preferredGender},
                  onSelectionChanged: (s) => setState(() => _preferredGender = s.first),
                ),
                const SizedBox(height: 24),
                Text(
                  'Age range: ${_ageRange.start.round()} - ${_ageRange.end.round()}',
                  key: const Key('age_range_label'),
                  style: theme.textTheme.titleSmall,
                ),
                RangeSlider(
                  key: const Key('age_range_slider'),
                  values: _ageRange,
                  min: ProfileOptions.minAge.toDouble(),
                  max: ProfileOptions.maxAge.toDouble(),
                  divisions: ProfileOptions.maxAge - ProfileOptions.minAge,
                  labels: RangeLabels('${_ageRange.start.round()}', '${_ageRange.end.round()}'),
                  onChanged: (v) => setState(() => _ageRange = v),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    key: const Key('edit_profile_error'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('save_profile_button'),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
