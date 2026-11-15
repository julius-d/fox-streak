// Streak Details screen (issue #084, glow-up #128, motion #132).
//
// Reached by tapping Home's StreakBadge. A flame hero with the exact
// current streak (profile.streakCount/lastActiveDay) and three all-time
// stat tiles sit above the GitHub-style activity calendar, whose streak
// bands and per-day popup are explained by the legend underneath.
//
// The body owns the screen's [StreakDetailsMotion]: the opening sequence
// starts once the page transition is finished, every animation pauses
// while the screen isn't visible (app hidden, another screen on top), and
// reduce motion shows the final state with nothing looping.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../data/clock.dart' show parseDayString;
import '../theme/fox_streak_theme.dart';
import 'activity_calendar.dart';
import 'activity_calendar_view.dart';
import 'stats_providers.dart';
import 'streak_details_hero.dart';
import 'streak_motion.dart';

class StreakDetailsScreen extends ConsumerWidget {
  const StreakDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final AsyncValue<ActivityCalendarData> dataAsync = ref.watch(
      activityCalendarProvider,
    );
    return Scaffold(
      key: const Key('streakDetailsScreen'),
      appBar: AppBar(title: Text(l10n.streakDetailsTitle)),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text(e.toString())),
        data: (ActivityCalendarData data) =>
            _StreakDetailsBody(data: data, l10n: l10n),
      ),
    );
  }
}

class _StreakDetailsBody extends StatefulWidget {
  final ActivityCalendarData data;
  final AppLocalizations l10n;

  const _StreakDetailsBody({required this.data, required this.l10n});

  @override
  State<_StreakDetailsBody> createState() => _StreakDetailsBodyState();
}

class _StreakDetailsBodyState extends State<_StreakDetailsBody>
    with TickerProviderStateMixin {
  late final StreakDetailsMotion _motion = StreakDetailsMotion(
    vsync: this,
    hasStreak: widget.data.currentStreakCount > 0,
    todayPending: !widget.data.practicedToday,
  );
  late final AppLifecycleListener _lifecycle;

  /// False while another screen covers this one (the navigator mutes a
  /// covered route's tickers through [TickerMode]).
  ValueListenable<TickerModeData>? _tickerMode;
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: (_) => _syncMotion());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _motion.showFinalState();
    final ValueListenable<TickerModeData> tickerMode =
        TickerMode.getValuesNotifier(context);
    if (tickerMode != _tickerMode) {
      _tickerMode?.removeListener(_syncMotion);
      _tickerMode = tickerMode..addListener(_syncMotion);
    }
    final Animation<double>? routeAnimation = ModalRoute.of(context)?.animation;
    if (routeAnimation != _routeAnimation) {
      _routeAnimation?.removeStatusListener(_onRouteStatus);
      _routeAnimation = routeAnimation?..addStatusListener(_onRouteStatus);
    }
    _syncMotion();
  }

  @override
  void didUpdateWidget(_StreakDetailsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.practicedToday) _motion.stopTodayPulse();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _tickerMode?.removeListener(_syncMotion);
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _motion.dispose();
    super.dispose();
  }

  void _onRouteStatus(AnimationStatus _) => _syncMotion();

  /// Starts the opening sequence once the page has fully opened, and pauses
  /// / resumes the motion with the screen's visibility.
  void _syncMotion() {
    final AppLifecycleState? lifecycle = WidgetsBinding.instance.lifecycleState;
    final bool appVisible =
        lifecycle == null ||
        lifecycle == AppLifecycleState.resumed ||
        lifecycle == AppLifecycleState.inactive;
    final bool visible = appVisible && (_tickerMode?.value.enabled ?? true);
    if (!visible) {
      _motion.pause();
      return;
    }
    _motion.resume();
    final bool pageOpened =
        _routeAnimation == null || _routeAnimation!.isCompleted;
    if (pageOpened) _motion.start();
  }

  @override
  Widget build(BuildContext context) {
    final ActivityCalendarData data = widget.data;
    final AppLocalizations l10n = widget.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final DateFormat labelFormat = DateFormat.yMMMd(locale);
    final DateFormat popupFormat = DateFormat.yMMMEd(locale);
    String cellSemanticsLabel(ActivityDay day) {
      final String formattedDay = labelFormat.format(parseDayString(day.day)!);
      return switch (day.state) {
        ActivityDayState.practiced => l10n.streakCalendarCellActivityLabel(
          formattedDay,
          day.xpEarned,
        ),
        ActivityDayState.streakFreeze =>
          l10n.streakCalendarCellStreakOnIceLabel(formattedDay),
        ActivityDayState.none when day.isToday =>
          l10n.streakCalendarCellTodayNotPracticedLabel(formattedDay),
        ActivityDayState.none => l10n.streakCalendarCellNoActivityLabel(
          formattedDay,
        ),
      };
    }

    ActivityDayPopupText dayPopupText(ActivityDay day) => (
      date: popupFormat.format(parseDayString(day.day)!),
      status: switch (day.state) {
        ActivityDayState.practiced => l10n.streakDetailsDayXpEarned(
          day.xpEarned,
        ),
        ActivityDayState.streakFreeze => l10n.streakDetailsDayStreakFreeze,
        ActivityDayState.none when day.isToday =>
          l10n.streakDetailsDayNotYetToday,
        ActivityDayState.none => l10n.streakDetailsDayNoPractice,
      },
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(FoxSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            StreakHero(
              data: data,
              countUp: _motion.countUp,
              flameFlicker: _motion.flameFlicker,
            ),
            const SizedBox(height: FoxSpacing.lg),
            StreakStatTiles(data: data),
            const SizedBox(height: FoxSpacing.xl),
            ActivityCalendarView(
              data: data,
              cellSemanticsLabel: cellSemanticsLabel,
              dayPopupText: dayPopupText,
              bandDrawIn: _motion.bandDrawIn,
              todayPulse: _motion.todayPulse,
            ),
            const SizedBox(height: FoxSpacing.md),
            _Legend(l10n: l10n, showLongestStreak: data.showLongestStreakBand),
          ],
        ),
      ),
    );
  }
}

