// Confirm-dialog pattern (issue #015).
//
// Generalizes what #003 built in `LibraryScreen._confirmDeleteSet`: every
// destructive confirm in the app goes through [FoxConfirmDialog.show] with
// the kit buttons — no hand-rolled `AlertDialog` + `TextButton`/`FilledButton`
// pairs in feature screens. Keys stay caller-controlled so the #016 e2e
// hooks and existing tests keep working.
import 'package:flutter/material.dart';

import '../theme/fox_streak_theme.dart';
import 'fox_buttons.dart';

/// Destructive confirm dialog built from the kit button pair.
///
/// [danger] renders the confirm action in error red (default true for
/// deletes); set false for neutral confirms.
class FoxConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool danger;
  final Key? confirmKey;
  final Key? cancelKey;

  const FoxConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.danger = true,
    this.confirmKey,
    this.cancelKey,
  });

  /// Shows the dialog and resolves to true (confirmed), false (cancelled),
  /// or null (dismissed).
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    bool danger = true,
    Key? confirmKey,
    Key? cancelKey,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => FoxConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        danger: danger,
        confirmKey: confirmKey,
        cancelKey: cancelKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FoxSemanticColors tokens = foxSemantics(context);
    final TextTheme text = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(title),
      content: Text(message, style: text.bodyMedium),
      actions: <Widget>[
        FoxSecondaryButton(
          key: cancelKey,
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: FoxSpacing.sm),
        FoxPrimaryButton(
          key: confirmKey,
          label: confirmLabel,
          backgroundColor: danger ? tokens.error : null,
          foregroundColor: danger ? tokens.onError : null,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
