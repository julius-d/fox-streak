// Home banner for pack updates (issue #125): "update available" with
// Update/dismiss, progress while updating, a short success confirmation and
// a retry on failure. State lives in `packUpdateControllerProvider`; this
// widget only renders it (and hides itself when there is nothing to show).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'pack_update_controller.dart';

class PackUpdateBanner extends ConsumerStatefulWidget {
  /// How long the success confirmation stays before it disappears.
  final Duration successDuration;

  const PackUpdateBanner({
    super.key,
    this.successDuration = const Duration(seconds: 3),
  });

  @override
  ConsumerState<PackUpdateBanner> createState() => _PackUpdateBannerState();
}

class _PackUpdateBannerState extends ConsumerState<PackUpdateBanner> {
  Timer? _successTimer;

  @override
  void dispose() {
    _successTimer?.cancel();
    super.dispose();
  }

  Future<bool> _confirmOverwrite(List<String> setTitles) async {
    // The learner may have left Home while the update was preparing.
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context)!;
    final overwrite = await FoxConfirmDialog.show(
      context: context,
      title: l10n.marketplacePackOverwriteTitle,
      message: l10n.marketplacePackOverwriteMessage(
        setTitles.map((t) => '• $t').join('\n'),
      ),
      confirmLabel: l10n.marketplacePackOverwriteConfirm,
      cancelLabel: l10n.marketplacePackOverwriteSkip,
      confirmKey: const Key('confirmOverwriteLocalEditsButton'),
      cancelKey: const Key('skipOverwriteLocalEditsButton'),
    );
    return overwrite == true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(packUpdateControllerProvider.notifier);
    final state = ref.watch(packUpdateControllerProvider);

    if (state.phase == PackUpdatePhase.success) {
      _successTimer ??= Timer(
        widget.successDuration,
        controller.acknowledgeSuccess,
      );
    } else {
      _successTimer?.cancel();
      _successTimer = null;
    }
    if (!state.visible) return const SizedBox.shrink();

    switch (state.phase) {
      case PackUpdatePhase.idle:
        return const SizedBox.shrink();
      case PackUpdatePhase.available:
        return FoxFeedbackBanner.info(
          key: const Key('packUpdateBanner'),
          message: state.updates.length == 1
              ? l10n.packUpdateBannerOne(state.updates.single.listing.title)
              : l10n.packUpdateBannerMany(state.updates.length),
          actionLabel: l10n.packUpdateAction,
          onAction: () => controller.update(_confirmOverwrite),
          onClose: controller.dismiss,
          closeLabel: l10n.packUpdateDismiss,
        );
      case PackUpdatePhase.running:
        return Column(
          key: const Key('packUpdateBanner'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FoxFeedbackBanner.info(
              message: l10n.packUpdateProgress(state.done, state.total),
            ),
            const SizedBox(height: FoxSpacing.xs),
            FoxProgressBar(
              key: const Key('packUpdateProgress'),
              value: state.total == 0 ? 0 : state.done / state.total,
              semanticsLabel: l10n.packUpdateProgress(state.done, state.total),
            ),
          ],
        );
      case PackUpdatePhase.success:
        return FoxFeedbackBanner.success(
          key: const Key('packUpdateBanner'),
          message: l10n.packUpdateSuccess,
        );
      case PackUpdatePhase.failed:
        return FoxFeedbackBanner.info(
          key: const Key('packUpdateBanner'),
          message: state.partial
              ? l10n.packUpdateFailedPartial
              : l10n.packUpdateFailed,
          actionLabel: l10n.packUpdateRetry,
          onAction: () => controller.update(_confirmOverwrite),
          onClose: controller.dismiss,
          closeLabel: l10n.packUpdateDismiss,
        );
    }
  }
}
