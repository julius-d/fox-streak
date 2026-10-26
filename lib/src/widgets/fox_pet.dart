// Pet display widget (issue #015, retired state-painter -> collectible
// Lottie render by #059).
//
// Where the pet may appear: [FoxEmptyState] headers, result/celebration
// surfaces (#005–#009), Home's tap-to-collect target (#012/#059),
// onboarding (#012). Nowhere else without a design reason.
//
// Renders the given [PetEntry]'s Lottie animation as-is — no more
// empty/lit/on-fire state variants (#059 retired those along with
// `FoxPetState`/`_FoxPainter`; which pet is shown is a collectible
// choice now, not a mood).
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../pet/pet_catalog.dart';

/// Displays [pet]'s Lottie animation.
///
/// Plays once (`repeat: false`) rather than looping: besides being the
/// calmer choice next to static UI, a looping animation would never let
/// `tester.pumpAndSettle()` finish in widget/golden tests.
///
/// Always provide [semanticLabel] (or null for purely decorative repeats
/// next to a labelled heading) so screen readers announce the moment.
class FoxPet extends StatelessWidget {
  final PetEntry pet;
  final double size;
  final String? semanticLabel;

  const FoxPet({
    super.key,
    required this.pet,
    this.size = 96,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      child: SizedBox(
        key: Key('foxPet-${pet.id}'),
        width: size,
        height: size,
        child: Lottie.asset(pet.assetPath, repeat: false, fit: BoxFit.contain),
      ),
    );
  }
}
