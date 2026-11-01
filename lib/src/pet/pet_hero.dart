// Shared Hero wiring for the equipped pet's flight between Home and
// PetCollectionScreen (issue #100).
import 'package:flutter/material.dart';

/// Hero tag shared by Home's pet avatar and `PetCollectionScreen`'s
/// equipped tile — constant, not keyed by pet id. Each screen renders at
/// most one `FoxPet` wrapped with this tag at a time: Home always shows the
/// equipped pet, and on the collection grid only the equipped tile is
/// wrapped (`_PetTile`'s `isEquipped` branch) even though every owned tile
/// renders a `FoxPet`. That keeps exactly one match per screen, which Hero
/// requires.
const Object equippedPetHeroTag = 'equippedPetHero';

/// Wraps [child] in a `Hero` sharing [equippedPetHeroTag], unless OS
/// reduce-motion is on — then [child] is returned bare, so Home <->
/// PetCollectionScreen navigation swaps it instantly with no flight,
/// matching `FoxPet`'s own reduce-motion convention
/// (`MediaQuery.disableAnimationsOf`, see fox_pet.dart).
Widget wrapEquippedPetHero(BuildContext context, Widget child) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  return Hero(tag: equippedPetHeroTag, child: child);
}
