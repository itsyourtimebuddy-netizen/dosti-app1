import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import 'call_controller.dart';
import 'call_models.dart';

/// One screen for the whole flow; what it shows follows the call phase:
/// searching -> connecting -> in call -> summary.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  @override
  void initState() {
    super.initState();
    // Opened with nothing going on (for example after the call was reset): just leave.
    WidgetsBinding.instance.addPostFrameCallback((_) => _leaveIfIdle());
  }

  void _leaveIfIdle() {
    if (!mounted) return;
    if (ref.read(callProvider).phase == CallPhase.idle && context.canPop()) context.pop();
  }

  Future<void> _onBack() async {
    final controller = ref.read(callProvider.notifier);
    switch (ref.read(callProvider).phase) {
      case CallPhase.searching:
        controller.cancelSearch();
        break;
      case CallPhase.connecting:
      case CallPhase.inCall:
        final end = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('End the call?'),
            actions: [
              TextButton(
                key: const Key('keep_call_button'),
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Stay'),
              ),
              FilledButton(
                key: const Key('confirm_end_call_button'),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('End call'),
              ),
            ],
          ),
        );
        if (end == true) await controller.endCall();
        break;
      case CallPhase.ended:
        controller.dismiss();
        break;
      case CallPhase.idle:
        _leaveIfIdle();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CallPhase>(callProvider.select((s) => s.phase), (_, next) {
      if (next == CallPhase.idle) _leaveIfIdle();
    });
    final call = ref.watch(callProvider);

    final Widget body;
    switch (call.phase) {
      case CallPhase.searching:
        body = _SearchingView(seconds: call.searchSeconds);
        break;
      case CallPhase.connecting:
        body = _ConnectingView(call: call);
        break;
      case CallPhase.inCall:
        body = _InCallView(call: call);
        break;
      case CallPhase.ended:
        body = _SummaryView(call: call);
        break;
      case CallPhase.idle:
        body = const SizedBox.shrink();
        break;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        key: const Key('call_screen'),
        body: SafeArea(child: body),
      ),
    );
  }
}

