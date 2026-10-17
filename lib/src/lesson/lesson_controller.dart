// Lesson controller + state (issue #005).
//
// Riverpod NotifierProvider (NOT autoDispose) so rotation rebuilds lose nothing.
// Owns: queue (shuffled & capped at 20), index, outcomes, phase.
// Dispatches items by type to #006–#009 cards via ExerciseCardBuilder.
// Writes attempts rows immediately on each submit/skip via StatsRepository.

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/clock.dart';
import '../data/database.dart';
import '../data/providers.dart';
import '../data/stats_repository.dart';
import '../mascot/mascot_catalog.dart';
import '../stats/mascot_service.dart';
import '../stats/streak_service.dart';
import '../stats/xp_service.dart';
import 'exercise_card.dart';

/// Internal state held by the lesson controller.
///
/// [sourceItems] is kept so Practice-again can reshuffle the same set.
/// [queue] is the shuffled & capped (max 20) list for this session.
/// [index] is the current position in [queue].
/// [outcomes] accumulates one outcome per answered item.
/// [phase] tracks the current question phase.
/// [currentDraft] holds the latest ExerciseDraft from the active card
///   so the shell can call grade() on CHECK.
/// [lastCorrect] remembers the last grade result for the FoxCheckButton tint.
/// [xpApplied] guards #010's XP write so rebuild/rotation (which replays
///   this same state) can never re-apply it; #011's streak write reuses the
///   same gate instead of adding a second one.
/// [xpTotalAfterLesson] is the lifetime `xpTotal` returned by that write,
///   handed to the result screen so it never has to re-query the database
///   (and never has to hold open a `watch()` stream of its own) to show
///   the level-progress bar.
/// [xpTotalBeforeLesson] is the lifetime `xpTotal` immediately *before* that
///   same write (issue #053), handed to the result screen so it can compute
///   `XpService.levelForXp(before) != XpService.levelForXp(after)` and show
///   the level-up celebration without a second database query.
/// [streakCountAfterLesson] is the `streak_count` returned by #011's streak
///   write, handed to the result screen the same way for `StreakBadge`.
/// [wonMascot] is the catalog entry #059's `MascotService` returned for
///   this lesson completion (the twice-a-day lootbox trigger), or null if
///   no lootbox should be shown — handed to `LessonScreen` so it can insert
///   the lootbox reveal before continuing to the caller's destination.
/// [equippedMascotId] is the profile's `equippedMascotId` at completion
///   time, snapshotted the same one-shot way as `xpTotalAfterLesson` —
///   the result screen resolves it against `mascotCatalogProvider` (no
///   drift involved) instead of watching the live `profileProvider`
///   stream, which it would otherwise have to hold open for a screen
///   that, like the XP/streak fields above, is a one-shot snapshot, not
///   a live-updating dashboard.
/// [busy] mirrors the controller's in-flight guard (issue #031) so the
///   shell can disable CHECK/CONTINUE and hide Skip while a prior
///   submitGrade/skip/next call hasn't resolved yet — otherwise e.g. a
///   Skip tap landing while CHECK's write is still in flight would be
///   silently dropped by the guard with no visible affordance.
class LessonState {
  final List<Item> sourceItems;
  final List<Item> queue;
  final int index;
  final List<LessonItemOutcome> outcomes;
  final LessonPhase phase;
  final ExerciseDraft? currentDraft;
  final bool? lastCorrect;
  // Snapshot of the graded draft's correctAnswerLabel, taken at grade time —
  // currentDraft itself is cleared on grade, but the feedback banner still
  // needs this label while showing the wrong-answer message.
  final String? lastCorrectAnswerLabel;
  final bool xpApplied;
  final int? xpTotalBeforeLesson;
  final int? xpTotalAfterLesson;
  final int? streakCountAfterLesson;
  final MascotEntry? wonMascot;
  final String? equippedMascotId;
  final bool busy;

