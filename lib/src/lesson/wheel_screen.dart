// Wheel-of-fortune reveal screen (issue #085; #087 adds the 7th
// streak-on-ice segment).
//
// Shown after the lesson result screen, on the day's 3rd lesson completion
// and then again every 3rd completion after that (6, 9, 12, ..., uncapped)
// — see `PetService.recordLessonCompletion`/`LessonController`/
// `LessonScreen`. That cadence never overlaps the lootbox's own (2, 5, 8,
// 11, ...), so this screen occupies the same "reward slot" in the
// completion sequence as `LootboxScreen` without ever competing with it.
//
// The reward was already drawn + persisted (to `coinsTotal` or
// `streakFreezesAvailable`) by `PetService.recordLessonCompletion` before
// this screen ever opens — the spin itself is purely cosmetic and always
// lands on that reward's slice, regardless of whether the user taps a
// second time to stop it early or lets the automatic timeout stop it.
// Unlike the lootbox/streak-saved/XP-up screens (#082, still open for those
// three), this one ships with `PopScope(canPop: false)` from day one: a
// spin result is visible (persisted) as soon as it's drawn, so there's no
// safe "undo" point to back out to.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../pet/lootbox_reward.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';

/// How far around the wheel (in full turns) the spin must land to put
/// [reward]'s slice under the fixed top pointer, plus [extraFullTurns]
/// whole turns purely for visual flair — adding whole turns never changes
/// which slice ends up under the pointer, since a full turn brings every
/// slice back to where it started.
///
/// Pulled out of [_WheelScreenState] so the landing math is unit-testable
/// without a running animation.
@visibleForTesting
double wheelTargetRotationTurns(WheelReward reward, {int extraFullTurns = 4}) {
  final index = kWheelSegments.indexOf(reward);
  assert(index != -1, 'reward must be one of kWheelSegments, was $reward');
  final sliceTurn = 1 / kWheelSegments.length;
  final sliceCenterTurn = (index + 0.5) * sliceTurn;
  // The pointer reads whatever slice sits at turn 0 (the top) once rotated;
  // rotating by (1 - sliceCenterTurn) turns brings that slice's center back
  // to turn 0.
  return extraFullTurns + (1 - sliceCenterTurn);
}

/// The four states a wheel moves through, in order, never backwards: idle
/// and tappable to start; spinning (tappable a second time to stop early,
/// otherwise stopped automatically after a short delay); stopping (the
/// short wind-down animation already underway, no longer tappable — see
/// [_WheelScreenState._stopSpin] for why a tap here must be a no-op); and
/// stopped on the already-decided segment.
enum _WheelPhase { idle, spinning, stopping, stopped }

/// Tap-to-spin wheel-of-fortune reveal for an already-won [reward].
class WheelScreen extends StatefulWidget {
  final WheelReward reward;
  final AppLocalizations l10n;

  const WheelScreen({super.key, required this.reward, required this.l10n});

  @override
  State<WheelScreen> createState() => _WheelScreenState();
}

