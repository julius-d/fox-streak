// Lesson summary screen (issue #005; trimmed to a dedicated summary by
// issue #078 — XP/streak/loot box each moved to their own focused screen
// in the completion sequence, this is the last one, shown always).
//
// Shows the pet celebration (#059) and score % + correct/total, then the
// next-step buttons (issue #114): with missed items, primary "Redo missed
// items" above secondary "Home"; on a perfect score only a primary "Home".

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../pet/pet_catalog.dart';
import '../pet/pet_hero.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'exercise_card.dart';

/// Summary screen shown last in the post-lesson completion sequence.
class LessonResultScreen extends StatelessWidget {
  final LessonResult result;
  final AppLocalizations l10n;
  final PetEntry pet;
  final VoidCallback onHome;
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
                child: wrapEquippedPetHero(
                  context,
                  FoxPet(
                    pet: pet,
                    size: 120,
                    semanticLabel: l10n.petSemanticLabel(pet.emoji),
                  ),
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
              if (onRedoMissedItems != null) ...[
                _summaryButton(
                  key: 'redoMissedItemsButton',
                  label: l10n.lessonRedoMissedItems,
                  primary: true,
                  onPressed: onRedoMissedItems!,
                ),
                const SizedBox(height: FoxSpacing.md),
              ],
              _summaryButton(
                key: 'homeButton',
                label: l10n.lessonHome,
                primary: onRedoMissedItems == null,
                onPressed: onHome,
              ),
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
