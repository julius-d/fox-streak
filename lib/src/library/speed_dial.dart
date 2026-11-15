// Library "New set" speed-dial (issues #074, #133).
//
// [SpeedDial] goes into `Scaffold.floatingActionButton` as one unit: the
// option stack plus the main FAB in a single column. Scaffold positions
// the whole column, lifting it above the bottom system inset (Android nav
// bar / gesture handle, iOS home indicator), so the
// options always sit directly above the main FAB wherever it ends up
// (#133). Before that, the options lived at a fixed offset in the body and
// slid under the lifted FAB on edge-to-edge Android.
//
// [SpeedDialScrim] goes into the body (below the FAB slot in paint
// order). Both are driven by one caller-owned [AnimationController] —
// `forward()` opens, `reverse()` closes, so an interrupted animation
// reverses from wherever it is. [speedDialOpenDuration] /
// [speedDialCloseDuration] size it; reduced motion is the caller's job
// (set `value` directly instead of animating).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';

/// Per-option pop duration (#133).
const Duration speedDialOptionDuration = Duration(milliseconds: 200);

/// Delay between one option's pop and the next one up (#133).
const Duration speedDialOptionStagger = Duration(milliseconds: 50);

/// Whole close animation: options shrink back top → bottom (#133).
const Duration speedDialCloseDuration = Duration(milliseconds: 200);

/// Whole open animation for [optionCount] staggered options: ~300ms for
/// the Library's three.
Duration speedDialOpenDuration(int optionCount) =>
    speedDialOptionDuration +
    speedDialOptionStagger * math.max(0, optionCount - 1);

/// Slice of the controller's 0..1 range in which the option at
/// [indexFromBottom] (0 = closest to the main FAB) pops in. Played
/// backwards on close, the same slices make the top option leave first.
({double begin, double end}) speedDialOptionSlice(
  int indexFromBottom,
  int optionCount,
) {
  final total = speedDialOpenDuration(optionCount).inMicroseconds;
  final begin =
      (speedDialOptionStagger * indexFromBottom).inMicroseconds / total;
  final end = begin + speedDialOptionDuration.inMicroseconds / total;
  return (begin: begin, end: math.min(1.0, end));
}

/// One labeled option above the main FAB.
class SpeedDialOption {
  final Key key;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const SpeedDialOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}

/// Main FAB plus its option stack (top-first in [options]).
///
/// Collapsed ([animation] dismissed): only the extended "[icon] [label]"
/// FAB, identical to a plain `FloatingActionButton.extended`. Open: the
/// options pop out bottom → top with a small overshoot while the main FAB
/// morphs into a round button, its icon rotated by 45° (+ → ×).
class SpeedDial extends StatefulWidget {
  final Animation<double> animation;
  final List<SpeedDialOption> options;

  /// Key of the main FAB, kept stable across collapsed/expanded.
  final Key mainKey;
  final String label;
  final IconData icon;
  final String closeTooltip;
  final VoidCallback onToggle;

  /// Height above the Scaffold's FAB slot the options must stay clear of:
  /// status bar + app bar.
  final double topClearance;

  /// Height below the main FAB that Scaffold keeps free: bottom system
  /// inset + FAB margin.
  final double bottomClearance;

  const SpeedDial({
    super.key,
    required this.animation,
    required this.options,
    required this.mainKey,
    required this.label,
    required this.icon,
    required this.closeTooltip,
    required this.onToggle,
    required this.topClearance,
    required this.bottomClearance,
  });

  @override
  State<SpeedDial> createState() => _SpeedDialState();
}

class _SpeedDialState extends State<SpeedDial> {
  static const double _shadowRoom = FoxSpacing.sm;

  // Persistent (not rebuilt per frame): a [CurvedAnimation] locks its
  // curve direction until the animation hits an end, so reversing mid-pop
  // continues smoothly instead of jumping to the reverse curve's value.
  late List<CurvedAnimation> _scales;
  late List<CurvedAnimation> _fades;
  late CurvedAnimation _morph;

  @override
  void initState() {
    super.initState();
    _createCurves();
    widget.animation.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(SpeedDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation ||
        oldWidget.options.length != widget.options.length) {
      oldWidget.animation.removeStatusListener(_onStatus);
      _disposeCurves();
      _createCurves();
      widget.animation.addStatusListener(_onStatus);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    _disposeCurves();
    super.dispose();
  }

  // Status drives mounting, hit-testing and semantics of the options.
  void _onStatus(AnimationStatus _) => setState(() {});

  void _createCurves() {
    final count = widget.options.length;
    _scales = [];
    _fades = [];
    for (var i = 0; i < count; i++) {
      final slice = speedDialOptionSlice(i, count);
      _scales.add(
        CurvedAnimation(
          parent: widget.animation,
          curve: Interval(slice.begin, slice.end, curve: Curves.easeOutBack),
          reverseCurve: Interval(slice.begin, slice.end, curve: Curves.easeIn),
        ),
      );
      _fades.add(
        CurvedAnimation(
          parent: widget.animation,
          curve: Interval(slice.begin, slice.end, curve: Curves.easeOut),
        ),
      );
    }
    _morph = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeInOutCubic,
    );
  }

