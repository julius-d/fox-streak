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

  const LessonState({
    this.sourceItems = const [],
    this.queue = const [],
    this.index = 0,
    this.outcomes = const [],
    this.phase = LessonPhase.answering,
    this.currentDraft,
    this.lastCorrect,
    this.lastCorrectAnswerLabel,
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
          other.lastCorrectAnswerLabel == lastCorrectAnswerLabel);

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
  Random? _random;

  @override
  LessonState build() {
    _statsRepo = ref.read(statsRepositoryProvider);
    _clock = ref.read(systemClockProvider);
    return const LessonState();
  }

  /// Starts a new lesson session with the given items.
  ///
  /// Shuffles once using [_random] (or a fresh Random), caps at 20 items.
  /// Keeps a copy of [items] as [sourceItems] so [restart] can reshuffle.
  /// Resets index, outcomes, phase, and draft.
  void start(List<Item> items, {Random? random}) {
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
  Future<void> submitGrade() async {
    final draft = state.currentDraft;
    final item = state.currentItem;
    if (draft == null || item == null) return;

    final correct = draft.grade();
    final outcome = LessonItemOutcome(
      itemId: item.id,
      correct: correct,
      skipped: false,
      firstTry: true,
      hintUsed: false,
    );

    // Write attempt row immediately (ownership: attempts only).
    await _statsRepo.recordAttempt(
      itemId: item.id,
      ok: correct,
      now: _clock.now(),
    );

    state = state.copyWith(
      outcomes: [...state.outcomes, outcome],
      phase: LessonPhase.feedback,
      lastCorrect: correct,
      lastCorrectAnswerLabel: draft.correctAnswerLabel,
      clearDraft: true,
    );
  }

  /// Skips the current item (SKIP pressed).
  ///
  /// Counts as wrong (skipped=true). Records attempt immediately.
  /// Advances to next item or done phase.
  Future<void> skip() async {
    final item = state.currentItem;
    if (item == null) return;

    final outcome = LessonItemOutcome(
      itemId: item.id,
      correct: false,
      skipped: true,
      firstTry: true,
      hintUsed: false,
    );

    // Write attempt row immediately (ownership: attempts only).
    await _statsRepo.recordAttempt(
      itemId: item.id,
      ok: false,
      now: _clock.now(),
    );

    _advanceAfterOutcome(outcome);
  }

  /// Advances from feedback phase to next item or done (CONTINUE pressed).
  void next() {
    if (state.phase != LessonPhase.feedback) return;
    if (state.index + 1 >= state.queue.length) {
      state = state.copyWith(phase: LessonPhase.done, clearLastCorrect: true);
    } else {
      state = state.copyWith(
        index: state.index + 1,
        phase: LessonPhase.answering,
        clearDraft: true,
        clearLastCorrect: true,
      );
    }
  }

  /// Internal: advances after skip or submit when not using feedback phase.
  void _advanceAfterOutcome(LessonItemOutcome outcome) {
    final newOutcomes = [...state.outcomes, outcome];
    if (state.index + 1 >= state.queue.length) {
      state = state.copyWith(
        outcomes: newOutcomes,
        phase: LessonPhase.done,
        clearLastCorrect: true,
      );
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

  /// Builds the [LessonResult] for the completed session.
  ///
  /// Returns null if the lesson hasn't been started or isn't done.
  LessonResult? buildResult() {
    if (state.queue.isEmpty || !state.isDone) return null;
    final correctCount = state.outcomes.where((o) => o.correct).length;
    final scorePct = state.total == 0
        ? 0
        : ((correctCount / state.total) * 100).round();
    return LessonResult(
      setId: state.queue.first.setId,
      itemIds: state.queue.map((i) => i.id).toList(),
      outcomes: state.outcomes,
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