  const LessonState({
    this.sourceItems = const [],
    this.queue = const [],
    this.index = 0,
    this.outcomes = const [],
    this.phase = LessonPhase.answering,
    this.currentDraft,
    this.lastCorrect,
    this.lastCorrectAnswerLabel,
    this.xpApplied = false,
    this.xpTotalBeforeLesson,
    this.xpTotalAfterLesson,
    this.streakCountAfterLesson,
    this.wonMascot,
    this.equippedMascotId,
    this.busy = false,
  });

  LessonState copyWith({
    List<Item>? sourceItems,
    List<Item>? queue,
    int? index,
    List<LessonItemOutcome>? outcomes,
    LessonPhase? phase,
    ExerciseDraft? currentDraft,
    bool? lastCorrect,
    String? lastCorrectAnswerLabel,
    bool? xpApplied,
    int? xpTotalBeforeLesson,
    int? xpTotalAfterLesson,
    int? streakCountAfterLesson,
    MascotEntry? wonMascot,
    String? equippedMascotId,
    bool? busy,
    bool clearDraft = false,
    bool clearLastCorrect = false,
  }) {
    return LessonState(
      sourceItems: sourceItems ?? this.sourceItems,
      queue: queue ?? this.queue,
      index: index ?? this.index,
      outcomes: outcomes ?? this.outcomes,
      phase: phase ?? this.phase,
      currentDraft: clearDraft ? null : (currentDraft ?? this.currentDraft),
      lastCorrect: clearLastCorrect ? null : (lastCorrect ?? this.lastCorrect),
      lastCorrectAnswerLabel: clearLastCorrect
          ? null
          : (lastCorrectAnswerLabel ?? this.lastCorrectAnswerLabel),
      xpApplied: xpApplied ?? this.xpApplied,
      xpTotalBeforeLesson: xpTotalBeforeLesson ?? this.xpTotalBeforeLesson,
      xpTotalAfterLesson: xpTotalAfterLesson ?? this.xpTotalAfterLesson,
      streakCountAfterLesson:
          streakCountAfterLesson ?? this.streakCountAfterLesson,
      wonMascot: wonMascot ?? this.wonMascot,
      equippedMascotId: equippedMascotId ?? this.equippedMascotId,
      busy: busy ?? this.busy,
    );
  }

  /// Current item being answered, or null if done.
  Item? get currentItem {
    if (index >= 0 && index < queue.length) return queue[index];
    return null;
  }

  /// Total items in this lesson session.
  int get total => queue.length;

  /// Number of items already answered (outcomes.length).
  int get answeredCount => outcomes.length;

  /// Progress as a fraction 0..1 (for FoxProgressBar).
  double get progress => total == 0 ? 0 : answeredCount / total;

  /// Whether the lesson is complete.
  bool get isDone => phase == LessonPhase.done;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LessonState &&
          other.sourceItems.length == sourceItems.length &&
          other.sourceItems.every((e) => sourceItems.contains(e)) &&
          other.queue.length == queue.length &&
          other.queue.every((e) => queue.contains(e)) &&
          other.index == index &&
          other.outcomes.length == outcomes.length &&
          other.outcomes.every((e) => outcomes.contains(e)) &&
          other.phase == phase &&
          other.currentDraft == currentDraft &&
          other.lastCorrect == lastCorrect &&
          other.lastCorrectAnswerLabel == lastCorrectAnswerLabel &&
          other.xpApplied == xpApplied &&
          other.xpTotalBeforeLesson == xpTotalBeforeLesson &&
          other.xpTotalAfterLesson == xpTotalAfterLesson &&
          other.streakCountAfterLesson == streakCountAfterLesson &&
          other.wonMascot == wonMascot &&
          other.equippedMascotId == equippedMascotId &&
          other.busy == busy);

  @override
  int get hashCode => Object.hash(
    sourceItems,
    queue,
    index,
    outcomes,
    phase,
    currentDraft,
    lastCorrect,
    lastCorrectAnswerLabel,
    xpApplied,
    xpTotalBeforeLesson,
    streakCountAfterLesson,
    xpTotalAfterLesson,
    wonMascot,
    equippedMascotId,
    busy,
  );
}

