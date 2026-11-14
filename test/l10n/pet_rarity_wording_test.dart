// Every PetRarity tier (plus "seasonal") has its own wording in both
// locales, so a new tier can't silently fall back to the select's `other`
// branch ("Common" / "You got a new pet!"). Pure-logic check, direct
// `AppLocalizationsDe`/`AppLocalizationsEn` instantiation per
// `lib/l10n/README.md` (no widget tree needed).

import 'package:flutter_test/flutter_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/l10n/app_localizations_de.dart';
import 'package:fox_streak_app/l10n/app_localizations_en.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';

void main() {
  final rarityKeys = [...PetRarity.values.map((r) => r.name), 'seasonal'];
  final locales = <String, AppLocalizations>{
    'en': AppLocalizationsEn(),
    'de': AppLocalizationsDe(),
  };

  for (final MapEntry(key: locale, value: l10n) in locales.entries) {
    group(locale, () {
      test('petRarityLabel is distinct for every rarity key', () {
        final labels = rarityKeys.map(l10n.petRarityLabel).toSet();
        expect(labels, hasLength(rarityKeys.length));
      });

      test('lootboxRevealedTitle is distinct for every rarity key and '
          'never the generic fallback', () {
        final titles = rarityKeys.map(l10n.lootboxRevealedTitle).toSet();
        expect(titles, hasLength(rarityKeys.length));
        expect(titles, isNot(contains(l10n.lootboxRevealedTitle('unknown'))));
      });
    });
  }

  test('rare reads "Rare" / "Selten"', () {
    expect(AppLocalizationsEn().petRarityLabel('rare'), 'Rare');
    expect(
      AppLocalizationsEn().lootboxRevealedTitle('rare'),
      'You got a Rare pet!',
    );
    expect(AppLocalizationsDe().petRarityLabel('rare'), 'Selten');
    expect(
      AppLocalizationsDe().lootboxRevealedTitle('rare'),
      'Du hast ein seltenes Pet bekommen!',
    );
  });
}
