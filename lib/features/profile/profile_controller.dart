import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import 'profile_repository.dart';
import 'user_models.dart';

/// Holds the logged-in user's profile and coin balance for the whole home area.
/// Auto-disposed: leaving the home area (logout) throws the data away, so the next
/// user never sees the previous user's profile.
class ProfileController extends AutoDisposeAsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() => ref.watch(profileRepositoryProvider).fetchMe();

  /// Full reload with a spinner (first load failed, or pull-to-refresh).
  Future<void> reload() async {
    state = const AsyncLoading<UserProfile>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => ref.read(profileRepositoryProvider).fetchMe());
  }

  /// Quiet refresh of just the balance (app returned to the foreground, after a purchase or gift).
  /// A failure keeps the old number: the balance is never blanked by a network blip.
  Future<void> refreshCoins() async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
      final coins = await ref.read(profileRepositoryProvider).fetchCoins();
      final latest = state.valueOrNull ?? current;
      state = AsyncData(latest.copyWith(coins: coins));
    } on ApiException {
      // keep showing the last known balance
    }
  }

  /// Saves the edit form. Throws [ApiException] so the form can show the message.
  Future<void> save(ProfileUpdate update) async {
    final saved = await ref.read(profileRepositoryProvider).updateMe(update);
    state = AsyncData(saved);
  }
}

final profileProvider =
    AsyncNotifierProvider.autoDispose<ProfileController, UserProfile>(ProfileController.new);

/// A message fit for the user from whatever the profile load threw.
String profileErrorMessage(Object error) =>
    error is ApiException ? error.message : 'Something went wrong. Please try again.';
