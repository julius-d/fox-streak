// Shared "wrap in a Hero unless OS reduce-motion is on" convention
// (issue #105), extracted from `pet_hero.dart`'s `wrapEquippedPetHero`
// (#100) and `fox_question_image.dart`'s `_wrapQuestionImageHero` (#103) —
// both implemented the identical 3-line pattern independently.
import 'package:flutter/material.dart';

/// Wraps [child] in a `Hero` sharing [tag], unless OS reduce-motion is on
/// — then [child] is returned bare, so the navigation it would otherwise
/// fly across swaps it instantly with no flight.
Widget wrapInReducedMotionHero(BuildContext context, Object tag, Widget child) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  return Hero(tag: tag, child: child);
}
