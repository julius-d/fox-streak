// Lesson result screen (issue #005).
//
// Shows score % + correct/total, FoxMascot celebration (lit if score > 0,
// empty on 0 — never on-fire; that belongs to #011 streak moments),
// FoxCelebration micro-moment, Practice again + Back to library buttons.
// XP/streak rows are stubs ("coming soon") — no placeholder math.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'exercise_card.dart';

/// Result screen shown when the lesson completes.
class LessonResultScreen extends ConsumerWidget {
  final LessonResult result;
  final AppLocalizations l10n;
  final VoidCallback onPracticeAgain;
  final VoidCallback onBackToLibrary;

  const LessonResultScreen({
    super.key,
    required this.result,
    required this.l10n,
    required this.onPracticeAgain,
    required this.onBackToLibrary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mascotState = result.scorePct > 0
        ? FoxMascotState.lit
        : FoxMascotState.empty;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(FoxSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration wrapper for the micro-moment
              FoxCelebration(
                child: FoxMascot(
                  state: mascotState,
                  size: 120,
                  semanticLabel: result.scorePct > 0
                      ? l10n.lessonCelebrate
                      : l10n.lessonNoScore,
                ),
              ),
              const SizedBox(height: FoxSpacing.xl),
              // Score summary
              Text(
                l10n.lessonScoreSummary(
                  result.correctCount,
                  result.itemIds.length,
                  result.scorePct,
                ),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: FoxSpacing.md),
              Text(
                '${result.correctCount} / ${result.itemIds.length}',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: FoxSpacing.xl),
              // XP / Streak stubs (coming soon — no placeholder math)
              _buildComingSoonRow(context, Icons.star, l10n.lessonXpComingSoon),
              const SizedBox(height: FoxSpacing.sm),
              _buildComingSoonRow(
                context,
                Icons.local_fire_department,
                l10n.lessonStreakComingSoon,
              ),
              const SizedBox(height: FoxSpacing.xxl),
              // Practice again button
              FoxPrimaryButton(
                key: const Key('practiceAgainButton'),
                label: l10n.lessonPracticeAgain,
                expanded: true,
                icon: Icons.refresh,
                onPressed: onPracticeAgain,
              ),
              const SizedBox(height: FoxSpacing.md),
              // Back to library button
              FoxSecondaryButton(
                key: const Key('backToLibraryButton'),
                label: l10n.lessonBackToLibrary,
                expanded: true,
                onPressed: onBackToLibrary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComingSoonRow(
    BuildContext context,
    IconData icon,
    String label,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: FoxSpacing.sm),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
