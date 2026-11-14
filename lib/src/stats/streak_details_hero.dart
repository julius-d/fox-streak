// Top of the Streak Details screen (issue #128): the flame "hero" with the
// current streak number + a situation-dependent line, and the three stat
// tiles (longest streak, practice days, streak freezes) underneath.
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'activity_calendar.dart';
import 'streak_motion.dart';

/// Which encouraging line the hero shows.
enum StreakHeroMood { practicedToday, notYetToday, noStreak }

StreakHeroMood streakHeroMoodFor(ActivityCalendarData data) {
  if (data.currentStreakCount <= 0) return StreakHeroMood.noStreak;
  return data.practicedToday
      ? StreakHeroMood.practicedToday
      : StreakHeroMood.notYetToday;
}

/// Large flame + current streak number, counting up from 0 and flickering
/// gently each time the screen opens (skipped under reduce motion). A 0
/// streak shows a still, dimmed flame and an inviting line instead.
class StreakHero extends StatefulWidget {
  final ActivityCalendarData data;

  const StreakHero({super.key, required this.data});

  @override
  State<StreakHero> createState() => _StreakHeroState();
}

class _StreakHeroState extends State<StreakHero> with TickerProviderStateMixin {
  late final AnimationController _countUp = AnimationController(
    vsync: this,
    duration: kStreakCountUpDuration,
  );
  late final AnimationController _flicker = AnimationController(
    vsync: this,
    duration: kStreakPulseCycle * kStreakPulseCycles,
  );
  bool _animationsStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool hasStreak = widget.data.currentStreakCount > 0;
    if (MediaQuery.disableAnimationsOf(context) || !hasStreak) {
      _countUp.value = 1;
      _flicker
        ..stop()
        ..value = 0;
    } else if (!_animationsStarted) {
      _countUp.forward(from: 0);
      _flicker.forward(from: 0);
    }
    _animationsStarted = true;
  }

  /// The count-up's current frame of [streak] — eased, so it slows down
  /// as it lands on the final value.
  int _countedUp(int streak) =>
      (Curves.easeOutCubic.transform(_countUp.value) * streak).round();

  @override
  void dispose() {
    _countUp.dispose();
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final FoxSemanticColors semantics = foxSemantics(context);
    final int streak = widget.data.currentStreakCount;
    final StreakHeroMood mood = streakHeroMoodFor(widget.data);
    final bool dimmed = mood == StreakHeroMood.noStreak;
    final Color flameColor = dimmed
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.38)
        : semantics.flame;
    final String line = switch (mood) {
      StreakHeroMood.practicedToday => l10n.streakDetailsHeroPracticedToday,
      StreakHeroMood.notYetToday => l10n.streakDetailsHeroNotYetToday,
      StreakHeroMood.noStreak => l10n.streakDetailsHeroNoStreak,
    };
    return MergeSemantics(
      key: const Key('streakHero'),
      child: Column(
        children: [
          Semantics(
            label: l10n.streakDetailsCurrentStreakHeadline(streak),
            // The visual number counts up; screen readers get the final
            // value from the label above instead of an in-between frame.
            child: ExcludeSemantics(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: FoxSpacing.sm,
                children: [
                  AnimatedBuilder(
                    animation: _flicker,
                    builder: (context, child) {
                      final double wave = streakPulseWave(_flicker.value);
                      return Transform.scale(
                        scale: 1 + 0.08 * wave,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      );
                    },
                    child: Icon(
                      Icons.local_fire_department,
                      key: const Key('streakHeroFlame'),
                      size: 72,
                      color: flameColor,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _countUp,
                    builder: (context, _) => Text(
                      '${_countedUp(streak)}',
                      key: const Key('streakHeroCount'),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: dimmed
                            ? theme.colorScheme.onSurfaceVariant
                            : semantics.flame,
                      ),
                    ),
                  ),
                  Text(
                    l10n.streakDetailsHeroDaysLabel(streak),
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: FoxSpacing.xs),
          Text(
            line,
            key: const Key('streakHeroLine'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// The three stat tiles under the hero. Side by side when they fit; at
/// large font sizes (or on a narrow screen) they stack, one full-width row
/// each, so values and captions wrap instead of clipping.
class StreakStatTiles extends StatelessWidget {
  final ActivityCalendarData data;

  const StreakStatTiles({super.key, required this.data});

  /// Narrowest a side-by-side tile may get, in unscaled dp, before the
  /// tiles stack instead.
  static const double _minTileWidth = 96;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final FoxSemanticColors semantics = foxSemantics(context);
    List<_StatTile> buildTiles({required bool compact}) => [
      _StatTile(
        key: const Key('streakStatLongest'),
        compact: compact,
        icon: Icon(Icons.emoji_events, color: semantics.goldInk, size: 24),
        value: data.longestStreak,
        label: l10n.streakDetailsStatLongestLabel,
        semanticsLabel: l10n.streakDetailsStatLongestSemantics(
          data.longestStreak,
        ),
      ),
      _StatTile(
        key: const Key('streakStatPracticeDays'),
        compact: compact,
        icon: Icon(Icons.event_available, color: semantics.flame, size: 24),
        value: data.practiceDays,
        label: l10n.streakDetailsStatPracticeDaysLabel,
        semanticsLabel: l10n.streakDetailsStatPracticeDaysSemantics(
          data.practiceDays,
        ),
      ),
      _StatTile(
        key: const Key('streakStatFreezes'),
        compact: compact,
        // #127's one streak-freeze glyph: the icy-blue snowflake.
        icon: const FoxStreakFreezeIcon(),
        value: data.streakFreezesAvailable,
        label: l10n.streakDetailsStatFreezesLabel,
        semanticsLabel: l10n.streakFreezesAvailableLabel(
          data.streakFreezesAvailable,
        ),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final double scale = MediaQuery.textScalerOf(context).scale(1);
        const int count = 3;
        final double tileWidth =
            (constraints.maxWidth - FoxSpacing.sm * (count - 1)) / count;
        final bool stacked = tileWidth < _minTileWidth * scale;
        final List<_StatTile> tiles = buildTiles(compact: !stacked);
        if (stacked) {
          return Column(
            key: const Key('streakStatTilesStacked'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(height: FoxSpacing.sm),
                tiles[i],
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            key: const Key('streakStatTilesRow'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: FoxSpacing.sm),
                Expanded(child: tiles[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final Widget icon;
  final int value;
  final String label;
  final String semanticsLabel;

  /// Icon/value/caption stacked vertically (side-by-side tiles) vs. one
  /// horizontal row (stacked tiles at large font sizes).
  final bool compact;

  const _StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.semanticsLabel,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget valueText = Text(
      '$value',
      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    );
    final Widget labelText = Text(
      label,
      textAlign: compact ? TextAlign.center : TextAlign.start,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    return Semantics(
      container: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.md)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FoxSpacing.sm,
            vertical: FoxSpacing.md,
          ),
          child: compact
              ? Column(
                  children: [
                    icon,
                    const SizedBox(height: FoxSpacing.xs),
                    valueText,
                    labelText,
                  ],
                )
              : Row(
                  children: [
                    icon,
                    const SizedBox(width: FoxSpacing.sm),
                    Expanded(child: labelText),
                    const SizedBox(width: FoxSpacing.sm),
                    valueText,
                  ],
                ),
        ),
      ),
    );
  }
}