  void _disposeCurves() {
    for (final curve in [..._scales, ..._fades, _morph]) {
      curve.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.animation.status;
    final mainFab = _MorphingFab(
      key: widget.mainKey,
      morph: _morph,
      open: status.isForwardOrCompleted,
      label: widget.label,
      icon: widget.icon,
      closeTooltip: widget.closeTooltip,
      onPressed: widget.onToggle,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Scaffold lays the FAB slot out loosely against its full size;
        // cap the column so a short screen (landscape + large font)
        // scrolls the options instead of pushing them under the app bar.
        final maxHeight = math.max(
          0.0,
          constraints.maxHeight -
              widget.topClearance -
              widget.bottomClearance -
              FoxSpacing.sm,
        );
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            // Same structure collapsed and open (keyed main FAB), so the
            // main FAB keeps its state (ink, focus) across the toggle.
            children: [
              if (!status.isDismissed) ...[
                Flexible(child: _buildOptions(status)),
                const SizedBox(height: FoxSpacing.lg - _shadowRoom),
              ],
              mainFab,
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptions(AnimationStatus status) {
    final count = widget.options.length;
    return ClipRect(
      clipper: const _ShadowRoomClipper(right: _shadowRoom),
      child: SingleChildScrollView(
        // Clipped by the [ClipRect] above instead, which leaves room for
        // the options' shadow on the right (their right edge is flush with
        // the main FAB's, so padding can't make that room).
        clipBehavior: Clip.none,
        key: const Key('speedDialOptions'),
        // Bottom option ("New set") stays in view first on a short screen.
        reverse: true,
        // Gaps around the options stay scrim taps, not scroll-view hits.
        hitTestBehavior: HitTestBehavior.deferToChild,
        // Room for the pop's overshoot and the options' drop shadow inside
        // the scroll view's clip; the bottom part counts toward the gap.
        padding: const EdgeInsets.only(
          left: FoxSpacing.xxl,
          top: FoxSpacing.sm,
          bottom: _shadowRoom,
        ),
        // Closing (or closed): never tappable while shrinking away. Read
        // only once fully shown, so screen readers don't announce options
        // mid-pop.
        child: IgnorePointer(
          ignoring: !status.isForwardOrCompleted,
          child: ExcludeSemantics(
            excluding: !status.isCompleted,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const SizedBox(height: FoxSpacing.sm),
                  _buildOption(widget.options[i], count - 1 - i),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption(SpeedDialOption option, int indexFromBottom) {
    return FadeTransition(
      opacity: _fades[indexFromBottom],
      child: ScaleTransition(
        scale: _scales[indexFromBottom],
        alignment: Alignment.bottomRight,
        child: FloatingActionButton.extended(
          key: option.key,
          heroTag: option.key,
          tooltip: option.label,
          onPressed: option.onPressed,
          icon: Icon(option.icon),
          label: FoxFabLabel(option.label),
        ),
      ),
    );
  }
}

/// Extended "[icon] [label]" FAB that shrinks into a round, 56dp one as
/// [morph] goes 0 → 1, rotating [icon] by 45°.
///
/// At 0 its padding/spacing match `FloatingActionButton.extended`'s M3
/// defaults (start 16, end 20, spacing 8), so the collapsed button is
/// pixel-identical to the pre-#133 one; at 1 the label is gone and the
/// padding centers the 24dp icon in a 56dp square — the regular FAB.
class _MorphingFab extends StatelessWidget {
  final Animation<double> morph;
  final bool open;
  final String label;
  final IconData icon;
  final String closeTooltip;
  final VoidCallback onPressed;

  const _MorphingFab({
    super.key,
    required this.morph,
    required this.open,
    required this.label,
    required this.icon,
    required this.closeTooltip,
    required this.onPressed,
  });

  static const double _iconSize = FoxFabLabel.iconSize;
  static const double _roundSize = 56;
  static const double _roundPadding = (_roundSize - _iconSize) / 2;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: morph,
      builder: (context, _) {
        final t = morph.value.clamp(0.0, 1.0);
        return FloatingActionButton.extended(
          tooltip: open ? closeTooltip : null,
          onPressed: onPressed,
          extendedPadding: EdgeInsetsDirectional.only(
            start: _lerp(FoxFabLabel.startPadding, _roundPadding, t),
            end: _lerp(FoxFabLabel.endPadding, _roundPadding, t),
          ),
          extendedIconLabelSpacing: _lerp(FoxFabLabel.iconLabelSpacing, 0, t),
          icon: Transform.rotate(
            angle: t * math.pi / 4,
            child: Icon(icon, size: _iconSize),
          ),
          // Hidden label must not be read out next to the close tooltip.
          label: ExcludeSemantics(
            excluding: open,
            child: ClipRect(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 1 - t,
                child: Opacity(opacity: 1 - t, child: FoxFabLabel(label)),
              ),
            ),
          ),
        );
      },
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// Clips to the scroll view's bounds widened by [right] on the right.
class _ShadowRoomClipper extends CustomClipper<Rect> {
  final double right;

  const _ShadowRoomClipper({required this.right});

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, 0, size.width + right, size.height);

  @override
  bool shouldReclip(_ShadowRoomClipper oldClipper) => oldClipper.right != right;
}

/// Dimmed, tappable backdrop behind an open [SpeedDial], fading with
/// [animation]. Put it last in the body's `Stack`: it also hides what's
/// painted before it from screen readers (`BlockSemantics`). Mount it only
/// while [animation] isn't dismissed.
class SpeedDialScrim extends StatelessWidget {
  final Animation<double> animation;
  final VoidCallback onTap;

  const SpeedDialScrim({
    super.key,
    required this.animation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BlockSemantics(
      child: FadeTransition(
        opacity: animation,
        child: GestureDetector(
          onTap: onTap,
          child: Container(color: Colors.black54),
        ),
      ),
    );
  }
}
