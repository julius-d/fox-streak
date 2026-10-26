// Lesson summary screen (issue #005; trimmed to a dedicated summary by
// issue #078 — XP/streak/loot box each moved to their own focused screen
// in the completion sequence, this is the last one, shown always).
//
// Shows the pet celebration (#059) and score % + correct/total, then four
// next-step buttons: Home, Set overview, Redo whole set, Redo missed items
// (omitted on a perfect score). "Redo missed items" is primary when
// present (most learning-relevant next action); otherwise "Redo whole set"
// is. Button order is fixed regardless of which one is primary.

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../pet/pet_catalog.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'exercise_card.dart';

/// Summary screen shown last in the post-lesson completion sequence.
class LessonResultScreen extends StatelessWidget {
  final LessonResult result;
  final AppLocalizations l10n;
  final PetEntry pet;
  final VoidCallback onHome;
  final VoidCallback onSetOverview;
  final VoidCallback onRedoWholeSet;
  // Null omits the "Redo missed items" button entirely (perfect score —
  // nothing to redo); its presence alone decides both whether the button
  // shows and which button is primary, so the two can never disagree.
  final VoidCallback? onRedoMissedItems;

  const LessonResultScreen({
    super.key,
    required this.result,
    required this.l10n,
    required this.pet,
    required this.onHome,
    required this.onSetOverview,
    required this.onRedoWholeSet,
    this.onRedoMissedItems,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(FoxSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration wrapper for the micro-moment
              FoxCelebration(
                child: FoxPet(
                  pet: pet,
                  size: 120,
                  semanticLabel: l10n.petSemanticLabel(pet.emoji),
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
              const SizedBox(height: FoxSpacing.xxl),
              _summaryButton(
                key: 'homeButton',
                label: l10n.lessonHome,
                primary: false,
                onPressed: onHome,
              ),
              const SizedBox(height: FoxSpacing.md),
              _summaryButton(
                key: 'setOverviewButton',
                label: l10n.lessonSetOverview,
                primary: false,
                onPressed: onSetOverview,
              ),
              const SizedBox(height: FoxSpacing.md),
              _summaryButton(
                key: 'redoWholeSetButton',
                label: l10n.lessonRedoWholeSet,
                primary: onRedoMissedItems == null,
                onPressed: onRedoWholeSet,
              ),
              if (onRedoMissedItems != null) ...[
                const SizedBox(height: FoxSpacing.md),
                _summaryButton(
                  key: 'redoMissedItemsButton',
                  label: l10n.lessonRedoMissedItems,
                  primary: true,
                  onPressed: onRedoMissedItems!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryButton({
    required String key,
    required String label,
    required bool primary,
    required VoidCallback onPressed,
  }) {
    return primary
        ? FoxPrimaryButton(
            key: Key(key),
            label: label,
            expanded: true,
            onPressed: onPressed,
          )
        : FoxSecondaryButton(
            key: Key(key),
            label: label,
            expanded: true,
            onPressed: onPressed,
          );
  }
}
