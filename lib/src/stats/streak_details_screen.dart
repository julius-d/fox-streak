// Streak Details screen: GitHub-style activity calendar (issue #084).
//
// Reached by tapping Home's StreakBadge. Shows the exact current streak
// (profile.streakCount/lastActiveDay) and the longest run of active days
// within the visible ~6-month window — explicitly labeled as windowed, not
// a lifetime "longest streak ever" claim — above a horizontally scrollable
// calendar, with a legend for the color buckets.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../data/clock.dart' show parseDayString;
import '../theme/fox_streak_theme.dart';
import 'activity_calendar.dart';
import 'activity_calendar_view.dart';
import 'stats_providers.dart';

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

class _StreakDetailsBody extends StatelessWidget {
  final ActivityCalendarData data;
  final AppLocalizations l10n;

  const _StreakDetailsBody({required this.data, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormat = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    );
    String cellSemanticsLabel(ActivityDay day) {
      final String formattedDay = dateFormat.format(parseDayString(day.day)!);
      return day.hasActivity
          ? l10n.streakCalendarCellActivityLabel(formattedDay, day.xpEarned)
          : l10n.streakCalendarCellNoActivityLabel(formattedDay);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(FoxSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.streakDetailsCurrentStreakHeadline(data.currentStreakCount),
              key: const Key('currentStreakHeadline'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: FoxSpacing.xs),
            Text(
              l10n.streakDetailsLongestStreakHeadline(
                data.longestStreakInWindow,
              ),
              key: const Key('longestStreakHeadline'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: FoxSpacing.lg),
            ActivityCalendarView(
              data: data,
              cellSemanticsLabel: cellSemanticsLabel,
            ),
            const SizedBox(height: FoxSpacing.lg),
            _Legend(l10n: l10n),
          ],
        ),
      ),
    );
  }
}

/// Small swatch + label per color bucket, sharing [colorForActivityLevel]
/// with the calendar cells so the two can never drift apart.
class _Legend extends StatelessWidget {
  final AppLocalizations l10n;

  const _Legend({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final Color flame = foxSemantics(context).flame;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final entries = <(ActivityLevel, String)>[
      (ActivityLevel.none, l10n.streakDetailsLegendNone),
      (ActivityLevel.low, l10n.streakDetailsLegendLow),
      (ActivityLevel.medium, l10n.streakDetailsLegendMedium),
      (ActivityLevel.high, l10n.streakDetailsLegendHigh),
    ];
    return Wrap(
      key: const Key('activityCalendarLegend'),
      spacing: FoxSpacing.md,
      runSpacing: FoxSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (level, label) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: FoxSpacing.md,
                height: FoxSpacing.md,
                decoration: BoxDecoration(
                  color: colorForActivityLevel(
                    level,
                    flame: flame,
                    emptyColor: scheme.surfaceContainerHighest,
                  ),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(FoxRadius.sm),
                  ),
                ),
              ),
              const SizedBox(width: FoxSpacing.xs),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
      ],
    );
  }
}
