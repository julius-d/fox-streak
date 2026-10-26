// Pet display widget (issue #015, retired state-painter -> collectible
// Lottie render by #059; loops with a pause instead of playing once, #071).
//
// Where the pet may appear: [FoxEmptyState] headers, result/celebration
// surfaces (#005–#009), Home's tap-to-collect target (#012/#059),
// onboarding (#012). Nowhere else without a design reason.
//
// Renders the given [PetEntry]'s Lottie animation as-is — no more
// empty/lit/on-fire state variants (#059 retired those along with
// `FoxPetState`/`_FoxPainter`; which pet is shown is a collectible
// choice now, not a mood).
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../pet/pet_catalog.dart';

/// The pause between play-throughs is re-rolled in this range each cycle
/// (issue #071).
const Duration kFoxPetMinPause = Duration(seconds: 3);
const Duration kFoxPetMaxPause = Duration(seconds: 8);

/// Draws a random pause before the next play-through, in
/// [kFoxPetMinPause, kFoxPetMaxPause], off [random] — mirroring
/// `lootbox_reward.dart`'s `drawCoinAmount(Random random)` seam so tests
/// can inject a seeded `Random` and assert the draw's bounds.
Duration drawFoxPetPause(Random random) {
  final int rangeMs = (kFoxPetMaxPause - kFoxPetMinPause).inMilliseconds;
  return kFoxPetMinPause + Duration(milliseconds: random.nextInt(rangeMs + 1));
}

/// Displays [pet]'s Lottie animation.
///
/// Plays once, then — unless the OS "reduce motion" accessibility setting
/// is on (`MediaQuery.disableAnimationsOf`) — waits a random pause in
/// [kFoxPetMinPause, kFoxPetMaxPause] (re-rolled independently each cycle)
/// and plays again, looping indefinitely for as long as the widget stays
/// mounted (issue #071). With reduce motion on, it plays once and holds
/// its final frame, same as a plain `repeat: false` Lottie — no loop, no
/// pause, matching #010's `FoxProgressBar` reduce-motion pattern rather
/// than inventing a new app-specific toggle.
///
/// Always provide [semanticLabel] (or null for purely decorative repeats
/// next to a labelled heading) so screen readers announce the moment.
class FoxPet extends StatefulWidget {
  final PetEntry pet;
  final double size;
  final String? semanticLabel;

  /// Seam for the loop pause's random draw (default `Random()`); inject a
  /// seeded `Random` in tests to assert the pause falls in
  /// [kFoxPetMinPause, kFoxPetMaxPause], mirroring `lootbox_reward.dart`'s
  /// `drawCoinAmount(Random random)` seam.
  final Random? random;

  const FoxPet({
    super.key,
    required this.pet,
    this.size = 96,
    this.semanticLabel,
    this.random,
  });

  @override
  State<FoxPet> createState() => _FoxPetState();
}

class _FoxPetState extends State<FoxPet> with SingleTickerProviderStateMixin {
  late final Random _random = widget.random ?? Random();
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addStatusListener(_handlePlaythroughStatus);
  Timer? _pauseTimer;

  @override
  void didUpdateWidget(FoxPet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Call sites pass no `Key`, so swapping `pet` (e.g. re-equipping on
    // `PetCollectionScreen` while this `FoxPet` stays mounted underneath,
    // as on Home) reuses this same State. `Lottie.asset` reloads and
    // re-fires `onLoaded` for the new composition on its own; without this,
    // any pause timer still pending from the old pet's loop would survive
    // to fire later and restart the new pet's in-progress play-through.
    if (widget.pet.id != oldWidget.pet.id) {
      _pauseTimer?.cancel();
      _pauseTimer = null;
    }
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleCompositionLoaded(LottieComposition composition) {
    _controller.duration = composition.duration;
    _controller.forward(from: 0);
  }

  void _handlePlaythroughStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _pauseTimer = Timer(drawFoxPetPause(_random), () {
      if (mounted) _controller.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      image: widget.semanticLabel != null,
      child: SizedBox(
        key: Key('foxPet-${widget.pet.id}'),
        width: widget.size,
        height: widget.size,
        child: Lottie.asset(
          widget.pet.assetPath,
          controller: _controller,
          onLoaded: _handleCompositionLoaded,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
