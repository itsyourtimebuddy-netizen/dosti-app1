import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/realtime/realtime_controller.dart';
import '../profile/profile_controller.dart';
import '../profile/profile_tab.dart';
import 'coin_chip.dart';
import 'match_tab.dart';
import 'rooms_tab.dart';

/// The main screen after login: top bar with coin balance and connection dot, three tabs below.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;

  static const _titles = ['Match', 'Rooms', 'Profile'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(realtimeProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coins can change while the app is in the background (a gift received, a purchase confirmed
    // by the webhook), so refresh the balance when the user comes back.
    if (state == AppLifecycleState.resumed) {
      ref.read(profileProvider.notifier).refreshCoins();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    // Watching keeps the live connection alive for as long as the home area is on screen.
    final realtime = ref.watch(realtimeProvider);

    return Scaffold(
      key: const Key('home_screen'),
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          ConnectionDot(status: realtime.status),
          if (profile.valueOrNull != null) CoinChip(coins: profile.value!.coins),
          const SizedBox(width: 12),
        ],
      ),
      body: profile.when(
        skipLoadingOnReload: true,
        skipError: true,
        data: (user) => IndexedStack(
          index: _tab,
          children: [
            MatchTab(user: user, onlineCount: realtime.onlineCount),
            const RoomsTab(),
            ProfileTab(user: user),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator(key: Key('home_loading'))),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profileErrorMessage(error),
                  key: const Key('home_error'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('home_retry_button'),
                  onPressed: () => ref.read(profileProvider.notifier).reload(),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            key: Key('tab_match'),
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Match',
          ),
          NavigationDestination(
            key: Key('tab_rooms'),
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Rooms',
          ),
          NavigationDestination(
            key: Key('tab_profile'),
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