/// Riverpod Notifier controlling the lesson session.
///
/// Not autoDispose so state survives config changes (rotation).
/// Call [start] with the set's items to begin a session.
/// Use [submitGrade], [skip], [next], [restart] to drive the flow.
class LessonController extends Notifier<LessonState> {
  late final StatsRepository _statsRepo;
  late final Clock _clock;
  late final XpService _xpService;
  late final StreakService _streakService;
  late final MascotService _mascotService;
  Random? _random;

  // Guards submitGrade/skip/next against a double-tap (or two
  // near-simultaneous calls) firing before the first call's `await` resumes:
  // both would otherwise read the same `state.currentItem`/`state.outcomes`
  // and each write an `attempts` row/`outcomes` entry for the same item
  // (issue #031). Shared across all three: CHECK and Skip are both live UI
  // targets during the `answering` phase, so a CHECK-then-Skip sequence
  // landing in this same window is exactly as unsafe as a same-action
  // double-tap and must be dropped the same way. `state.busy` mirrors this
  // flag so the shell can disable CHECK/hide Skip while it's set, instead
  // of silently swallowing the second tap with no visible affordance.
  bool _actionInFlight = false;

  // Bumped by every [start] (so every [restart], too). A guarded action
  // captures the generation it started with; if [start]/[restart] bumps it
  // mid-`await` (issue #033 — `start`/`restart` are synchronous and don't
  // go through [_guarded]), the stale action's resumed `state = ...` writes
  // compare against this and bail instead of clobbering the fresh
  // post-restart state with data captured from the old session. [start]
  // also force-clears [_actionInFlight] for the same reason: that flag
  // belongs to the now-abandoned generation, so leaving it set would
  // silently drop the first legitimate action on the new session.
  int _generation = 0;

  /// Runs [action] under the [_actionInFlight] guard, mirroring it onto
  /// [LessonState.busy] so the shell can disable/hide the affected buttons
  /// for the duration — shared by [submitGrade], [skip], [next] so the
  /// guard/reset bookkeeping lives in one place.
  ///
  /// [action] receives the generation (see [_generation]) current when it
  /// started, so it can detect a mid-flight [start]/[restart] and skip
  /// writes that would otherwise land on the wrong session (issue #033).
  Future<void> _guarded(Future<void> Function(int generation) action) async {
    if (_actionInFlight) return;
    final generation = _generation;
    _actionInFlight = true;
    state = state.copyWith(busy: true);
    try {
      await action(generation);
    } finally {
      // Only clear the guard/busy flag if this call's generation is still
      // current — a stale call (superseded by start/restart mid-flight)
      // must not touch bookkeeping that now belongs to a newer session.
      if (generation == _generation) {
        _actionInFlight = false;
        state = state.copyWith(busy: false);
      }
    }
  }

  @override
  LessonState build() {
    _statsRepo = ref.read(statsRepositoryProvider);
    _clock = ref.read(systemClockProvider);
    _xpService = ref.read(xpServiceProvider);
    _streakService = ref.read(streakServiceProvider);
    _mascotService = ref.read(mascotServiceProvider);
    return const LessonState();
  }

  /// Starts a new lesson session with the given items.
  ///
  /// Shuffles once using [_random] (or a fresh Random), caps at 20 items.
  /// Keeps a copy of [items] as [sourceItems] so [restart] can reshuffle.
  /// Resets index, outcomes, phase, and draft.
  ///
  /// Bumps [_generation] and clears [_actionInFlight] so a `submitGrade`/
  /// `skip`/`next` call still mid-`await` for the *old* session (issue
  /// #033) neither blocks the first action on this new one nor, once it
  /// resumes, overwrites the state set here — see [_generation] and
  /// [_guarded].
  void start(List<Item> items, {Random? random}) {
    _generation++;
    _actionInFlight = false;
    _random = random;
    final rng = _random ?? Random();
    final shuffled = [...items]..shuffle(rng);
    final queue = shuffled.take(20).toList();
    state = LessonState(
      sourceItems: items,
      queue: queue,
      index: 0,
      outcomes: [],
      phase: queue.isEmpty ? LessonPhase.done : LessonPhase.answering,
      currentDraft: null,
      lastCorrect: null,
    );
  }

