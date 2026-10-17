// Daily lootbox reveal screen (issue #059).
//
// Shown once, after the lesson result screen, on the day the 2nd lesson
// completion triggers it (and only while at least one mascot remains
// unowned) — see `LessonController._completeLesson`/`LessonScreen`. The
// reward itself was already picked + persisted as owned by
// `MascotService.recordLessonCompletion`; this screen is purely the
// tap-to-open reveal moment. Pops itself on Continue, so callers just
// `await Navigator.push(...)` it like `FoxConfirmDialog`.
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'mascot_catalog.dart';

/// Tap-to-open lootbox reveal for a single already-won [reward].
class LootboxScreen extends StatefulWidget {
  final MascotEntry reward;
  final AppLocalizations l10n;

  const LootboxScreen({super.key, required this.reward, required this.l10n});

  @override
  State<LootboxScreen> createState() => _LootboxScreenState();
}

class _LootboxScreenState extends State<LootboxScreen> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = widget.l10n;
    return Scaffold(
      key: const Key('lootboxScreen'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(FoxSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _revealed ? l10n.lootboxRevealedTitle : l10n.lootboxHeading,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: FoxSpacing.xl),
                if (_revealed)
                  FoxCelebration(
                    child: FoxMascot(
                      mascot: widget.reward,
                      size: 160,
                      semanticLabel: l10n.mascotSemanticLabel(
                        widget.reward.emoji,
                      ),
                    ),
                  )
                else
                  _ClosedLootbox(
                    label: l10n.lootboxTapPrompt,
                    onTap: () => setState(() => _revealed = true),
                  ),
                const SizedBox(height: FoxSpacing.xxl),
                if (_revealed)
                  FoxPrimaryButton(
                    key: const Key('lootboxContinueButton'),
                    label: l10n.lessonContinue,
                    expanded: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Unopened-box tap target: a simple icon affordance (final art out of
/// scope, same as the retired `FoxMascot` painter) with the 48dp a11y floor.
///
/// Design reason for not reusing a kit button here: none of
/// `FoxPrimaryButton`/`FoxSecondaryButton`/`FoxCheckButton` support a large
/// square icon-only tap target shaped like a gift box — this stays a
/// one-off, same precedent as `_EditNameDialog` in `home_screen.dart`.
class _ClosedLootbox extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ClosedLootbox({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: const Key('lootboxOpenButton'),
      borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.lg)),
      onTap: onTap,
      child: Semantics(
        button: true,
        label: label,
        child: Container(
          width: 160,
          height: 160,
          constraints: const BoxConstraints(
            minWidth: FoxButtonMetrics.minSize,
            minHeight: FoxButtonMetrics.minSize,
          ),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.lg)),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.card_giftcard,
            size: 96,
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
