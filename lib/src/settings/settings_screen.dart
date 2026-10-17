// Settings screen (issue #055): haptics + sound toggles, persisted via
// `SettingsRepository`. Reachable from Home's overflow menu.
//
// Plain Material `SwitchListTile` per toggle — already picks up
// `FoxStreakTheme`'s M3 color scheme with no hardcoded colors, and this is
// the only screen that needs a switch (see #015 "follows" note in the
// issue).
//
// Issue #057 adds two more `ListTile`s (display name, daily XP goal), each
// opening an edit dialog on tap — mirroring Home's hand-rolled
// `_EditNameDialog` rather than introducing a new kit dialog/stepper widget.
// Both write straight through `StatsRepository`, same immediate-write
// pattern as the switches above; `profileProvider`'s stream then refreshes
// this screen and Home (greeting, goal ring) with no extra plumbing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart' show ProfileStat;
import '../data/providers.dart';
import '../stats/stats_providers.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';

/// Inclusive bounds enforced by the daily XP goal dialog — tighter than
/// `StatsRepository.updateDailyGoal`'s own `>= 0` check (see #057 decisions:
/// the stricter bound lives in the UI layer, not the repository).
const int kDailyGoalMinXp = 10;
const int kDailyGoalMaxXp = 500;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProfileStat> profileAsync = ref.watch(profileProvider);
    return profileAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object e, StackTrace _) =>
          Scaffold(body: Center(child: Text(e.toString()))),
      data: (ProfileStat profile) => _SettingsBody(profile: profile),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  final ProfileStat profile;

  const _SettingsBody({required this.profile});

  Future<void> _editDisplayName(BuildContext context, WidgetRef ref) async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (_) => _EditDisplayNameDialog(initialName: profile.displayName),
    );
    if (result == null) return;
    await ref.read(statsRepositoryProvider).setDisplayName(result);
  }

  Future<void> _editDailyGoal(BuildContext context, WidgetRef ref) async {
    final int? result = await showDialog<int>(
      context: context,
      builder: (_) => _EditDailyGoalDialog(initialGoal: profile.dailyGoalXp),
    );
    if (result == null) return;
    await ref.read(statsRepositoryProvider).updateDailyGoal(result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool hapticsEnabled = ref.watch(foxHapticsEnabledProvider);
    final bool soundEnabled = ref.watch(foxSoundEnabledProvider);
    final String? displayName = profile.displayName?.trim();
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
            ListTile(
              key: const Key('displayNameListTile'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: FoxSpacing.lg,
              ),
              title: Text(l10n.settingsDisplayNameLabel),
              subtitle: Text(
                displayName == null || displayName.isEmpty
                    ? l10n.settingsDisplayNameUnset
                    : displayName,
              ),
              onTap: () => _editDisplayName(context, ref),
            ),
            ListTile(
              key: const Key('dailyGoalListTile'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: FoxSpacing.lg,
              ),
              title: Text(l10n.settingsDailyGoalLabel),
              subtitle: Text(
                l10n.settingsDailyGoalSubtitle(profile.dailyGoalXp),
              ),
              onTap: () => _editDailyGoal(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings' own display name edit dialog — mirrors Home's `_EditNameDialog`
/// (#012), a second entry point writing through the same
/// `StatsRepository.setDisplayName` (see #057 decisions).
class _EditDisplayNameDialog extends StatefulWidget {
  final String? initialName;

  const _EditDisplayNameDialog({this.initialName});

  @override
  State<_EditDisplayNameDialog> createState() => _EditDisplayNameDialogState();
}

class _EditDisplayNameDialogState extends State<_EditDisplayNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.settingsDisplayNameDialogTitle),
      content: TextField(
        key: const Key('settingsDisplayNameField'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.settingsDisplayNameHint),
      ),
      actions: <Widget>[
        FoxSecondaryButton(
          key: const Key('settingsCancelDisplayNameButton'),
          label: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        FoxPrimaryButton(
          key: const Key('settingsSaveDisplayNameButton'),
          label: l10n.save,
          onPressed: () => Navigator.of(context).pop(_controller.text),
        ),
      ],
    );
  }
}

/// Settings' daily XP goal edit dialog (#057): a numeric `TextField` whose
/// save action stays disabled until the value is a 10–500 inclusive integer
/// — stricter than the repository's own `>= 0` check.
class _EditDailyGoalDialog extends StatefulWidget {
  final int initialGoal;

  const _EditDailyGoalDialog({required this.initialGoal});

  @override
  State<_EditDailyGoalDialog> createState() => _EditDailyGoalDialogState();
}

class _EditDailyGoalDialogState extends State<_EditDailyGoalDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialGoal}');
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _parsedGoal => int.tryParse(_controller.text.trim());

  bool get _isValid {
    final int? goal = _parsedGoal;
    return goal != null && goal >= kDailyGoalMinXp && goal <= kDailyGoalMaxXp;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool showError = _controller.text.isNotEmpty && !_isValid;
    return AlertDialog(
      title: Text(l10n.settingsDailyGoalDialogTitle),
      content: TextField(
        key: const Key('settingsDailyGoalField'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: l10n.settingsDailyGoalHint,
          errorText: showError ? l10n.settingsDailyGoalValidationError : null,
        ),
      ),
      actions: <Widget>[
        FoxSecondaryButton(
          key: const Key('settingsCancelDailyGoalButton'),
          label: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        FoxPrimaryButton(
          key: const Key('settingsSaveDailyGoalButton'),
          label: l10n.save,
          onPressed: _isValid
              ? () => Navigator.of(context).pop(_parsedGoal)
              : null,
        ),
      ],
    );
  }
}
