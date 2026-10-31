// Lesson shell UI (issue #005).
//
// Top: FoxProgressBar + overflow menu (Quit via FoxConfirmDialog, Skip
// pre-check only — issue #024).
// Middle: ExerciseCard slot (dispatched by item.type).
// Feedback: FoxFeedbackBanner (success/error with correct answer).
// Bottom: FoxCheckButton (CHECK→CONTINUE, same key, tinted by correctState).
// Completion (issue #078): once the lesson is done, a sequential, non-
// skippable, non-back-navigable set of full-screen pushes plays out — loot
// box (#059, if won) -> streak saved (#011, if it advanced today's streak)
// -> XP up (#010/#053, always) -> summary (LessonResultScreen, always:
// pet celebration, score, Home/Set overview/Redo whole set/Redo missed
// items).
//
// All strings via AppLocalizations (DE + EN). Follows #015 kit reuse only.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../library/library_providers.dart';
import '../library/set_detail_screen.dart';
import '../pet/lootbox_screen.dart';
import '../pet/pet_catalog.dart';
import '../pet/pet_providers.dart';
import '../stats/xp_service.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import '../exercises/date_exercise.dart';
import '../exercises/dial_pad_exercise.dart';
import '../exercises/free_text_exercise.dart';
import '../exercises/multiple_choice_exercise.dart';
import 'exercise_card.dart';
import 'lesson_controller.dart';
import 'lesson_result.dart';
import 'streak_saved_screen.dart';
import 'xp_up_screen.dart';

/// Navigates into [LessonScreen] for [setId], or shows the
/// `lessonEmptySetNote` snackbar instead when the set has no items.
///
/// Shared by `SetDetailScreen`'s "Start lesson" FAB and the Library row's
/// play icon (#042) so both entry points stay in lockstep. Both are always
/// enabled by design (never disabled for an empty set — a disabled icon
/// reads as "broken" to a young user), so this reads [itemsAsync] directly
/// rather than collapsing it to a plain list beforehand: while it's still
/// loading there's no reliable answer yet to "is this set empty", so the
/// tap is a no-op rather than risking a false "empty" snackbar for a set
/// that actually has items (the narrow window right after navigating in,
/// before the first stream emission arrives).
void startLessonFromSet({
  required BuildContext context,
  required int setId,
  required AsyncValue<List<Item>> itemsAsync,
  required AppLocalizations l10n,
}) {
  if (itemsAsync.isLoading) return;
  final items = itemsAsync.value ?? const <Item>[];
  if (items.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.lessonEmptySetNote)));
    return;
  }
  Navigator.of(context).push<LessonResult?>(
    MaterialPageRoute<LessonResult?>(
      builder: (_) => LessonScreen(setId: setId, items: items),
    ),
  );
}

/// Main lesson screen: progress bar, card, feedback, check/skip buttons.
class LessonScreen extends ConsumerStatefulWidget {
  final int setId;
  final List<Item> items; // If empty, fetches from itemsForSetProvider
  // Test-only: custom card builder for exercise cards.
  // If null, uses the default placeholder (throws in prod, works in tests).
  final Widget Function({
    Key? key,
    required Item item,
    required void Function(ExerciseDraft) onStateChanged,
    required AppLocalizations l10n,
    bool autoAnswer,
  })?
  cardBuilder;

