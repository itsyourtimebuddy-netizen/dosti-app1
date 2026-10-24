import 'package:flutter/material.dart';

/// Audio rooms are built in Step 5.
class RoomsTab extends StatelessWidget {
  const RoomsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Audio rooms', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Join live rooms to chat with many people. Coming soon.',
              key: const Key('rooms_placeholder'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
