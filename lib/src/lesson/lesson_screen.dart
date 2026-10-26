// Lesson shell UI (issue #005).
//
// Top: FoxProgressBar + overflow menu (Quit via FoxConfirmDialog, Skip
// pre-check only — issue #024).
// Middle: ExerciseCard slot (dispatched by item.type).
// Feedback: FoxFeedbackBanner (success/error with correct answer).
// Bottom: FoxCheckButton (CHECK→CONTINUE, same key, tinted by correctState).
// Result: LessonResultScreen (score, pet, celebrate, Practice again / Back).
//
// All strings via AppLocalizations (DE + EN). Follows #015 kit reuse only.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../library/library_providers.dart';
import '../pet/lootbox_screen.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import '../exercises/date_exercise.dart';
import '../exercises/dial_pad_exercise.dart';
import '../exercises/free_text_exercise.dart';
import '../exercises/multiple_choice_exercise.dart';
import 'exercise_card.dart';
import 'lesson_controller.dart';
import 'lesson_result.dart';

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
  // Result screen's "back" button label (issue #034): the button just pops
  // the navigator, so the caller — whoever pushed this screen — is the only
  // one who knows where that actually lands. Defaults to the library-flow
  // wording (SetDetailScreen's "Start lesson" FAB, Library's play icon —
  // #042); callers that push this screen directly from elsewhere (e.g.
  // Home's Continue button) must pass their own accurate label.
  final String? backLabel;
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
    this.backLabel,
    this.cardBuilder,
  });

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  bool _lessonStarted = false;
  // Guards against showing the lootbox twice for the same session (e.g. the
  // overflow menu's quit path and the result screen's own back button both
  // ultimately call `_continueFromResult`).
  bool _lootboxShown = false;
  // Guards `_continueFromResult` itself against a second near-simultaneous
  // call landing mid-`await` (e.g. the overflow menu's quit and the result
  // screen's own back button both tapped before the first call's lootbox
  // push resolves) — without this, the second call would see `_lootboxShown`
  // already true and immediately pop whatever is currently on top (the
  // first call's just-pushed `LootboxScreen`) instead of waiting its turn.
  bool _continuingFromResult = false;

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

    // Once the lesson is done there's nothing left to lose: back nav (system
    // back or the X) pops straight to detail with the result, no confirm —
    // but still gives the #059 lootbox a chance to show first. Mid-lesson,
    // back nav goes through the quit-confirm dialog instead.
    Future<void> handleBack() async {
      if (state.isDone) {
        final result = controller.buildResult();
        if (result != null) {
          await _continueFromResult(result, l10n);
        } else {
          Navigator.of(context).pop();
        }
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
        body: items.isEmpty
            ? Center(child: Text(l10n.libraryLoading))
            : state.isDone
            ? _buildResultScreen(context, l10n, controller)
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

  /// Shows the #059 lootbox reveal once, if this lesson's completion won
  /// one, then pops [result] to the caller's original destination —
  /// shared by the result screen's own "back" button and the overflow
  /// menu/system-back path (both of which land on the same done state).
  Future<void> _continueFromResult(
    LessonResult result,
    AppLocalizations l10n,
  ) async {
    if (_continuingFromResult) return;
    _continuingFromResult = true;
    final lootboxReward = ref.read(lessonControllerProvider).lootboxReward;
    if (lootboxReward != null && !_lootboxShown) {
      _lootboxShown = true;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LootboxScreen(reward: lootboxReward, l10n: l10n),
        ),
      );
      if (!mounted) return;
    }
    Navigator.of(context).pop(result);
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
    LessonController controller,
  ) {
    final result = controller.buildResult();
    if (result == null) return const SizedBox.shrink();

    // Pop with result (user-initiated) so #010/#011 can consume it via
    // Navigator return; also exposed via lessonResultProvider.
    return LessonResultScreen(
      key: const Key('lessonResultScreen'),
      result: result,
      l10n: l10n,
      onPracticeAgain: () => controller.restart(),
      onBackToLibrary: () => _continueFromResult(result, l10n),
      backLabel: widget.backLabel ?? l10n.lessonBackToLibrary,
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
