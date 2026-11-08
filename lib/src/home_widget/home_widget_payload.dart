// Pure state model for the Android home-screen widget (issue #115).
//
// The widget can't run Dart at midnight, so the app pushes *both* the
// current state and the already-resolved "next day" state; the native side
// only compares [HomeWidgetPayload.day] with the device's date and picks one
// (see `FoxStreakWidgetProvider`). All rules (at-risk, ring clamping, today
// handling) therefore live here, unit-tested, not in Kotlin.
import '../../l10n/app_localizations.dart';
import '../data/clock.dart';
import '../data/database.dart';
import '../pet/pet_catalog.dart';

/// What the widget shows for one calendar day.
class HomeWidgetState {
  final int streakCount;
  final int todayXp;
  final int dailyGoalXp;

  /// Daily-goal fill in `0.0..1.0`; clamped at full when the goal is
  /// exceeded (unlike Home's multi-lap `FoxGoalRing`).
  final double ringFill;

  /// Streak > 0 and no activity yet today — dims the flame and shows
  /// [HomeWidgetPayload.atRiskText] when there is room.
  final bool atRisk;

  /// Localized screen-reader description of the whole widget.
  final String description;

  const HomeWidgetState({
    required this.streakCount,
    required this.todayXp,
    required this.dailyGoalXp,
    required this.ringFill,
    required this.atRisk,
    required this.description,
  });

  Map<String, Object?> toMap() => <String, Object?>{
    'streakCount': streakCount,
    'todayXp': todayXp,
    'dailyGoalXp': dailyGoalXp,
    'ringFill': ringFill,
    'atRisk': atRisk,
    'description': description,
  };

  @override
  bool operator ==(Object other) =>
      other is HomeWidgetState &&
      other.streakCount == streakCount &&
      other.todayXp == todayXp &&
      other.dailyGoalXp == dailyGoalXp &&
      other.ringFill == ringFill &&
      other.atRisk == atRisk &&
      other.description == description;

  @override
  int get hashCode => Object.hash(
    streakCount,
    todayXp,
    dailyGoalXp,
    ringFill,
    atRisk,
    description,
  );
}

/// Everything the native widget needs, serialisable over the platform channel.
class HomeWidgetPayload {
  /// Local `YYYY-MM-DD` the [current] state is valid for.
  final String day;

  /// The state while the device date still equals [day].
  final HomeWidgetState current;

  /// The state from the next midnight until the app runs again: 0 XP, empty
  /// ring, streak number kept (it is only settled when the app opens), at
  /// risk if the streak is > 0.
  final HomeWidgetState nextDay;

  /// The equipped pet, rendered as its emoji (the catalog's Noto Emoji pets).
  final String petEmoji;

  final String atRiskText;

  const HomeWidgetPayload({
    required this.day,
    required this.current,
    required this.nextDay,
    required this.petEmoji,
    required this.atRiskText,
  });

  Map<String, Object?> toMap() => <String, Object?>{
    'day': day,
    'current': current.toMap(),
    'nextDay': nextDay.toMap(),
    'petEmoji': petEmoji,
    'atRiskText': atRiskText,
  };

  @override
  bool operator ==(Object other) =>
      other is HomeWidgetPayload &&
      other.day == day &&
      other.current == current &&
      other.nextDay == nextDay &&
      other.petEmoji == petEmoji &&
      other.atRiskText == atRiskText;

  @override
  int get hashCode => Object.hash(day, current, nextDay, petEmoji, atRiskText);
}

/// Ring fill for [todayXp] toward [dailyGoalXp], clamped to `0.0..1.0`.
/// A non-positive goal counts as reached, same as Home's goal ring.
double widgetRingFill(int todayXp, int dailyGoalXp) {
  if (dailyGoalXp <= 0) return 1.0;
  return (todayXp / dailyGoalXp).clamp(0.0, 1.0);
}

HomeWidgetState _state({
  required AppLocalizations l10n,
  required int streakCount,
  required int todayXp,
  required int dailyGoalXp,
  required bool todayDone,
}) {
  return HomeWidgetState(
    streakCount: streakCount,
    todayXp: todayXp,
    dailyGoalXp: dailyGoalXp,
    ringFill: widgetRingFill(todayXp, dailyGoalXp),
    atRisk: streakCount > 0 && !todayDone,
    description: l10n.widgetSemanticsLabel(streakCount, todayXp, dailyGoalXp),
  );
}

/// Builds the payload for [profile] as of [now] and the equipped [pet].
///
/// "Today done" and the day-gated `todayXp` follow Home's rule (the stored
/// `todayXp` is only reset lazily, so it may belong to a previous day).
HomeWidgetPayload buildHomeWidgetPayload({
  required ProfileStat profile,
  required PetEntry pet,
  required DateTime now,
  required AppLocalizations l10n,
}) {
  final String day = toLocalDayString(now);
  final bool todayDone = profile.lastActiveDay == day;
  return HomeWidgetPayload(
    day: day,
    current: _state(
      l10n: l10n,
      streakCount: profile.streakCount,
      todayXp: todayDone ? profile.todayXp : 0,
      dailyGoalXp: profile.dailyGoalXp,
      todayDone: todayDone,
    ),
    nextDay: _state(
      l10n: l10n,
      streakCount: profile.streakCount,
      todayXp: 0,
      dailyGoalXp: profile.dailyGoalXp,
      todayDone: false,
    ),
    petEmoji: pet.emoji,
    atRiskText: l10n.widgetAtRiskText,
  );
}
