import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';

/// Placeholder. Step 3 replaces this with the real home (tabs, coins, profile).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: const Key('home_screen'),
      appBar: AppBar(title: const Text('Dosti')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('You are logged in.'),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const Key('logout_button'),
                onPressed: () => ref.read(sessionProvider.notifier).signOut(),
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
