// Streak-saved screen (issue #078), split out of the old combined lesson
// result screen so a streak advance gets its own focused moment instead of
// competing with XP/pet content. Shown only when this completion is what
// actually advanced today's streak (`StreakUpdate.isNewDay`) — see
// `LessonController.LessonState.streakIsNewDayAfterLesson` and
// `LessonScreen`'s post-lesson sequence. Reuses the streak headline +
// `StreakBadge` content unchanged from #011. Pops itself on Continue, same
// shape as `LootboxScreen`. Confetti burst on mount (issue #083), reusing
// `XpUpScreen`'s `_LevelUpEffects` pattern verbatim but unconditional (this
// screen is only ever shown when the streak actually advanced) and with no
// sound — see that screen's doc for why.

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';

/// Full-screen streak celebration, shown once per lesson completion that
/// advanced today's streak.
class StreakSavedScreen extends StatelessWidget {
  final int streakCount;
  final AppLocalizations l10n;

  const StreakSavedScreen({
    super.key,
    required this.streakCount,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          key: const Key('streakSavedScreen'),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(FoxSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.lessonStreakSavedHeading,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: FoxSpacing.xl),
                    FoxCelebration(
                      child: Text(
                        l10n.lessonStreakResultText(streakCount),
                        key: const Key('streakResultText'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: foxSemantics(context).flame,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: FoxSpacing.sm),
                    StreakBadge(
                      key: const Key('streakBadge'),
                      streakCount: streakCount,
                      todayDone: true,
                      streakCountLabel: l10n.streakCountLabel(streakCount),
                      todayDoneLabel: l10n.streakTodayDoneLabel,
                      semanticsLabel:
                          '${l10n.lessonStreakResultText(streakCount)} '
                          '${l10n.streakTodayDoneLabel}',
                    ),
                    const SizedBox(height: FoxSpacing.xxl),
                    FoxPrimaryButton(
                      key: const Key('streakSavedContinueButton'),
                      label: l10n.lessonContinue,
                      expanded: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const _StreakConfettiEffects(),
      ],
    );
  }
}

/// Confetti burst, triggered exactly once per `StreakSavedScreen` instance
/// (issue #083). A dedicated [State] — rather than inline logic in the
/// stateless [StreakSavedScreen] — so a stray ancestor rebuild can never
/// replay the burst; [initState] only runs once per mount. Mirrors
/// `XpUpScreen`'s `_LevelUpEffects` exactly, minus the `active` gate (this
/// screen is only ever shown when the streak genuinely advanced) and minus
/// any sound (no streak-specific chime exists — see this file's doc).
class _StreakConfettiEffects extends StatefulWidget {
  const _StreakConfettiEffects();

  @override
  State<_StreakConfettiEffects> createState() => _StreakConfettiEffectsState();
}

class _StreakConfettiEffectsState extends State<_StreakConfettiEffects> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 500),
    )..play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          key: const Key('streakSavedConfetti'),
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          numberOfParticles: 60,
        ),
      ),
    );
  }
}
