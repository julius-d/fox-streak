// Home dashboard (issue #012).
//
// New `main.dart` landing screen: greeting (generic by default, or
// `display_name` when set, tap-to-rename) + #011 StreakBadge + #010
// level-progress widget + FoxGoalRing (daily goal fill) + Continue button
// (derived from the latest `attempts` row's set; a "Browse sets" CTA when
// no attempts exist) + Browse sets -> unchanged LibraryScreen. Gates
// first-run onboarding on `has_onboarded`; the parental info and settings
// screens are reachable via the app bar's overflow menu (#055).
//
// Also gates the dashboard on `settingsHydrationProvider` (#055), so the
// persisted haptics/sound toggles are seeded into their providers before
// any screen (not just `SettingsScreen`) can read them.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/clock.dart';
import '../data/database.dart';
import '../data/providers.dart';
import '../library/library_screen.dart';
import '../lesson/lesson_screen.dart';
import '../settings/settings_providers.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_providers.dart';
import '../stats/xp_service.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'onboarding_screen.dart';
import 'parental_info_screen.dart';

/// Overflow-menu entry values for Home's app bar menu.
enum _HomeMenuAction { parentalInfo, settings }

/// Generic (no display name) or named time-of-day greeting.
String _greeting(AppLocalizations l10n, DateTime now, String? displayName) {
  final String? name = displayName?.trim();
  final bool hasName = name != null && name.isNotEmpty;
  if (now.hour < 12) {
    return hasName
        ? l10n.homeGreetingMorningNamed(name)
        : l10n.homeGreetingMorning;
  }
  if (now.hour < 18) {
    return hasName
        ? l10n.homeGreetingAfternoonNamed(name)
        : l10n.homeGreetingAfternoon;
  }
  return hasName
      ? l10n.homeGreetingEveningNamed(name)
      : l10n.homeGreetingEvening;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<void> settingsAsync = ref.watch(settingsHydrationProvider);
    return settingsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object e, StackTrace _) =>
          Scaffold(body: Center(child: Text(e.toString()))),
      data: (_) => const _HomeGate(),
    );
  }
}

/// Gates the dashboard on `profileProvider` once settings have hydrated
/// (split out of [HomeScreen] so each async gate stays a single `.when`).
class _HomeGate extends ConsumerWidget {
  const _HomeGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProfileStat> profileAsync = ref.watch(profileProvider);
    return profileAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object e, StackTrace _) =>
          Scaffold(body: Center(child: Text(e.toString()))),
      data: (ProfileStat profile) {
        if (!profile.hasOnboarded) {
          return OnboardingScreen(
            onDone: (String? name) async {
              final statsRepo = ref.read(statsRepositoryProvider);
              if (name != null && name.trim().isNotEmpty) {
                await statsRepo.setDisplayName(name);
              }
              await statsRepo.setOnboarded();
            },
          );
        }
        return _HomeDashboard(profile: profile);
      },
    );
  }
}

class _HomeDashboard extends ConsumerWidget {
  final ProfileStat profile;

