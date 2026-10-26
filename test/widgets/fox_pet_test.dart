// Loop-with-pause coverage for `FoxPet` (issue #071): plays once, then —
// unless reduce motion is on — waits a random pause and plays again,
// indefinitely for as long as the widget stays mounted.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';
import 'package:fox_streak_app/src/widgets/fox_pet.dart';

/// Pumps [child] inside a plain [MaterialApp], optionally with reduce
/// motion forced on via `MediaQuery.disableAnimationsOf`.
Future<void> _pumpPet(
  WidgetTester tester,
  Widget child, {
  bool disableAnimations = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      builder: !disableAnimations
          ? null
          : (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  test('drawFoxPetPause always falls within [3s, 8s] across many draws', () {
    final random = Random(7);
    for (var i = 0; i < 200; i++) {
      final pause = drawFoxPetPause(random);
      expect(pause, greaterThanOrEqualTo(kFoxPetMinPause));
      expect(pause, lessThanOrEqualTo(kFoxPetMaxPause));
    }
  });

  test('drawFoxPetPause is re-rolled rather than fixed across draws', () {
    final random = Random(7);
    final draws = List.generate(20, (_) => drawFoxPetPause(random));
    expect(draws.toSet().length, greaterThan(1));
  });

  testWidgets('with reduce motion off, the pet replays after its pause, '
      'indefinitely for as long as it stays mounted', (tester) async {
    await _pumpPet(tester, FoxPet(pet: PetCatalog.defaultEntry));
    // Composition load + the first play-through (~2.1s for the default
    // entry): nothing else scheduled once it ends, well before the >=3s
    // pause even starts counting down.
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    // The pause is re-rolled in [3s, 8s] each cycle; 8s guarantees a
    // replay has started by then regardless of the random draw.
    await tester.pump(kFoxPetMaxPause);
    expect(tester.binding.hasScheduledFrame, isTrue);

    // The replay itself finishes and goes idle again...
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    // ...and a second replay starts after another such pause, proving
    // the loop repeats rather than firing once.
    await tester.pump(kFoxPetMaxPause);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('with reduce motion on, the pet plays once and never replays', (
    tester,
  ) async {
    await _pumpPet(
      tester,
      FoxPet(pet: PetCatalog.defaultEntry),
      disableAnimations: true,
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    // Wait well past the maximum possible pause: still no replay.
    await tester.pump(kFoxPetMaxPause + const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'dispose cancels the pending pause timer, leaving no pending timer or '
    'post-unmount work',
    (tester) async {
      await _pumpPet(tester, FoxPet(pet: PetCatalog.defaultEntry));
      // Let the first play-through finish so a pause timer is scheduled.
      await tester.pumpAndSettle();

      // Unmount before the pause elapses, then end the test without ever
      // advancing far enough for that timer to fire on its own. If
      // `dispose()` didn't cancel it, the test framework's own
      // end-of-test invariant check — which runs *after* this test body
      // returns, unmounting whatever's left and asserting no `Timer` is
      // still pending — fails with "A Timer is still pending even after
      // the widget tree was disposed." This test passing at all is the
      // proof; pumping further here would let the still-pending timer
      // fire harmlessly (its `if (mounted)` guard) before that check ever
      // runs, defeating it.
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'swapping to a different pet while mounted cancels the old pet\'s '
    'stale pause timer instead of leaking it',
    (tester) async {
      // Call sites pass no `Key` (e.g. Home's `FoxPet(pet: '
      // 'ref.watch(equippedPetProvider))`), so re-equipping a pet while
      // that screen stays mounted underneath reuses this same State —
      // exactly what this reproduces. Both entries share one asset path
      // so Lottie itself never reloads/replays on the swap, isolating
      // the assertion to the stale-timer leak this guards against: if
      // the old pet's pending timer weren't cancelled, it would fire
      // `_controller.forward(from: 0)` again on its own, unprompted by
      // anything the new pet does.
      const assetPath = 'assets/noto-emoji/pet/emoji_u1f98a_lottie.json';
      const petA = PetEntry(
        id: 'fox-pet-test-a',
        assetPath: assetPath,
        emoji: '🦊',
        rarity: PetRarity.common,
        sortOrder: 0,
      );
      const petB = PetEntry(
        id: 'fox-pet-test-b',
        assetPath: assetPath,
        emoji: '🦊',
        rarity: PetRarity.common,
        sortOrder: 1,
      );
      final random = Random(2);

      await _pumpPet(tester, FoxPet(pet: petA, random: random));
      // First play-through ends; a pause timer is scheduled off `random`.
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);

      await _pumpPet(tester, FoxPet(pet: petB, random: random));
      await tester.pump();

      // Advance well past the old pet's pause: with the fix, nothing is
      // pending anymore (same asset, so the swap itself replayed nothing
      // either), so this stays idle for good.
      await tester.pump(kFoxPetMaxPause);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );
}
