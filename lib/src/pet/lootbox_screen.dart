// Daily lootbox reveal screen (issue #059; opening animation + asset-folder
// reorg by #062; coin-reward outcome by #065; repeating trigger cadence by
// #067).
//
// Shown after the lesson result screen, on the 2nd lesson completion of the
// local day and then again every 3rd completion after that (5, 8, 11, ...,
// uncapped) — see `PetService.recordLessonCompletion`/
// `LessonController._completeLesson`/`LessonScreen`. Each trigger pushes its
// own instance of this screen in turn. The reward itself was already picked
// + persisted (as an owned pet or added coins) by
// `PetService.recordLessonCompletion`; this screen is
// purely the tap-to-open reveal moment, switching on [LootboxReward] only
// for what's shown *after* the box finishes opening — the opening phase
// and its Lottie are the same for both outcomes. Pops itself on Continue,
// so callers just `await Navigator.push(...)` it like `FoxConfirmDialog`.
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../l10n/app_localizations.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'lootbox_reward.dart';

/// The lootbox-opening Lottie: a one-off effect animation, not a
/// collectible, so it lives in `other/` rather than `PetCatalog`'s
/// scanned `pet/` directory (#062).
const String kLootboxOpenAnimationAsset =
    'assets/noto-emoji/other/emoji_u1fa8e_lottie.json';

/// The coin-reveal Lottie for a [CoinsReward] outcome (issue #065) — same
/// `other/`-not-`pet/` placement and rationale as
/// [kLootboxOpenAnimationAsset]: a one-off effect, not a collectible.
const String kLootboxCoinRevealAsset =
    'assets/noto-emoji/other/emoji_u1fa99_lottie.json';

/// The three states a lootbox moves through, in order, never backwards:
/// frozen on frame 0 and tappable; tapped and playing once (no longer
/// tappable, not announced as interactive); and the final reveal.
enum _LootboxPhase { closed, opening, revealed }

/// Tap-to-open lootbox reveal for a single already-won [reward].
class LootboxScreen extends StatefulWidget {
  final LootboxReward reward;
  final AppLocalizations l10n;

  const LootboxScreen({super.key, required this.reward, required this.l10n});

  @override
  State<LootboxScreen> createState() => _LootboxScreenState();
}

class _LootboxScreenState extends State<LootboxScreen>
    with SingleTickerProviderStateMixin {
  _LootboxPhase _phase = _LootboxPhase.closed;
  late final AnimationController _animationController;

  // The real composition duration isn't known until `Lottie.asset`'s
  // `onLoaded` fires. If `_open` runs first (a fast tap racing a slow
  // asset decode), `_animationController` has no duration yet to
  // `forward()` with — `_openRequested` defers that `forward()` call to
  // `_handleCompositionLoaded` instead, rather than playing at a guessed,
  // possibly-wrong speed.
  bool _compositionLoaded = false;
  bool _openRequested = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
    _animationController.addStatusListener(_handleAnimationStatus);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() => _phase = _LootboxPhase.revealed);
    }
  }

  void _handleCompositionLoaded(LottieComposition composition) {
    _animationController.duration = composition.duration;
    _compositionLoaded = true;
    if (_openRequested) {
      _animationController.forward();
    }
  }

  void _open() {
    if (_phase != _LootboxPhase.closed) {
      return;
    }
    setState(() => _phase = _LootboxPhase.opening);
    if (_compositionLoaded) {
      _animationController.forward();
    } else {
      _openRequested = true;
    }
  }

  String _revealedTitle(AppLocalizations l10n) => switch (widget.reward) {
    PetReward() => l10n.lootboxRevealedTitle,
    CoinsReward(amount: final amount) => l10n.lootboxCoinsRevealedTitle(amount),
  };

  Widget _revealedContent(AppLocalizations l10n) => switch (widget.reward) {
    PetReward(entry: final entry) => FoxPet(
      pet: entry,
      size: 160,
      semanticLabel: l10n.petSemanticLabel(entry.emoji),
    ),
    CoinsReward(amount: final amount) => _CoinReveal(
      semanticLabel: l10n.coinsSemanticLabel(amount),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = widget.l10n;
    final bool revealed = _phase == _LootboxPhase.revealed;
    return Scaffold(
      key: const Key('lootboxScreen'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(FoxSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  revealed ? _revealedTitle(l10n) : l10n.lootboxHeading,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: FoxSpacing.xl),
                if (revealed)
                  FoxCelebration(child: _revealedContent(l10n))
                else
                  _LootboxAnimation(
                    controller: _animationController,
                    interactive: _phase == _LootboxPhase.closed,
                    label: l10n.lootboxTapPrompt,
                    onTap: _open,
                    onLoaded: _handleCompositionLoaded,
                  ),
                const SizedBox(height: FoxSpacing.xxl),
                if (revealed)
                  FoxPrimaryButton(
                    key: const Key('lootboxContinueButton'),
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

/// The lootbox's Lottie, [controller]-driven so the caller can hold it on
/// frame 0 until tapped ([interactive], the closed state) and then advance
/// it once via [onTap]. [interactive] gates both the tap target and its
/// a11y semantics; while `false` (mid-animation) the box renders with no
/// `InkWell`/`Semantics` at all, so a re-tap is a true no-op and screen
/// readers never announce it as a button.
class _LootboxAnimation extends StatelessWidget {
  final AnimationController controller;
  final bool interactive;
  final String label;
  final VoidCallback onTap;
  final void Function(LottieComposition composition) onLoaded;

  const _LootboxAnimation({
    required this.controller,
    required this.interactive,
    required this.label,
    required this.onTap,
    required this.onLoaded,
  });

  @override
  Widget build(BuildContext context) {
    final Widget lottie = SizedBox(
      key: const Key('lootboxAnimation'),
      width: 160,
      height: 160,
      child: Lottie.asset(
        kLootboxOpenAnimationAsset,
        controller: controller,
        onLoaded: onLoaded,
        fit: BoxFit.contain,
      ),
    );

    if (!interactive) {
      return lottie;
    }

    return InkWell(
      key: const Key('lootboxOpenButton'),
      borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.lg)),
      onTap: onTap,
      child: Semantics(
        button: true,
        label: label,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: FoxButtonMetrics.minSize,
            minHeight: FoxButtonMetrics.minSize,
          ),
          child: lottie,
        ),
      ),
    );
  }
}

/// The #065 coin-reveal visual: [kLootboxCoinRevealAsset] plus an a11y
/// label, mirroring `FoxPet`'s Lottie-plus-semantic-label shape for the
/// pet case. Not tappable, so — unlike [_LootboxAnimation] — there's no
/// interaction/gating to model; kept as a one-off here rather than
/// promoted to the kit, same reasoning as `_PetTile` in
/// `pet_collection_screen.dart`.
class _CoinReveal extends StatelessWidget {
  final String semanticLabel;

  const _CoinReveal({required this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox(
        key: const Key('lootboxCoinReveal'),
        width: 160,
        height: 160,
        child: Lottie.asset(
          kLootboxCoinRevealAsset,
          repeat: false,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
