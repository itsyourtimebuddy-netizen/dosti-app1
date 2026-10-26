import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../call/call_controller.dart';
import '../call/call_models.dart';
import '../call/mic_permission.dart';
import '../profile/user_models.dart';

/// Landing tab: the button that starts a voice match.
class MatchTab extends ConsumerStatefulWidget {
  const MatchTab({super.key, required this.user, required this.onlineCount});

  final UserProfile user;
  final int? onlineCount;

  @override
  ConsumerState<MatchTab> createState() => _MatchTabState();
}

class _MatchTabState extends ConsumerState<MatchTab> {
  bool _starting = false;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSettingsDialog() async {
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Microphone is off'),
        content: const Text('Voice calls need the microphone. Turn it on for Dosti in your phone settings.'),
        actions: [
          TextButton(
            key: const Key('mic_not_now_button'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            key: const Key('mic_open_settings_button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
    if (open == true) await ref.read(micPermissionProvider).openSettings();
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    final StartResult result;
    try {
      result = await ref.read(callProvider.notifier).startSearch();
    } finally {
      if (mounted) setState(() => _starting = false);
    }
    if (!mounted) return;

    switch (result) {
      case StartResult.started:
        context.push(AppRoutes.call);
        break;
      case StartResult.busy:
        // A call is already running: take the user back to it.
        if (ref.read(callProvider).phase != CallPhase.idle) context.push(AppRoutes.call);
        break;
      case StartResult.notConnected:
        _snack('Not connected to the server yet. Please try again in a moment.');
        break;
      case StartResult.micDenied:
        _snack('Microphone permission is needed for voice calls.');
        break;
      case StartResult.micPermanentlyDenied:
        await _openSettingsDialog();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Messages left behind by a search that ended on its own (timeout, lost connection, ...).
    ref.listen<String?>(callProvider.select((s) => s.notice), (_, notice) {
      if (notice == null) return;
      _snack(notice);
      ref.read(callProvider.notifier).clearNotice();
    });

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
              'Hi ${widget.user.name}!',
              key: const Key('greeting'),
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              widget.onlineCount == null ? 'Connecting...' : '${widget.onlineCount} people online now',
              key: const Key('online_count'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              key: const Key('start_match_button'),
              onPressed: _starting ? null : _start,
              icon: _starting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.mic),
              label: const Text('Find a voice match'),
            ),
            const SizedBox(height: 8),
            Text(
              'You will be connected to someone for a voice chat.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
