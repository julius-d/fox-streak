// Riverpod wiring for app-preferences hydration (issue #055).
//
// `HomeScreen` gates its dashboard on this provider alongside
// `profileProvider`, so the persisted haptics/sound values are seeded into
// `foxHapticsEnabledProvider`/`foxSoundEnabledProvider` before *any* screen
// can read them — not just when `SettingsScreen` happens to be opened.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../widgets/widgets.dart';

/// Loads the persisted settings row once per app session and seeds
/// [foxHapticsEnabledProvider]/[foxSoundEnabledProvider] from it.
final settingsHydrationProvider = FutureProvider<void>((ref) async {
  final settings = await ref.watch(settingsRepositoryProvider).getSettings();
  ref
      .read(foxHapticsEnabledProvider.notifier)
      .setEnabled(value: settings.hapticsEnabled);
  ref
      .read(foxSoundEnabledProvider.notifier)
      .setEnabled(value: settings.soundEnabled);
});