class _WheelScreenState extends State<WheelScreen>
    with SingleTickerProviderStateMixin {
  static const int _extraFullTurns = 4;
  static const Duration _spinDuration = Duration(milliseconds: 3000);
  static const Duration _autoStopDelay = Duration(milliseconds: 1600);
  static const Duration _quickStopDuration = Duration(milliseconds: 500);

  _WheelPhase _phase = _WheelPhase.idle;
  late final AnimationController _controller;
  late final Animation<double> _rotation;
  Timer? _autoStopTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _spinDuration)
      ..addStatusListener(_handleStatus);
    final targetTurns = wheelTargetRotationTurns(
      widget.reward,
      extraFullTurns: _extraFullTurns,
    );
    _rotation = Tween<double>(
      begin: 0,
      end: targetTurns,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() => _phase = _WheelPhase.stopped);
    }
  }

  void _handleTap() {
    switch (_phase) {
      case _WheelPhase.idle:
        _startSpin();
      case _WheelPhase.spinning:
        _stopSpin();
      case _WheelPhase.stopping:
      case _WheelPhase.stopped:
        break;
    }
  }

  void _startSpin() {
    setState(() => _phase = _WheelPhase.spinning);
    _controller.forward();
    _autoStopTimer = Timer(_autoStopDelay, _stopSpin);
  }

  /// Ends the spin, whether called from a second tap or [_autoStopTimer] —
  /// either way, animates the *same* [_controller] from wherever it
  /// currently is up to `1.0` (i.e. [Tween.end], [widget.reward]'s slice),
  /// just over a shorter, fixed [_quickStopDuration]. Only how long the
  /// remaining spin takes differs between the two callers, never the
  /// landing slice.
  ///
  /// Moves to [_WheelPhase.stopping] (rather than leaving [_phase] at
  /// `spinning` until the animation completes) so [_handleTap] ignores any
  /// further taps during this short wind-down — without this, tapping
  /// faster than [_quickStopDuration] would keep restarting `animateTo`
  /// from a fresh `0%`, starving the controller of ever reaching
  /// `completed` and leaving the screen permanently stuck (no back nav,
  /// per [PopScope]).
  void _stopSpin() {
    if (_phase != _WheelPhase.spinning) return;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    setState(() => _phase = _WheelPhase.stopping);
    _controller.animateTo(1.0, duration: _quickStopDuration);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final reward = widget.reward;
    final stopped = _phase == _WheelPhase.stopped;
    final String wonText = switch (reward) {
      WheelCoinsReward(amount: final amount) => l10n.wheelWonText(amount),
      WheelStreakOnIceReward() => l10n.wheelWonStreakOnIceText,
    };
    final String wonSemanticLabel = switch (reward) {
      WheelCoinsReward(amount: final amount) => l10n.coinsSemanticLabel(amount),
      WheelStreakOnIceReward() => l10n.streakOnIceSemanticLabel,
    };
    return PopScope(
      canPop: false,
      child: Scaffold(
        key: const Key('wheelScreen'),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(FoxSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    stopped ? wonText : l10n.wheelHeading,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: FoxSpacing.xl),
                  if (stopped)
                    FoxCelebration(
                      child: _WheelDial(
                        rotation: _rotation,
                        semanticLabel: wonSemanticLabel,
                      ),
                    )
                  else
                    _WheelDial(
                      rotation: _rotation,
                      semanticLabel: l10n.wheelTapPrompt,
                      onTap: _handleTap,
                    ),
                  const SizedBox(height: FoxSpacing.xxl),
                  if (stopped)
                    FoxPrimaryButton(
                      key: const Key('wheelContinueButton'),
                      label: l10n.lessonContinue,
                      expanded: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The text label painted on one wheel slice: the coin amount, or a
/// snowflake glyph for the streak-on-ice segment — decorative only (the
/// dial's own [FoxRevealTapTarget.semanticLabel] carries the a11y text), so
/// a plain Unicode character needs no l10n entry, same as the wheel's own
/// pointer icon.
String _labelFor(WheelReward segment) => switch (segment) {
  WheelCoinsReward(amount: final amount) => '$amount',
  WheelStreakOnIceReward() => '❄',
};

/// The wheel's rotating [CustomPaint] plus its fixed (non-rotating) top
/// pointer, wrapped in the shared [FoxRevealTapTarget] (issue #095) that
/// also gates `LootboxScreen`'s `_LootboxAnimation`.
class _WheelDial extends StatelessWidget {
  static const double _size = 220;

  final Animation<double> rotation;
  final String semanticLabel;
  final VoidCallback? onTap;

  const _WheelDial({
    required this.rotation,
    required this.semanticLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final semantics = Theme.of(context).extension<FoxSemanticColors>()!;
    final sliceColors = <Color>[
      semantics.gold,
      semantics.coin,
      semantics.flame,
      semantics.success,
      semantics.info,
      semantics.math,
      semantics.ice,
    ];
    final onSliceColors = <Color>[
      semantics.onGold,
      semantics.onCoin,
      semantics.onFlame,
      semantics.onSuccess,
      semantics.onInfo,
      semantics.onMath,
      semantics.onIce,
    ];
    final textStyle =
        Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w800) ??
        const TextStyle(fontWeight: FontWeight.w800);

    final Widget dial = SizedBox(
      key: const Key('wheelDial'),
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          AnimatedBuilder(
            animation: rotation,
            builder: (context, child) => Transform.rotate(
              angle: rotation.value * 2 * math.pi,
              child: child,
            ),
            child: CustomPaint(
              size: const Size.square(_size),
              painter: _WheelPainter(
                labels: kWheelSegments.map(_labelFor).toList(),
                sliceColors: sliceColors,
                onSliceColors: onSliceColors,
                textStyle: textStyle,
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Icon(
              Icons.arrow_drop_down,
              size: 36,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );

    return FoxRevealTapTarget(
      tapKey: const Key('wheelSpinButton'),
      borderRadius: const BorderRadius.all(Radius.circular(_size / 2)),
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: dial,
    );
  }
}

/// Paints [labels.length] equal pie slices, each filled with its
/// [sliceColors] entry and labelled with its [labels] entry in the matching
/// [onSliceColors] entry (the AA-checked "safe for text on this fill"
/// counterpart — see `FoxSemanticColors`'s class doc). Slice `0` starts at
/// the top (12 o'clock) and slices proceed clockwise —
/// [wheelTargetRotationTurns] relies on this exact layout to compute which
/// rotation lands which slice under the fixed pointer.
class _WheelPainter extends CustomPainter {
  final List<String> labels;
  final List<Color> sliceColors;
  final List<Color> onSliceColors;
  final TextStyle textStyle;

  const _WheelPainter({
    required this.labels,
    required this.sliceColors,
    required this.onSliceColors,
    required this.textStyle,
  }) : assert(
         sliceColors.length == labels.length &&
             onSliceColors.length == labels.length,
         'sliceColors/onSliceColors must have one entry per labels entry '
         '(labels: ${labels.length}, sliceColors: ${sliceColors.length}, '
         'onSliceColors: ${onSliceColors.length})',
       );

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;
    final double sliceAngle = 2 * math.pi / labels.length;

    for (var i = 0; i < labels.length; i++) {
      final double startAngle = -math.pi / 2 + i * sliceAngle;
      final Paint fillPaint = Paint()..color = sliceColors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sliceAngle,
        true,
        fillPaint,
      );

      final double labelAngle = startAngle + sliceAngle / 2;
      final Offset labelOffset =
          center +
          Offset(math.cos(labelAngle), math.sin(labelAngle)) * radius * 0.65;
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: textStyle.copyWith(color: onSliceColors[i]),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        labelOffset - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => false;
}
