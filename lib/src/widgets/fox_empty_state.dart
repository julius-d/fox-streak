// Empty-state-CTA pattern (issue #015).
//
// Generalizes what #003 built in `LibraryScreen._buildEmpty`: pet +
// title + message + CTA (+ loading / error slots). Feature screens reuse
// this instead of hand-rolling centered columns. All copy flows in via
// params from the existing `lib/l10n` arb pattern (DE + EN) — no hardcoded
// user-visible strings live in the kit.
import 'package:flutter/material.dart';

import '../pet/pet_catalog.dart';
import '../theme/fox_streak_theme.dart';
import 'feedback_banner.dart';
import 'fox_buttons.dart';
import 'fox_pet.dart';

/// Friendly empty state with pet header and CTA.
///
/// [ctaLabel]/[onCta] are optional so pure info states (e.g. "no items
/// yet" with an add FAB nearby) can reuse the same layout. [isLoading]
/// swaps the CTA for [loadingLabel]; [errorMessage] adds an error banner.
class FoxEmptyState extends StatelessWidget {
  final String title;

  /// Optional supporting line. Omit for pure info states (e.g. an empty
  /// detail screen with an add FAB nearby).
  final String? message;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final bool isLoading;
  final String? loadingLabel;
  final String? errorMessage;
  final PetEntry pet;
  final String? petSemanticLabel;
  final Key? titleKey;
  final Key? ctaKey;
  final Key? errorKey;
  final Key? loadingKey;

  const FoxEmptyState({
    super.key,
    required this.title,
    required this.pet,
    this.message,
    this.ctaLabel,
    this.onCta,
    this.isLoading = false,
    this.loadingLabel,
    this.errorMessage,
    this.petSemanticLabel,
    this.titleKey,
    this.ctaKey,
    this.errorKey,
    this.loadingKey,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(FoxSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FoxPet(pet: pet, semanticLabel: petSemanticLabel),
            const SizedBox(height: FoxSpacing.lg),
            Text(
              title,
              key: titleKey,
              style: text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: FoxSpacing.sm),
              Text(message!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: FoxSpacing.xl),
            if (isLoading && loadingLabel != null)
              Text(loadingLabel!, key: loadingKey)
            else if (ctaLabel != null)
              FoxPrimaryButton(
                key: ctaKey,
                label: ctaLabel!,
                expanded: true,
                onPressed: onCta,
              ),
            if (errorMessage != null) ...<Widget>[
              const SizedBox(height: FoxSpacing.md),
              FoxFeedbackBanner.error(key: errorKey, message: errorMessage!),
            ],
          ],
        ),
      ),
    );
  }
}
