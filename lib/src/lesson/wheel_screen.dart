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
// second time to stop it early or lets the automatic timeout stop it (the
// motion lives in `wheel_spin.dart`, the painting in `wheel_painter.dart`;
// issue #117 made the spin feel physical).
// Unlike the lootbox/streak-saved/XP-up screens (#082, still open for those
// three), this one ships with `PopScope(canPop: false)` from day one: a
// spin result is visible (persisted) as soon as it's drawn, so there's no
// safe "undo" point to back out to.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../pet/lootbox_reward.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'wheel_painter.dart';
import 'wheel_spin.dart';

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
/// wind-down already underway, no longer tappable — see
/// [_WheelScreenState._stopSpin] for why a tap here must be a no-op); and
/// stopped on the already-decided segment.
enum _WheelPhase { idle, spinning, stopping, stopped }

/// Tap-to-spin wheel-of-fortune reveal for an already-won [reward].
class WheelScreen extends ConsumerStatefulWidget {
  final WheelReward reward;
  final AppLocalizations l10n;

  const WheelScreen({super.key, required this.reward, required this.l10n});

  @override
  ConsumerState<WheelScreen> createState() => _WheelScreenState();
}

class _WheelScreenState extends ConsumerState<WheelScreen>
    with TickerProviderStateMixin {
  static const Duration _idleBreathDuration = Duration(milliseconds: 700);
  static const Duration _idlePauseDuration = Duration(milliseconds: 1600);
  static const Duration _flickDuration = Duration(milliseconds: 110);
  static const Duration _winPulseDuration = Duration(milliseconds: 450);
  static const int _winPulseCount = 3;

  _WheelPhase _phase = _WheelPhase.idle;
  final ValueNotifier<double> _rotation = ValueNotifier<double>(0);
  late final Ticker _ticker;
  late final double _restFraction;
  late WheelTrajectory _trajectory;
  bool _reduceMotion = false;
  Duration _elapsed = Duration.zero;
  final WheelBoundaryTracker _boundaries = WheelBoundaryTracker(
    segments: kWheelSegments.length,
  );
  final WheelHapticThrottle _haptics = WheelHapticThrottle();

  late final AnimationController _flick = AnimationController(
    vsync: this,
    duration: _flickDuration,
  );
  late final AnimationController _winPulse = AnimationController(
    vsync: this,
    duration: _winPulseDuration,
  );

  // Idle invitation: the same bounded breathe-then-pause loop as the
  // lootbox's closed-box pulse (#073/#079), never an endless animation.
  late final BoundedLoopController _idleLoop = BoundedLoopController(
    vsync: this,
    playback: BoundedLoopPlayback.pingPong,
    duration: _idleBreathDuration,
    pauseDuration: () => _idlePauseDuration,
    reduceMotion: () => MediaQuery.disableAnimationsOf(context),
  );

  @override
  void initState() {
    super.initState();
    _restFraction =
        wheelTargetRotationTurns(widget.reward, extraFullTurns: 0) % 1;
    _trajectory = WheelTrajectory(restFraction: _restFraction);
    _ticker = createTicker(_handleTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_phase != _WheelPhase.idle) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _idleLoop.reset();
    } else {
      _idleLoop.startIfIdle();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _rotation.dispose();
    _flick.dispose();
    _winPulse.dispose();
    _idleLoop.dispose();
    super.dispose();
  }

  void _handleTick(Duration elapsed) {
    _elapsed = elapsed;
    final double turns = _trajectory.turnsAt(elapsed);
    _rotation.value = turns;
    if (_boundaries.advance(turns) > 0) {
      _flick.forward(from: 0);
      if (_haptics.tryFire(elapsed)) {
        FoxFeedback.tick(context, ref);
      }
    }
    // The automatic stop has engaged: from here a tap must be a no-op, or it
    // would re-plan the stop from a later moment and speed the wheel up.
    if (_phase == _WheelPhase.spinning &&
        elapsed >= _trajectory.stopEngagesAt) {
      setState(() => _phase = _WheelPhase.stopping);
    }
    if (elapsed >= _trajectory.totalDuration) {
      _ticker.stop();
      _rotation.value = _trajectory.restTurns;
      setState(() => _phase = _WheelPhase.stopped);
      if (!_reduceMotion) {
        _winPulse.repeat(reverse: true, count: _winPulseCount * 2);
      }
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
    _idleLoop.reset();
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    _reduceMotion = reduceMotion;
    _trajectory = WheelTrajectory(
      restFraction: _restFraction,
      reduceMotion: reduceMotion,
    );
    // The plain reduce-motion spin has no early stop to offer.
    setState(
      () => _phase = reduceMotion ? _WheelPhase.stopping : _WheelPhase.spinning,
    );
    _ticker.start();
  }

  /// Ends the spin early on a second tap: replaces the trajectory with one
  /// whose deceleration engages now. The two trajectories agree up to this
  /// moment, so the wheel carries on from where it is, only slowing down,
  /// and lands on the same slice as an unhindered spin.
  ///
  /// Moves to [_WheelPhase.stopping] so [_handleTap] ignores any further
  /// taps during the wind-down — re-planning on every tap could otherwise
  /// keep postponing the landing and leave the screen stuck (no back nav,
  /// per [PopScope]).
  void _stopSpin() {
    if (_phase != _WheelPhase.spinning) return;
    setState(() => _phase = _WheelPhase.stopping);
    _trajectory = WheelTrajectory(
      restFraction: _restFraction,
      stopAfter: _elapsed,
    );
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
    final int? winningIndex = stopped ? kWheelSegments.indexOf(reward) : null;
    Widget dial({required String label, VoidCallback? onTap}) => _WheelDial(
      rotation: _rotation,
      flick: _flick,
      idle: _idleLoop.controller,
      winPulse: _winPulse,
      winningIndex: winningIndex,
      semanticLabel: label,
      onTap: onTap,
    );
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
                    FoxCelebration(child: dial(label: wonSemanticLabel))
                  else
                    dial(label: l10n.wheelTapPrompt, onTap: _handleTap),
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
  static const double _idleScale = 0.05;
  static const double _idleWobbleTurns = 0.012;
  static const double _flickTilt = 0.5;

  final ValueNotifier<double> rotation;
  final Animation<double> flick;
  final Animation<double> idle;
  final Animation<double> winPulse;
  final int? winningIndex;
  final String semanticLabel;
  final VoidCallback? onTap;

  const _WheelDial({
    required this.rotation,
    required this.flick,
    required this.idle,
    required this.winPulse,
    required this.winningIndex,
    required this.semanticLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final semantics = theme.extension<FoxSemanticColors>()!;
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
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800) ??
        const TextStyle(fontWeight: FontWeight.w800);

    final Widget dial = SizedBox(
      key: const Key('wheelDial'),
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[rotation, idle]),
            builder: (context, child) {
              final double wobble =
                  math.sin(idle.value * 2 * math.pi) * _idleWobbleTurns;
              return Transform.scale(
                scale: 1 + _idleScale * Curves.easeInOut.transform(idle.value),
                child: Transform.rotate(
                  key: const Key('wheelRotation'),
                  angle: (rotation.value + wobble) * 2 * math.pi,
                  child: child,
                ),
              );
            },
            child: RepaintBoundary(
              child: CustomPaint(
                size: const Size.square(_size),
                painter: WheelPainter(
                  labels: kWheelSegments.map(_labelFor).toList(),
                  sliceColors: sliceColors,
                  onSliceColors: onSliceColors,
                  textStyle: textStyle,
                  rimColor: scheme.primary,
                  rimLightColor: scheme.onPrimary,
                  dividerColor: scheme.surface,
                  hubColor: scheme.surface,
                  shadowColor: scheme.shadow,
                  surfaceColor: scheme.surface,
                  onSurfaceColor: scheme.onSurface,
                  winningIndex: winningIndex,
                  pulse: winPulse,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: AnimatedBuilder(
              animation: flick,
              builder: (context, child) => Transform.rotate(
                alignment: Alignment.topCenter,
                angle: math.sin(flick.value * math.pi) * _flickTilt,
                child: child,
              ),
              child: Icon(
                Icons.arrow_drop_down,
                size: 36,
                color: scheme.onSurface,
              ),
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