class _SearchingView extends ConsumerWidget {
  const _SearchingView({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 56, width: 56, child: CircularProgressIndicator()),
            const SizedBox(height: 32),
            Text('Finding someone to talk to...', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              seconds < 15
                  ? 'This usually takes a few seconds.'
                  : 'Still searching. It is quicker when more people are online.',
              key: const Key('search_hint'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 40),
            OutlinedButton(
              key: const Key('cancel_search_button'),
              onPressed: () => ref.read(callProvider.notifier).cancelSearch(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerHeader extends StatelessWidget {
  const _PartnerHeader({required this.partner});

  final MatchPartner partner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      if (partner.age > 0) '${partner.age}',
      if (partner.city.isNotEmpty) partner.city,
    ].join(' - ');
    return Column(
      children: [
        CircleAvatar(
          radius: 52,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            partner.name.isEmpty ? '?' : partner.name.characters.first.toUpperCase(),
            style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          partner.name,
          key: const Key('partner_name'),
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (details.isNotEmpty) Text(details, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _ConnectingView extends ConsumerWidget {
  const _ConnectingView({required this.call});

  final CallState call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PartnerHeader(partner: call.match!.partner),
            const SizedBox(height: 24),
            const SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(height: 12),
            const Text('Connecting the call...', key: Key('connecting_label')),
            const SizedBox(height: 40),
            _RoundButton(
              key: const Key('end_call_button'),
              icon: Icons.call_end,
              label: 'End',
              color: Colors.red,
              onPressed: () => ref.read(callProvider.notifier).endCall(),
            ),
          ],
        ),
      ),
    );
  }
}

class _InCallView extends ConsumerWidget {
  const _InCallView({required this.call});

  final CallState call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(callProvider.notifier);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PartnerHeader(partner: call.match!.partner),
            const SizedBox(height: 24),
            Text(
              formatDuration(call.elapsedSeconds),
              key: const Key('call_timer'),
              style: theme.textTheme.headlineMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            if (call.reconnecting)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Reconnecting...',
                  key: const Key('reconnecting_label'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RoundButton(
                  key: const Key('mute_button'),
                  icon: call.muted ? Icons.mic_off : Icons.mic,
                  label: call.muted ? 'Unmute' : 'Mute',
                  color: call.muted ? Colors.orange : theme.colorScheme.primary,
                  onPressed: () => controller.setMuted(!call.muted),
                ),
                _RoundButton(
                  key: const Key('end_call_button'),
                  icon: Icons.call_end,
                  label: 'End',
                  color: Colors.red,
                  onPressed: () => controller.endCall(),
                ),
                _RoundButton(
                  key: const Key('speaker_button'),
                  icon: call.speakerOn ? Icons.volume_up : Icons.volume_down,
                  label: call.speakerOn ? 'Speaker' : 'Earpiece',
                  color: theme.colorScheme.primary,
                  onPressed: () => controller.setSpeaker(!call.speakerOn),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: onPressed,
          style: IconButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, minimumSize: const Size(64, 64)),
          icon: Icon(icon, size: 30),
        ),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SummaryView extends ConsumerStatefulWidget {
  const _SummaryView({required this.call});

  final CallState call;

  @override
  ConsumerState<_SummaryView> createState() => _SummaryViewState();
}

class _SummaryViewState extends ConsumerState<_SummaryView> {
  int? _stars;
  bool _ratingSent = false;
  bool _reported = false;
  bool _blocked = false;
  bool _busy = false;
  String? _message;

  String _title(CallEndReason? reason) {
    switch (reason) {
      case CallEndReason.partnerLeft:
        return '${widget.call.match?.partner.name ?? 'Your match'} ended the call';
      case CallEndReason.noShow:
        return 'Your match did not join';
      case CallEndReason.connectionLost:
        return 'The connection was lost';
      case CallEndReason.timeLimit:
        return 'Call time limit reached';
      case CallEndReason.failed:
        return 'Could not connect the call';
      case CallEndReason.youEnded:
      case null:
        return 'Call ended';
    }
  }

  Future<void> _run(Future<void> Function() action, {required VoidCallback onDone}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) setState(onDone);
    } on ApiException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rate(int stars) {
    setState(() => _stars = stars);
    return _run(
      () => ref.read(callProvider.notifier).rate(stars),
      onDone: () => _ratingSent = true,
    );
  }

  Future<void> _report() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Report this person'),
        children: [
          for (final entry in reportReasons.entries)
            SimpleDialogOption(
              key: Key('report_reason_${entry.key}'),
              onPressed: () => Navigator.of(ctx).pop(entry.key),
              child: Text(entry.value),
            ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    await _run(
      () => ref.read(callProvider.notifier).report(reason),
      onDone: () => _reported = true,
    );
  }

  Future<void> _block() => _run(
        () => ref.read(callProvider.notifier).block(),
        onDone: () => _blocked = true,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final call = widget.call;
    final partner = call.match?.partner;
    final hadCall = call.partnerPresent;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            _title(call.endReason),
            key: const Key('summary_title'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (hadCall) ...[
            const SizedBox(height: 8),
            Text(
              'Call length ${formatDuration(call.elapsedSeconds)}',
              key: const Key('summary_duration'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
          if (hadCall && partner != null) ...[
            const SizedBox(height: 32),
            Text(
              _ratingSent ? 'Thanks for rating!' : 'How was your chat with ${partner.name}?',
              key: const Key('rating_prompt'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    key: Key('star_$i'),
                    onPressed: (_ratingSent || _busy) ? null : () => _rate(i),
                    iconSize: 36,
                    icon: Icon(
                      (_stars ?? 0) >= i ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                  ),
              ],
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              key: const Key('summary_error'),
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          if (partner != null) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  key: const Key('report_button'),
                  onPressed: (_reported || _busy) ? null : _report,
                  icon: const Icon(Icons.flag_outlined),
                  label: Text(_reported ? 'Reported' : 'Report'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  key: const Key('block_button'),
                  onPressed: (_blocked || _busy) ? null : _block,
                  icon: const Icon(Icons.block),
                  label: Text(_blocked ? 'Blocked' : 'Block'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('done_button'),
            onPressed: () => ref.read(callProvider.notifier).dismiss(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
