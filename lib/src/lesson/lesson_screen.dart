// Lesson shell UI (issue #005).
//
// Top: FoxProgressBar + quit-X (FoxConfirmDialog).
// Middle: ExerciseCard slot (dispatched by item.type).
// Feedback: FoxFeedbackBanner (success/error with correct answer).
// Bottom: FoxCheckButton (CHECK→CONTINUE, same key, tinted by correctState)
//         + FoxSecondaryButton Skip (pre-check only).
// Result: LessonResultScreen (score, mascot, celebrate, Practice again / Back).
//
// All strings via AppLocalizations (DE + EN). Follows #015 kit reuse only.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../library/library_providers.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'exercise_card.dart';
import 'lesson_controller.dart';
import 'lesson_result.dart';
import 'multiple_choice_card.dart';

/// Entry point: navigates to LessonScreen for the given setId.
///
/// Reads items via itemsForSetProvider (snapshot, no new data access).
/// Disables start if empty (SetDetailScreen handles empty CTA).
class LessonEntryButton extends ConsumerWidget {
  final int setId;

  const LessonEntryButton({super.key, required this.setId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final itemsAsync = ref.watch(itemsForSetProvider(setId));

    return itemsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return FoxPrimaryButton(
          key: const Key('startLessonButton'),
          label: l10n.lessonStart,
          expanded: true,
          icon: Icons.play_arrow,
          onPressed: () {
            Navigator.of(context).push<LessonResult?>(
              MaterialPageRoute<LessonResult?>(
                builder: (_) => LessonScreen(setId: setId, items: items),
              ),
            );
          },
        );
      },
    );
  }
}

/// Main lesson screen: progress bar, card, feedback, check/skip buttons.
class LessonScreen extends ConsumerStatefulWidget {
  final int setId;
  final List<Item> items; // If empty, fetches from itemsForSetProvider
  // Test-only: custom card builder for exercise cards.
  // If null, uses the default placeholder (throws in prod, works in tests).
  final Widget Function({
    required Item item,
    required void Function(ExerciseDraft) onStateChanged,
    required AppLocalizations l10n,
    bool autoAnswer,
  })? cardBuilder;

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

    // Handle back button / system back: show quit confirm.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldQuit = await _showQuitDialog(context, l10n);
        if (shouldQuit == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.lessonTitle),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              key: const Key('quitLessonButton'),
              icon: const Icon(Icons.close),
              tooltip: l10n.lessonQuit,
              onPressed: () async {
                final shouldQuit = await _showQuitDialog(context, l10n);
                if (shouldQuit == true && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: FoxSpacing.lg),
              child: FoxProgressBar(
                key: const Key('lessonProgressBar'),
                value: state.progress,
                semanticsLabel: l10n.lessonProgressLabel,
                semanticsValue: '${(state.progress * 100).round()}%',
              ),
            ),
          ),
        ),
        body: items.isEmpty
            ? Center(child: Text(l10n.libraryLoading))
            : state.isDone
                ? _buildResultScreen(context, ref, l10n, controller)
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
              child: _buildExerciseCard(item, controller, l10n),
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
                        state.currentDraft!.correctAnswerLabel,
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
                  onPressed: isFeedback
                      ? () => controller.next()
                      : (hasAnswer ? () => controller.submitGrade() : null),
                  correctState: isFeedback ? state.lastCorrect : null,
                ),
                // Skip button (pre-check only)
                if (!isFeedback)
                  Padding(
                    padding: const EdgeInsets.only(top: FoxSpacing.md),
                    child: FoxSecondaryButton(
                      key: const Key('skipItemButton'),
                      label: l10n.lessonSkip,
                      expanded: true,
                      onPressed: () => controller.skip(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(
    Item item,
    LessonController controller,
    AppLocalizations l10n,
  ) {
    // Dispatch by item.type to the appropriate exercise card.
    // #006 provides MultipleChoiceCard for vocab.
    // #007-#009 will provide cards for phone/date.
    // Auto-answer for test items that have choices (vocab with distractors).
    final autoAnswer =
        item.type == 'vocab' &&
        item.choices != null &&
        item.choices!.isNotEmpty;

    // Use custom card builder if provided (for tests), otherwise use real cards.
    if (widget.cardBuilder != null) {
      return widget.cardBuilder!(
        item: item,
        onStateChanged: controller.updateDraft,
        l10n: l10n,
        autoAnswer: autoAnswer,
      );
    }

    // Real card implementations
    switch (item.type) {
      case 'vocab':
        return MultipleChoiceCard(
          item: item,
          onStateChanged: controller.updateDraft,
          l10n: l10n,
        );
      default:
        // Fallback to placeholder for phone/date until #007-#009
        return _PlaceholderExerciseCard(
          item: item,
          onStateChanged: controller.updateDraft,
          l10n: l10n,
          autoAnswer: autoAnswer,
        );
    }
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
    WidgetRef ref,
    AppLocalizations l10n,
    LessonController controller,
  ) {
    final result = controller.buildResult();
    if (result == null) return const SizedBox.shrink();

    // Pop with result so #010/#011 can consume it via Navigator return.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.of(context).pop(result);
      }
    });

    return LessonResultScreen(
      key: const Key('lessonResultScreen'),
      result: result,
      l10n: l10n,
      onPracticeAgain: () => controller.restart(),
      onBackToLibrary: () => Navigator.of(context).pop(),
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