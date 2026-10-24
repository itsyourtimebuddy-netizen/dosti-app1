import 'package:flutter/material.dart';

import '../../core/realtime/realtime_controller.dart';

/// Coin balance shown in the top bar.
class CoinChip extends StatelessWidget {
  const CoinChip({super.key, required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('coin_chip'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, size: 18, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            '$coins',
            key: const Key('coin_balance'),
            style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}

/// Small dot: green = live connection up, amber = connecting / retrying, grey = not started.
class ConnectionDot extends StatelessWidget {
  const ConnectionDot({super.key, required this.status});

  final RealtimeStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      RealtimeStatus.connected => Colors.green,
      RealtimeStatus.connecting => Colors.amber,
      RealtimeStatus.disconnected => Colors.grey,
    };
    final label = switch (status) {
      RealtimeStatus.connected => 'Online',
      RealtimeStatus.connecting => 'Connecting',
      RealtimeStatus.disconnected => 'Offline',
    };
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Tooltip(
        message: label,
        child: Container(
          key: Key('connection_${status.name}'),
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
