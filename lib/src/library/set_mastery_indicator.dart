// Library set-card mastery (issue #134): the kit's crowns or "New" badge for
// one set, animating the change since the card last showed that set (fill,
// crown pops with a haptic tick, 100% shimmer, New -> crowns morph) as
// planned by `planMasteryMotion`.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/set_mastery.dart';
import '../widgets/widgets.dart';
import 'mastery_motion.dart';

/// The mastery each Library card last showed, by set id, for the app
/// session: lets a card that comes back into view (e.g. after a lesson)
/// animate from that value instead of only showing the new one.
final shownMasteryProvider = Provider<Map<int, SetMastery>>((ref) => {});

/// Crowns (or the "New" badge) for one set, announced as one phrase.
class SetMasteryIndicator extends ConsumerStatefulWidget {
  final int setId;
  final SetMastery mastery;

  const SetMasteryIndicator({
    super.key,
    required this.setId,
    required this.mastery,
  });

  @override
  ConsumerState<SetMasteryIndicator> createState() =>
      _SetMasteryIndicatorState();
}

class _SetMasteryIndicatorState extends ConsumerState<SetMasteryIndicator>
    with TickerProviderStateMixin {
  static const int _badgeShrinkMs = 250;
  static const int _crownsFadeStartMs = 200;
  static const int _crownsFadeMs = 250;
  static const int _morphMs = _crownsFadeStartMs + _crownsFadeMs;
  static const int _fillMs = 600;
  static const int _shimmerMs = 700;

  late final AnimationController _motionController = AnimationController(
    vsync: this,
  )..addListener(_popCrossedCrowns);
  late final List<AnimationController> _pops = [
    for (var i = 0; i < kMasteryCrownCount; i++)
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 260),
      ),
  ];

  /// The mastery this card renders: [SetMasteryIndicator.mastery], except
  /// while the card is hidden behind another route (then the value it last
  /// showed, so the change plays once it is back on top).
  SetMastery? _displayed;
  MasteryMotion? _motion;
  final Set<int> _popped = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SetMasteryIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setId != widget.setId) _startMotion(null);
    if (oldWidget.mastery != widget.mastery ||
        oldWidget.setId != widget.setId) {
      _sync();
    }
  }

  @override
  void dispose() {
    _motionController.dispose();
    for (final pop in _pops) {
      pop.dispose();
    }
    super.dispose();
  }

  void _sync() {
    final shownBySet = ref.read(shownMasteryProvider);
    final current = widget.mastery;
    final bool visible =
        (ModalRoute.isCurrentOf(context) ?? true) &&
        TickerMode.valuesOf(context).enabled;
    if (!visible) {
      _displayed = shownBySet.putIfAbsent(widget.setId, () => current);
      return;
    }
    final shown = shownBySet[widget.setId];
    _displayed = current;
    // Unrelated dependency changes re-run this; never restart a motion.
    if (shown == current) return;
    shownBySet[widget.setId] = current;
    _startMotion(
      planMasteryMotion(
        shown: shown,
        current: current,
        reduceMotion: MediaQuery.disableAnimationsOf(context),
      ),
    );
  }

  void _startMotion(MasteryMotion? motion) {
    _motionController.stop();
    for (final pop in _pops) {
      pop.value = 0;
    }
    _popped.clear();
    _motion = motion;
    if (motion == null) return;
    final int totalMs =
        (motion.morphFromNew ? _morphMs : 0) +
        (motion.fills ? _fillMs : 0) +
        (motion.shimmer ? _shimmerMs : 0);
    _motionController.duration = Duration(milliseconds: totalMs);
    _motionController.forward(from: 0);
  }

  double get _elapsedMs =>
      _motionController.value *
      (_motionController.duration?.inMilliseconds ?? 0);

  int get _fillStartMs => _motion!.morphFromNew ? _morphMs : 0;

  double get _fillProgress =>
      ((_elapsedMs - _fillStartMs) / _fillMs).clamp(0, 1).toDouble();

  double get _fill {
    final motion = _motion!;
    if (!motion.fills) return motion.toCrowns;
    return motion.fromCrowns +
        (motion.toCrowns - motion.fromCrowns) *
            Curves.easeOutCubic.transform(_fillProgress);
  }

  void _popCrossedCrowns() {
    final motion = _motion;
    if (motion == null || !mounted) return;
    final double fill = _fill;
    for (final index in motion.poppingCrowns) {
      if (fill >= index + 1 - 1e-9 && _popped.add(index)) {
        _pops[index].forward(from: 0);
        FoxFeedback.tick(context, ref);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mastery = _displayed ?? widget.mastery;
    final String label;
    switch (mastery.kind) {
      case MasteryKind.none:
        return const SizedBox.shrink();
      case MasteryKind.fresh:
        label = l10n.masteryNewSemantics;
      case MasteryKind.crowns:
        label = l10n.masteryPercentSemantics(mastery.percent);
    }
    final badge = FoxNewBadge(label: l10n.masteryNewBadge);
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: _motion == null
            ? (mastery.kind == MasteryKind.fresh
                  ? badge
                  : FoxMasteryCrowns(fill: mastery.crowns))
            : AnimatedBuilder(
                animation: Listenable.merge([_motionController, ..._pops]),
                builder: (context, _) => _buildMotionFrame(badge),
              ),
      ),
    );
  }

  Widget _buildMotionFrame(Widget badge) {
    final motion = _motion!;
    final double elapsed = _elapsedMs;
    final double badgeGone = motion.morphFromNew
        ? (elapsed / _badgeShrinkMs).clamp(0, 1).toDouble()
        : 1;
    final double crownsOpacity = motion.morphFromNew
        ? ((elapsed - _crownsFadeStartMs) / _crownsFadeMs)
              .clamp(0, 1)
              .toDouble()
        : 1;
    // Light bounce at the end of the fill: a small swell of the whole row.
    final double fillProgress = _fillProgress;
    final double bounce = motion.fills && fillProgress > 0.75
        ? 1 + 0.06 * math.sin(math.pi * (fillProgress - 0.75) / 0.25)
        : 1;
    final int shimmerStartMs = _fillStartMs + (motion.fills ? _fillMs : 0);
    final double shimmerProgress = (elapsed - shimmerStartMs) / _shimmerMs;
    final bool shimmering =
        motion.shimmer && shimmerProgress >= 0 && shimmerProgress < 1;
    return Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        if (badgeGone < 1)
          Opacity(
            opacity: 1 - badgeGone,
            child: Transform.scale(
              scale: 1 - badgeGone,
              alignment: AlignmentDirectional.centerStart,
              child: badge,
            ),
          ),
        Opacity(
          opacity: crownsOpacity,
          child: Transform.scale(
            scale: bounce,
            alignment: AlignmentDirectional.centerStart,
            child: FoxMasteryCrowns(
              fill: _fill,
              crownScales: [
                for (final pop in _pops)
                  1 + 0.35 * math.sin(math.pi * pop.value),
              ],
              shimmer: shimmering ? shimmerProgress : null,
            ),
          ),
        ),
      ],
    );
  }
}