/// One swatch + label per cell state, plus the longest-streak band while
/// that band is drawn (the current streak's band needs no explanation,
/// #132), sharing [colorForDayState] / [colorForStreakBand] with the
/// calendar so the two can never drift apart.
class _Legend extends StatelessWidget {
  final AppLocalizations l10n;
  final bool showLongestStreak;

  const _Legend({required this.l10n, required this.showLongestStreak});

  @override
  Widget build(BuildContext context) {
    final FoxSemanticColors semantics = foxSemantics(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    Color fill(ActivityDayState state) =>
        colorForDayState(state, semantics: semantics, scheme: scheme);
    return Wrap(
      key: const Key('activityCalendarLegend'),
      spacing: FoxSpacing.md,
      runSpacing: FoxSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LegendEntry(
          label: l10n.streakDetailsLegendPracticed,
          swatch: _FillSwatch(color: fill(ActivityDayState.practiced)),
        ),
        _LegendEntry(
          label: l10n.streakDetailsLegendStreakOnIce,
          swatch: _FillSwatch(color: fill(ActivityDayState.streakFreeze)),
        ),
        _LegendEntry(
          label: l10n.streakDetailsLegendNone,
          swatch: _FillSwatch(color: fill(ActivityDayState.none)),
        ),
        if (showLongestStreak)
          _LegendEntry(
            key: const Key('legendLongestStreak'),
            label: l10n.streakDetailsLegendLongestStreak,
            swatch: _BandSwatch(
              color: colorForStreakBand(StreakBandKind.longest, semantics),
            ),
          ),
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  final String label;
  final Widget swatch;

  const _LegendEntry({super.key, required this.label, required this.swatch});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: swatch),
        const SizedBox(width: FoxSpacing.xs),
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
      ],
    );
  }
}

class _FillSwatch extends StatelessWidget {
  final Color color;

  const _FillSwatch({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: FoxSpacing.md,
      height: FoxSpacing.md,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(FoxSpacing.xs)),
      ),
    );
  }
}

/// A small closed band, drawn by the same painter as the calendar's bands.
class _BandSwatch extends StatelessWidget {
  final Color color;

  const _BandSwatch({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: FoxSpacing.md + FoxSpacing.xs,
      height: FoxSpacing.md + FoxSpacing.xs,
      child: CustomPaint(
        painter: StreakBandPainter(
          color: color,
          openTop: false,
          openBottom: false,
        ),
      ),
    );
  }
}