  /// Restarts the lesson by reshuffling [sourceItems] (same cap of 20).
  void restart({Random? random}) {
    if (state.sourceItems.isEmpty) return;
    start(state.sourceItems, random: random);
  }

  /// Called by the exercise card whenever its draft state changes.
  ///
  /// The shell uses [draft.hasAnswer] to enable/disable CHECK and stores
  /// [draft.grade] to call later on submit.
  void updateDraft(ExerciseDraft draft) {
    state = state.copyWith(currentDraft: draft, clearLastCorrect: true);
  }

  /// Submits the current answer (CHECK pressed).
  ///
  /// Calls the stored grade function once, records the outcome immediately
  /// via StatsRepository.recordAttempt, updates phase to feedback, and
  /// remembers the result for the button tint.
  Future<void> submitGrade() => _guarded((generation) async {
    final draft = state.currentDraft;
    final item = state.currentItem;
    if (draft == null || item == null) return;

    final correct = draft.grade();
    final outcome = LessonItemOutcome(
      itemId: item.id,
      correct: correct,
      skipped: false,
      firstTry: true,
      hintUsed: draft.hintUsed,
    );

    // Write attempt row immediately (ownership: attempts only).
    await _statsRepo.recordAttempt(
      itemId: item.id,
      ok: correct,
      now: _clock.now(),
    );

    // A start()/restart() mid-`await` (issue #033) means `item`/`outcome`
    // above belong to a now-abandoned session — don't overwrite the fresh
    // state it set.
    if (generation != _generation) return;

    state = state.copyWith(
      outcomes: [...state.outcomes, outcome],
      phase: LessonPhase.feedback,
      lastCorrect: correct,
      lastCorrectAnswerLabel: draft.correctAnswerLabel,
      clearDraft: true,
    );
  });

  /// Skips the current item (SKIP pressed).
  ///
  /// Counts as wrong (skipped=true). Records attempt immediately.
  /// Advances to next item or done phase.
  Future<void> skip() => _guarded((generation) async {
    final item = state.currentItem;
    if (item == null) return;

    final outcome = LessonItemOutcome(
      itemId: item.id,
      correct: false,
      skipped: true,
      firstTry: true,
      hintUsed: state.currentDraft?.hintUsed ?? false,
    );

    // Write attempt row immediately (ownership: attempts only).
    await _statsRepo.recordAttempt(
      itemId: item.id,
      ok: false,
      now: _clock.now(),
    );

    // See the matching comment in submitGrade() (issue #033).
    if (generation != _generation) return;

    await _advanceAfterOutcome(outcome, generation);
  });

  /// Advances from feedback phase to next item or done (CONTINUE pressed).
  Future<void> next() => _guarded((generation) async {
    if (state.phase != LessonPhase.feedback) return;
    if (state.index + 1 >= state.queue.length) {
      await _completeLesson(state.outcomes, generation);
    } else {
      state = state.copyWith(
        index: state.index + 1,
        phase: LessonPhase.answering,
        clearDraft: true,
        clearLastCorrect: true,
      );
    }
  });

  /// Internal: advances after skip or submit when not using feedback phase.
  Future<void> _advanceAfterOutcome(
    LessonItemOutcome outcome,
    int generation,
  ) async {
    final newOutcomes = [...state.outcomes, outcome];
    if (state.index + 1 >= state.queue.length) {
      await _completeLesson(newOutcomes, generation);
    } else {
      state = state.copyWith(
        index: state.index + 1,
        outcomes: newOutcomes,
        phase: LessonPhase.answering,
        clearDraft: true,
        clearLastCorrect: true,
      );
    }
  }

