import 'package:flutter/material.dart';

import '../profile/user_models.dart';

/// Landing tab. The matching and the voice call itself are built in Step 4.
class MatchTab extends StatelessWidget {
  const MatchTab({super.key, required this.user, required this.onlineCount});

  final UserProfile user;
  final int? onlineCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Hi ${user.name}!',
              key: const Key('greeting'),
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              onlineCount == null ? 'Connecting...' : '$onlineCount people online now',
              key: const Key('online_count'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            const FilledButton(
              key: Key('start_match_button'),
              onPressed: null,
              child: Text('Find a voice match'),
            ),
            const SizedBox(height: 8),
            Text('Voice matching is coming in the next update.', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
