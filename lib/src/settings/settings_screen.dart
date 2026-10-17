// Settings screen (issue #055): haptics + sound toggles, persisted via
// `SettingsRepository`. Reachable from Home's overflow menu.
//
// Plain Material `SwitchListTile` per toggle — already picks up
// `FoxStreakTheme`'s M3 color scheme with no hardcoded colors, and this is
// the only screen that needs a switch (see #015 "follows" note in the
// issue).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/providers.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool hapticsEnabled = ref.watch(foxHapticsEnabledProvider);
    final bool soundEnabled = ref.watch(foxSoundEnabledProvider);
    return Scaffold(
      key: const Key('settingsScreen'),
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: FoxSpacing.md),
          children: <Widget>[
            SwitchListTile(
              key: const Key('hapticsSwitch'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: FoxSpacing.lg,
              ),
              title: Text(l10n.settingsHapticsLabel),
              subtitle: Text(l10n.settingsHapticsSubtitle),
              value: hapticsEnabled,
              onChanged: (bool value) async {
                ref
                    .read(foxHapticsEnabledProvider.notifier)
                    .setEnabled(value: value);
                await ref
                    .read(settingsRepositoryProvider)
                    .setHapticsEnabled(value: value);
              },
            ),
            SwitchListTile(
              key: const Key('soundSwitch'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: FoxSpacing.lg,
              ),
              title: Text(l10n.settingsSoundLabel),
              subtitle: Text(l10n.settingsSoundSubtitle),
              value: soundEnabled,
              onChanged: (bool value) async {
                ref
                    .read(foxSoundEnabledProvider.notifier)
                    .setEnabled(value: value);
                await ref
                    .read(settingsRepositoryProvider)
                    .setSoundEnabled(value: value);
              },
            ),
          ],
        ),
      ),
    );
  }
}