  const _HomeDashboard({required this.profile});

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(initialName: profile.displayName),
    );
    if (result == null) return;
    await ref.read(statsRepositoryProvider).setDisplayName(result);
  }

  Future<void> _openLibrary(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const LibraryScreen()),
    );
    ref.invalidate(lastPracticedSetIdProvider);
  }

  Future<void> _onContinue(
    BuildContext context,
    WidgetRef ref,
    int? setId,
  ) async {
    if (setId == null) {
      await _openLibrary(context, ref);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            LessonScreen(setId: setId, backLabel: l10n.lessonBackToHome),
      ),
    );
    ref.invalidate(lastPracticedSetIdProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final DateTime now = ref.watch(systemClockProvider).now();
    final bool todayDone = profile.lastActiveDay == toLocalDayString(now);
    // `profile.todayXp` is only reset lazily on the next `addXp()` write
    // (see `StatsRepository.addXp`), so it can still hold a prior day's
    // value here; gate the *display* on `todayDone`, same as the streak
    // badge above.
    final int todayXp = todayDone ? profile.todayXp : 0;
    final int level = XpService.levelForXp(profile.xpTotal);
    final int lo = XpService.xpForLevel(level);
    final int hi = XpService.xpForLevel(level + 1);
    final double goalProgress = profile.dailyGoalXp <= 0
        ? 1.0
        : todayXp / profile.dailyGoalXp;
    final AsyncValue<int?> lastSetIdAsync = ref.watch(
      lastPracticedSetIdProvider,
    );

    return Scaffold(
      key: const Key('homeScreen'),
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: <Widget>[
          PopupMenuButton<_HomeMenuAction>(
            key: const Key('homeOverflowMenu'),
            tooltip: l10n.homeOverflowMenuTooltip,
            icon: const Icon(Icons.more_vert),
            onSelected: (_HomeMenuAction action) {
              switch (action) {
                case _HomeMenuAction.parentalInfo:
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const ParentalInfoScreen(),
                    ),
                  );
                case _HomeMenuAction.settings:
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
              }
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<_HomeMenuAction>>[
                  PopupMenuItem<_HomeMenuAction>(
                    key: const Key('parentalInfoMenuItem'),
                    value: _HomeMenuAction.parentalInfo,
                    child: Text(l10n.homeParentalInfoTooltip),
                  ),
                  PopupMenuItem<_HomeMenuAction>(
                    key: const Key('settingsMenuItem'),
                    value: _HomeMenuAction.settings,
                    child: Text(l10n.homeSettingsMenuItem),
                  ),
                ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(FoxSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              InkWell(
                key: const Key('homeGreeting'),
                borderRadius: const BorderRadius.all(
                  Radius.circular(FoxRadius.md),
                ),
                onTap: () => _editName(context, ref),
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: FoxButtonMetrics.minSize,
                  ),
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    button: true,
                    label: l10n.homeEditNameTooltip,
                    child: Text(
                      _greeting(l10n, now, profile.displayName),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: FoxSpacing.lg),
              StreakBadge(
                key: const Key('streakBadge'),
                streakCount: profile.streakCount,
                todayDone: todayDone,
                streakCountLabel: l10n.streakCountLabel(profile.streakCount),
                todayDoneLabel: l10n.streakTodayDoneLabel,
                semanticsLabel: todayDone
                    ? '${l10n.streakCountLabel(profile.streakCount)} '
                          '${l10n.streakTodayDoneLabel}'
                    : l10n.streakCountLabel(profile.streakCount),
              ),
              const SizedBox(height: FoxSpacing.xl),
              FoxLevelProgressBar(
                key: const Key('levelProgressBar'),
                level: level,
                progress: XpService.progressToNextLevel(profile.xpTotal),
                levelLabel: l10n.levelLabel(level),
                progressText: l10n.levelProgressText(
                  profile.xpTotal - lo,
                  hi - lo,
                ),
                semanticsLabel: l10n.levelProgressLabel,
              ),
              const SizedBox(height: FoxSpacing.xl),
              Center(
                child: FoxGoalRing(
                  key: const Key('goalRing'),
                  value: goalProgress,
                  primaryLabel: l10n.homeGoalRingXp(todayXp),
                  secondaryLabel: l10n.homeGoalRingToday,
                  semanticsLabel: l10n.homeGoalRingLabel,
                  semanticsValue: l10n.homeGoalRingValue(
                    todayXp,
                    profile.dailyGoalXp,
                  ),
                ),
              ),
              const SizedBox(height: FoxSpacing.xxl),
              // Loading and error both fall back to the safe "Browse sets"
              // action (no dead button) rather than hiding the primary CTA.
              FoxPrimaryButton(
                key: const Key('homeContinueButton'),
                label: lastSetIdAsync.asData?.value == null
                    ? l10n.homeBrowseSetsButton
                    : l10n.homeContinueButton,
                expanded: true,
                icon: Icons.play_arrow,
                onPressed: () =>
                    _onContinue(context, ref, lastSetIdAsync.asData?.value),
              ),
              const SizedBox(height: FoxSpacing.md),
              FoxSecondaryButton(
                key: const Key('homeBrowseSetsButton'),
                label: l10n.homeBrowseSetsButton,
                expanded: true,
                onPressed: () => _openLibrary(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tap-to-rename dialog for Home's greeting.
///
/// Design reason for not reusing `FoxConfirmDialog`: the kit's only dialog
/// is a confirm/cancel pattern with no text input slot, and #012's task
/// list doesn't call for a new kit-level text-entry dialog (only
/// `FoxGoalRing`) — so this stays a one-off hand-rolled `AlertDialog` built
/// from kit buttons (the item editor's own dialog was converted to a full
/// screen by #047, so it is no longer an analogous shape).
class _EditNameDialog extends StatefulWidget {
  final String? initialName;

  const _EditNameDialog({this.initialName});

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
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
      title: Text(l10n.homeEditNameDialogTitle),
      content: TextField(
        key: const Key('displayNameField'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.homeEditNameHint),
      ),
      actions: <Widget>[
        FoxSecondaryButton(
          key: const Key('cancelDisplayNameButton'),
          label: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        FoxPrimaryButton(
          key: const Key('saveDisplayNameButton'),
          label: l10n.save,
          onPressed: () => Navigator.of(context).pop(_controller.text),
        ),
      ],
    );
  }
}
