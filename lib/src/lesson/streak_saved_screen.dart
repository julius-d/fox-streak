// Streak-saved screen (issue #078), split out of the old combined lesson
// result screen so a streak advance gets its own focused moment instead of
// competing with XP/pet content. Shown only when this completion is what
// actually advanced today's streak (`StreakUpdate.isNewDay`) — see
// `LessonController.LessonState.streakIsNewDayAfterLesson` and
// `LessonScreen`'s post-lesson sequence. Reuses the streak headline +
// `StreakBadge` content unchanged from #011. Pops itself on Continue, same
// shape as `LootboxScreen`.

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
    return Scaffold(
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
    );
  }
}