  /// Transitions to `phase: done` and applies this lesson's XP (issue #010),
  /// streak (issue #011), and mascot-lootbox (issue #059) writes as one
  /// atomic step.
  ///
  /// Deliberately does *not* flip `phase` to `done` until all three writes
  /// (and their resulting `xpTotal`/`streakCount`/`wonMascot`) are known:
  /// setting `phase` first and the `*AfterLesson` fields only after a later
  /// `await` would let the result screen render in between on transient
  /// pre-write values (e.g. "Level 1" at 0 XP for a learner who is actually
  /// much further along). [LessonState.xpApplied], flipped synchronously
  /// before the `await`s, guards all three writes against double-apply on
  /// repeated calls — #011/#059 reuse this single gate rather than adding
  /// their own.
  Future<void> _completeLesson(
    List<LessonItemOutcome> outcomes,
    int generation,
  ) async {
    if (state.xpApplied) {
      // #031's `_actionInFlight` guard now stops `skip`/`next` from
      // overlapping, so this path is mainly reached via rebuild/rotation
      // replaying the same state (see class doc) — kept as defense-in-depth
      // regardless. Just make sure this call also lands on `done` without
      // re-applying XP/streak/mascot.
      state = state.copyWith(
        outcomes: outcomes,
        phase: LessonPhase.done,
        clearLastCorrect: true,
      );
      return;
    }
    state = state.copyWith(xpApplied: true);
    final result = _buildResultFromOutcomes(outcomes);
    // The writes below persist real activity (the outcomes were genuinely
    // answered) regardless of a start()/restart() racing this `await`
    // (issue #033), so they still run even for an abandoned session. Only
    // the final `state = ...` is skipped when stale, since that's the one
    // that would overwrite the fresh post-restart state — there's no longer
    // a result screen for this session left to show it to.
    final xpApplication = result == null
        ? null
        : await _xpService.applyLessonResult(result);
    final streakCount = result == null
        ? null
        : (await _streakService.recordActivity()).streakCount;
    // One-shot read (not a `watch()` stream) for the result screen's
    // mascot celebration — see [LessonState.equippedMascotId]. Returned
    // alongside wonMascot from the same `getProfile()` call rather than
    // re-querying the row a second time here.
    final mascotUpdate = result == null
        ? null
        : await _mascotService.recordLessonCompletion();
    if (generation != _generation) return;
    state = state.copyWith(
      outcomes: outcomes,
      phase: LessonPhase.done,
      clearLastCorrect: true,
      xpTotalBeforeLesson: xpApplication?.xpTotalBefore,
      xpTotalAfterLesson: xpApplication?.xpTotal,
      streakCountAfterLesson: streakCount,
      wonMascot: mascotUpdate?.wonMascot,
      equippedMascotId: mascotUpdate?.equippedMascotId,
    );
  }

  /// Builds the [LessonResult] for the completed session.
  ///
  /// Returns null if the lesson hasn't been started or isn't done.
  LessonResult? buildResult() {
    if (!state.isDone) return null;
    return _buildResultFromOutcomes(state.outcomes);
  }

  LessonResult? _buildResultFromOutcomes(List<LessonItemOutcome> outcomes) {
    if (state.queue.isEmpty) return null;
    final correctCount = outcomes.where((o) => o.correct).length;
    final scorePct = state.total == 0
        ? 0
        : ((correctCount / state.total) * 100).round();
    return LessonResult(
      setId: state.queue.first.setId,
      itemIds: state.queue.map((i) => i.id).toList(),
      outcomes: outcomes,
      correctCount: correctCount,
      scorePct: scorePct,
    );
  }
}

/// Provider for the lesson controller (not autoDispose).
final lessonControllerProvider =
    NotifierProvider<LessonController, LessonState>(LessonController.new);

/// Provider for the lesson result (null until lesson is done).
///
/// #010 (XP) and #011 (streak) will watch this to consume the result.
/// Also returned via Navigator.pop(result) from LessonScreen.
final lessonResultProvider = Provider<LessonResult?>((ref) {
  final controller = ref.watch(lessonControllerProvider.notifier);
  return controller.buildResult();
});
