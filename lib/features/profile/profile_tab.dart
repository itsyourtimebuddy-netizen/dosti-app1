import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/session/session_controller.dart';
import 'profile_controller.dart';
import 'profile_options.dart';
import 'user_models.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key, required this.user});

  final UserProfile user;

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need your mobile number and a new code to log in again.'),
        actions: [
          TextButton(
            key: const Key('cancel_logout_button'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_logout_button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(sessionProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final initial = user.name.isEmpty ? '?' : user.name.characters.first.toUpperCase();

    return RefreshIndicator(
      onRefresh: () => ref.read(profileProvider.notifier).reload(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                initial,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            key: const Key('profile_name'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            '${user.age} - ${ProfileOptions.label(user.gender)} - ${user.city}',
            key: const Key('profile_summary'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            user.phone,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _Stat(label: 'Calls', value: '${user.totalCalls}'),
              _Stat(label: 'Minutes', value: '${user.totalMinutes}'),
              _Stat(label: 'Rating', value: user.rating.toStringAsFixed(1)),
            ],
          ),
          const SizedBox(height: 20),
          Text('Interests', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (user.interests.isEmpty)
            const Text('No interests yet. Add some so we can match you better.')
          else
            Wrap(
              key: const Key('interest_chips'),
              spacing: 8,
              runSpacing: 4,
              children: [for (final i in user.interests) Chip(label: Text(ProfileOptions.label(i)))],
            ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const Key('edit_profile_button'),
            onPressed: () => context.push(AppRoutes.editProfile),
            icon: const Icon(Icons.edit),
            label: const Text('Edit profile'),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            key: const Key('logout_button'),
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