  const LessonScreen({
    super.key,
    required this.setId,
    this.items = const [],
    this.cardBuilder,
  });

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  bool _lessonStarted = false;
  // Which `state.attempt` the completion sequence (loot box -> streak saved
  // -> XP up, each a full-screen push) has already been kicked off for —
  // null before the first completion. Keyed on `attempt` (bumped by every
  // `start`/`restart`, issue #072) rather than a plain bool so "Redo whole
  // set"/"Redo missed items" correctly re-triggers the sequence for the new
  // session's own completion instead of treating it as already shown.
  int? _sequenceStartedForAttempt;
  // Which `state.attempt` it's safe to actually render the summary screen
  // (with its `FoxPet`) for — set only once the completion sequence is
  // about to cover it with its first pushed screen (issue #083). Until
  // then, `build` renders a blank placeholder instead: without this gate,
  // the single frame between `state.isDone` turning true and that first
  // push actually landing would flash the summary/pet screen underneath.
  int? _revealResultForAttempt;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _ensureLessonStarted(List<Item> items) {
    if (!_lessonStarted && items.isNotEmpty) {
      _lessonStarted = true;
      // Defer to after build to avoid modifying provider during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(lessonControllerProvider.notifier).start(items);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // If items were passed in, use them; otherwise fetch from provider.
    final itemsAsync = widget.items.isNotEmpty
        ? null
        : ref.watch(itemsForSetProvider(widget.setId));

    final items = widget.items.isNotEmpty
        ? widget.items
        : itemsAsync?.asData?.value ?? [];

    // Start the lesson once we have items (deferred to after build).
    _ensureLessonStarted(items);

    final state = ref.watch(lessonControllerProvider);
    final controller = ref.read(lessonControllerProvider.notifier);
    final result = state.isDone ? controller.buildResult() : null;

    if (result != null) {
      _ensureCompletionSequenceStarted(state);
    }

    // Once the lesson is done there's nothing left to lose: back nav (system
    // back or the X) goes straight Home, no confirm. Mid-lesson, back nav
    // goes through the quit-confirm dialog instead. The completion sequence
    // itself (loot box/streak/XP, each pushed on top) has no back nav of its
    // own, same as this screen's own PopScope while mid-lesson.
    Future<void> handleBack() async {
      if (state.isDone) {
        _goHome(context);
        return;
      }
      final shouldQuit = await _showQuitDialog(context, l10n);
      if (shouldQuit == true && context.mounted) {
        Navigator.of(context).pop();
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.lessonTitle),
          automaticallyImplyLeading: false,
          actions: [
            PopupMenuButton<String>(
              key: const Key('lessonOverflowMenu'),
              tooltip: l10n.lessonActions,
              onSelected: (value) {
                if (value == 'quit') {
                  handleBack();
                } else if (value == 'skip') {
                  controller.skip();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'quit',
                  key: const Key('quitLessonMenuItem'),
                  child: Text(l10n.lessonQuit),
                ),
                // Hidden while busy too: Skip would otherwise be a live UI
                // target during a still-in-flight CHECK, and the shared
                // in-flight guard (#031) silently drops it rather than
                // risking a double outcome for the same item.
                if (state.phase == LessonPhase.answering && !state.busy)
                  PopupMenuItem(
                    value: 'skip',
                    key: const Key('skipItemMenuItem'),
                    child: Text(l10n.lessonSkip),
                  ),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: FoxSpacing.lg),
              // Keyed on state.attempt (issue #072): a new attempt forces a
              // fresh FoxProgressBar/TweenAnimationBuilder subtree instead of
              // tweening the 1.0 -> 0.0 drop that "Practice again" causes.
              // The inner Key('lessonProgressBar') stays stable for widget
              // lookups (home_screen_test.dart, lesson_shell_test.dart).
              child: KeyedSubtree(
                key: ValueKey(state.attempt),
                child: FoxProgressBar(
                  key: const Key('lessonProgressBar'),
                  value: state.progress,
                  animated: true,
                  semanticsLabel: l10n.lessonProgressLabel,
                  semanticsValue: '${(state.progress * 100).round()}%',
                ),
              ),
            ),
          ),
        ),
        body: items.isEmpty
            ? Center(child: Text(l10n.libraryLoading))
            : result != null
            ? (_revealResultForAttempt == state.attempt
                  ? _buildResultScreen(context, l10n, state, controller, result)
                  : const SizedBox.shrink())
            : _buildLessonBody(context, ref, l10n, state, controller),
      ),
    );
  }

  Widget _buildLessonBody(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    LessonState state,
    LessonController controller,
  ) {
    final item = state.currentItem;
    if (item == null) {
      return const SizedBox.shrink();
    }

    final isFeedback = state.phase == LessonPhase.feedback;
    final hasAnswer = state.currentDraft?.hasAnswer ?? false;

    return SafeArea(
      child: Column(
        children: [
          // Card slot — dispatched by item.type
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(FoxSpacing.lg),
              child: _buildExerciseCard(
                item,
                controller,
                l10n,
                state.sourceItems,
                isFeedback,
              ),
            ),
          ),
          // Feedback banner (shown in feedback phase)
          if (isFeedback && state.lastCorrect != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FoxSpacing.lg,
                vertical: FoxSpacing.sm,
              ),
              child: FoxFeedbackBanner(
                key: const Key('lessonFeedbackBanner'),
                variant: state.lastCorrect!
                    ? FoxFeedbackVariant.success
                    : FoxFeedbackVariant.error,
                message: state.lastCorrect!
                    ? l10n.lessonCorrect
                    : l10n.lessonWrongAnswer(
                        state.lastCorrectAnswerLabel ?? '',
                      ),
              ),
            ),
          // Bottom buttons
          Padding(
            padding: const EdgeInsets.all(FoxSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // CHECK / CONTINUE button (same key, label flips)
                FoxCheckButton(
                  key: const Key('checkButton'),
                  label: isFeedback ? l10n.lessonContinue : l10n.lessonCheck,
                  onPressed: state.busy
                      ? null
                      : (isFeedback
                            ? () => controller.next()
                            : (hasAnswer
                                  ? () =>
                                        _submitAndBuzz(context, ref, controller)
                                  : null)),
                  correctState: isFeedback ? state.lastCorrect : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Grades the current answer, then fires the correct/wrong haptic moment
  /// (behind [foxHapticsEnabledProvider]) plus, on a correct answer, the
  /// congratulation chime (behind [foxSoundEnabledProvider], issue #054)
  /// once the result is known.
  Future<void> _submitAndBuzz(
    BuildContext context,
    WidgetRef ref,
    LessonController controller,
  ) async {
    await controller.submitGrade();
    final correct = ref.read(lessonControllerProvider).lastCorrect;
    if (correct == null || !context.mounted) return;
    if (correct) {
      await FoxFeedback.correctAnswer(context, ref);
    } else {
      await FoxFeedback.error(context, ref);
    }
  }

  Widget _buildExerciseCard(
    Item item,
    LessonController controller,
    AppLocalizations l10n,
    List<Item> otherSetItems,
    bool isFeedback,
  ) {
    // Dispatch by item.type to the appropriate exercise card.
    // #006 provides MultipleChoiceCard for 'choice', #007 the free-text
    // card for 'freeText', #008 the dial pad for 'phone', #009 the
    // calendar-styled fields for 'date' (#026 renamed vocab -> choice and
    // wired freeText into this dispatch).
    // Auto-answer for test items that have choices ('choice' with distractors).
    final autoAnswer =
        item.type == 'choice' &&
        item.choices != null &&
        item.choices!.isNotEmpty;

    // Keyed by item.id: these cards cache per-question state (e.g.
    // MultipleChoiceCard's shuffled options) in initState, so without a
    // per-item key Flutter would reuse the same State — and its stale
    // options/answer — across different items of the same type.
    final cardKey = ValueKey(item.id);

    // Use custom card builder if provided (for tests), otherwise use real cards.
    if (widget.cardBuilder != null) {
      return widget.cardBuilder!(
        key: cardKey,
        item: item,
        onStateChanged: controller.updateDraft,
        l10n: l10n,
        autoAnswer: autoAnswer,
      );
    }

    // Real card implementations.
    switch (item.type) {
      case 'choice':
        return buildMultipleChoiceExercise(
          key: cardKey,
          item: item,
          otherSetItems: otherSetItems,
          onStateChanged: controller.updateDraft,
          l10n: l10n,
          revealed: isFeedback,
        );
      case 'freeText':
        return buildFreeTextExercise(
          key: cardKey,
          item: item,
          onStateChanged: controller.updateDraft,
          l10n: l10n,
        );
      case 'phone':
        return buildDialPadExercise(
          key: cardKey,
          item: item,
          onStateChanged: controller.updateDraft,
          l10n: l10n,
          autoAnswer: autoAnswer,
        );
      case 'date':
        return buildDateExercise(
          key: cardKey,
          item: item,
          onStateChanged: controller.updateDraft,
          l10n: l10n,
          autoAnswer: autoAnswer,
        );
      default:
        return _PlaceholderExerciseCard(
          key: cardKey,
          item: item,
          onStateChanged: controller.updateDraft,
          l10n: l10n,
          autoAnswer: autoAnswer,
        );
    }
  }

  /// Kicks off the post-lesson completion sequence (issue #078) exactly
  /// once per [LessonState.attempt] — guarded by [_sequenceStartedForAttempt]
  /// so a rebuild while mid-sequence (or landing on `done` again via
  /// rebuild/rotation replaying the same state, see `LessonController`'s
  /// class doc) never re-triggers it. Deferred to after build (like
  /// [_ensureLessonStarted]) since pushing a route during build isn't safe.
  ///
  /// Captures only [state.attempt], not [state]/[result] themselves: when
  /// this same [LessonScreen] route is reused for a brand-new session
  /// (Home's Continue button pushes a fresh `LessonScreen(setId: ...)`
  /// with no `items`, so the *first* build of the new instance still sees
  /// the *previous* instance's stale provider state for one frame, since
  /// `_ensureLessonStarted`'s own `start()` call is deferred the same way
  /// — issue #078 regression found via `issue062_lootbox_animation_test`),
  /// a closure holding that stale `state`/`result` would still push the
  /// wrong screen once its callback runs. [_runCompletionSequence]
  /// re-reads the live state instead and bails if [attempt] no longer
  /// matches it.
  void _ensureCompletionSequenceStarted(LessonState state) {
    if (_sequenceStartedForAttempt == state.attempt) return;
    _sequenceStartedForAttempt = state.attempt;
    final attempt = state.attempt;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _runCompletionSequence(attempt);
      }
    });
  }

  /// Pushes each applicable completion screen in turn — loot box (#059, if
  /// [LessonState.lootboxReward] isn't null) -> streak saved (#011, if
  /// [LessonState.streakIsNewDayAfterLesson]) -> XP up (#010/#053, always)
  /// — awaiting each Continue tap before pushing the next. Once the last
  /// one pops, the summary screen underneath (already the current body) is
  /// revealed.
  ///
  /// Re-reads the controller's live state/result rather than trusting
  /// values captured when this was scheduled, and bails entirely if
  /// [attempt] no longer matches — see [_ensureCompletionSequenceStarted].
  Future<void> _runCompletionSequence(int attempt) async {
    final state = ref.read(lessonControllerProvider);
    if (state.attempt != attempt || !state.isDone) return;
    final result = ref.read(lessonControllerProvider.notifier).buildResult();
    if (result == null) return;
    final l10n = AppLocalizations.of(context)!;

    // From here on, the summary screen underneath is safe to actually
    // build: the very next statement pushes the first completion-sequence
    // screen on top of it, so both changes land in the same frame — no
    // frame ever shows the bare summary/pet (issue #083).
    setState(() => _revealResultForAttempt = attempt);

    final lootboxReward = state.lootboxReward;
    if (lootboxReward != null) {
      if (!await _pushAndWait(
        (_) => LootboxScreen(reward: lootboxReward, l10n: l10n),
      )) {
        return;
      }
    }
    if (state.streakIsNewDayAfterLesson == true) {
      if (!await _pushAndWait(
        (_) => StreakSavedScreen(
          streakCount: state.streakCountAfterLesson ?? 0,
          l10n: l10n,
        ),
      )) {
        return;
      }
    }
    await _pushAndWait(
      (_) => XpUpScreen(
        xpEarned: XpService.xpEarned(result),
        bonus: XpService.lessonBonus(result),
        xpTotal: state.xpTotalAfterLesson ?? 0,
        xpTotalBefore: state.xpTotalBeforeLesson,
        l10n: l10n,
      ),
    );
  }

  /// Pushes [builder] and awaits its pop, returning whether this screen is
  /// still mounted afterward — the shared guard every completion-sequence
  /// step needs before pushing the next one.
  Future<bool> _pushAndWait(WidgetBuilder builder) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: builder));
    return mounted;
  }

  /// Pops back to Home (the app's root route) regardless of how deep the
  /// entry-point stack is — Home's Continue button, the Library row's play
  /// icon, and a set's "Start lesson" FAB all land here identically (issue
  /// #078 retires the old entry-point-specific `backLabel`).
  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Pops back to Home, then pushes `SetDetailScreen` for [setId] on top —
  /// same "regardless of entry point" guarantee as [_goHome].
  void _goToSetOverview(BuildContext context, int setId) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => SetDetailScreen(setId: setId)),
    );
  }

  Future<bool?> _showQuitDialog(BuildContext context, AppLocalizations l10n) {
    return FoxConfirmDialog.show(
      context: context,
      title: l10n.lessonQuitTitle,
      message: l10n.lessonQuitMessage,
      confirmLabel: l10n.lessonConfirmQuit,
      cancelLabel: l10n.cancel,
      confirmKey: const Key('confirmQuitLessonButton'),
    );
  }

  Widget _buildResultScreen(
    BuildContext context,
    AppLocalizations l10n,
    LessonState state,
    LessonController controller,
    LessonResult result,
  ) {
    // Resolved against the asset-backed catalog (not drift) — see
    // `LessonState.equippedPetId` for why this avoids `equippedPetProvider`
    // (which would watch the live, drift-backed `profileProvider` stream).
    final catalog = ref.watch(petCatalogProvider).asData?.value;
    final pet = catalog == null
        ? PetCatalog.defaultEntry
        : catalog.firstWhere(
            (entry) => entry.id == state.equippedPetId,
            orElse: () => PetCatalog.defaultEntry,
          );
    final missedItems = controller.missedItems();

    return LessonResultScreen(
      key: const Key('lessonResultScreen'),
      result: result,
      l10n: l10n,
      pet: pet,
      onHome: () => _goHome(context),
      onSetOverview: () => _goToSetOverview(context, result.setId),
      onRedoWholeSet: () => controller.restart(),
      onRedoMissedItems: missedItems.isEmpty
          ? null
          : () => controller.restartWithItems(missedItems),
    );
  }
}

/// Placeholder exercise card implementing the ExerciseCard contract.
///
/// Used for shell tests and as a stand-in until #006–#009 provide real cards.
/// This is intentionally minimal — real cards will have proper UIs.
class _PlaceholderExerciseCard extends StatelessWidget {
  final Item item;
  final void Function(ExerciseDraft) onStateChanged;
  final AppLocalizations l10n;
  final bool autoAnswer; // For tests: immediately report a correct answer

  const _PlaceholderExerciseCard({
    super.key,
    required this.item,
    required this.onStateChanged,
    required this.l10n,
    this.autoAnswer = false,
  });

  @override
  Widget build(BuildContext context) {
    // In production, this should never be reached since real cards will be
    // implemented in #006–#009. For tests, we use the test helper version.
    throw UnimplementedError(
      'Real exercise cards not yet implemented. '
      'Use PlaceholderExerciseCard from test/helpers/placeholder_exercise_card.dart for tests.',
    );
  }
}
