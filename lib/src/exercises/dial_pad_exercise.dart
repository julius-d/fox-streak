// Phone dial pad exercise (issue #008).
//
// Implements the ExerciseCardBuilder contract for 'phone' type items.
// Uses a custom circular keypad with masked display and reveal-hint.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/validation.dart';
import '../lesson/exercise_card.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import '../../l10n/app_localizations.dart';

/// Builds the dial pad exercise card for phone-type items.
///
/// This implements the [ExerciseCardBuilder] signature from the lesson shell.
/// The shell passes the [item] and [onStateChanged] callback.
Widget buildDialPadExercise({
  required Item item,
  required void Function(ExerciseDraft draft) onStateChanged,
  required AppLocalizations l10n,
  bool autoAnswer = false,
}) {
  return DialPadExercise(
    item: item,
    onStateChanged: onStateChanged,
    l10n: l10n,
    autoAnswer: autoAnswer,
  );
}

/// Internal stateful widget for the dial pad exercise.
class DialPadExercise extends ConsumerStatefulWidget {
  final Item item;
  final void Function(ExerciseDraft draft) onStateChanged;
  final AppLocalizations l10n;
  final bool autoAnswer;

  const DialPadExercise({
    super.key,
    required this.item,
    required this.onStateChanged,
    required this.l10n,
    this.autoAnswer = false,
  });

  @override
  ConsumerState<DialPadExercise> createState() => _DialPadExerciseState();
}

class _DialPadExerciseState extends ConsumerState<DialPadExercise> {
  String _typedDigits = '';
  bool _revealingHint = false;
  Timer? _hintRevealTimer;

  // Keypad layout: 1-9, then 0 with backspace
  static const List<List<String>> _keypadLayout = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', 'backspace'],
  ];

  @override
  void initState() {
    super.initState();
    if (widget.autoAnswer) {
      // For tests: immediately report correct answer
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _typedDigits = widget.item.answer;
          _reportDraft();
        }
      });
    }
  }

  @override
  void dispose() {
    _hintRevealTimer?.cancel();
    super.dispose();
  }

  void _onKeyTap(String key) {
    // Haptic feedback for each keypress
    FoxFeedback.success(context, ref);

    if (key == 'backspace') {
      if (_typedDigits.isNotEmpty) {
        setState(() {
          _typedDigits = _typedDigits.substring(0, _typedDigits.length - 1);
        });
        _reportDraft();
      }
    } else if (_typedDigits.length < 15) {
      // Max 15 digits per validation
      setState(() {
        _typedDigits += key;
      });
      _reportDraft();
    }
  }

  void _onRevealHint() {
    if (_revealingHint) return;

    setState(() {
      _revealingHint = true;
    });
    _reportDraft();

    // Auto-hide after 2 seconds
    _hintRevealTimer?.cancel();
    _hintRevealTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _revealingHint = false;
        });
      }
    });

    // Haptic for reveal
    FoxFeedback.success(context, ref);
  }

  void _reportDraft() {
    final normalizedTyped = normalizePhone(_typedDigits);
    final normalizedAnswer = normalizePhone(widget.item.answer);

    widget.onStateChanged(
      ExerciseDraft(
        hasAnswer: _typedDigits.isNotEmpty,
        grade: () => normalizedTyped == normalizedAnswer,
        correctAnswerLabel: widget.item.answer,
        hintLabel: null,
      ),
    );
  }

  String _getDisplayText() {
    if (_revealingHint) {
      return widget.item.answer;
    }
    final normalizedAnswer = normalizePhone(widget.item.answer);
    final answerLength = normalizedAnswer.length;
    final maskedChar = widget.l10n.exercisePhoneMaskedDigit;

    if (_typedDigits.isEmpty) {
      // Show all masked from the beginning based on answer length
      return maskedChar * answerLength;
    }

    // Build display: typed digits replace masked ones position by position
    final buffer = StringBuffer();
    for (int i = 0; i < answerLength; i++) {
      if (i < _typedDigits.length) {
        buffer.write(_typedDigits[i]);
      } else {
        buffer.write(maskedChar);
      }
    }
    // If user typed more than answer length, append extra digits
    if (_typedDigits.length > answerLength) {
      buffer.write(_typedDigits.substring(answerLength));
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final FoxSemanticColors tokens = foxSemantics(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: FoxSpacing.md),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.top -
              MediaQuery.of(context).padding.bottom -
              kToolbarHeight -
              FoxButtonMetrics.minSize -
              FoxSpacing.xxl * 2,
        ),
        child: IntrinsicHeight(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Contact label (prompt)
              Text(
                widget.item.prompt,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: FoxSpacing.xl),

              // Display area with masked digits or revealed hint
              Container(
                key: const Key('dialPadDisplay'),
                padding: const EdgeInsets.symmetric(
                  horizontal: FoxSpacing.lg,
                  vertical: FoxSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(FoxRadius.lg),
                  border: Border.all(color: scheme.outline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _getDisplayText(),
                        style: text.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: _revealingHint ? tokens.success : scheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (!_revealingHint)
                      IconButton(
                        key: const Key('dialPadRevealHint'),
                        icon: const Icon(Icons.visibility_outlined),
                        tooltip: widget.l10n.exercisePhoneRevealHintAria,
                        onPressed: _onRevealHint,
                        color: scheme.primary,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: FoxSpacing.xl),

              // Keypad grid
              Column(
                children: _keypadLayout.map((row) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: FoxSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: row.map((key) {
                        if (key.isEmpty) {
                          // Empty spacer for bottom-left
                          return const SizedBox(width: 72, height: 72);
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: FoxSpacing.xs),
                          child: _DialPadKey(
                            key: Key('dialPadKey$key'),
                            label: key,
                            onTap: () => _onKeyTap(key),
                            isBackspace: key == 'backspace',
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual circular keypad button with hard-shadow press feel.
class _DialPadKey extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isBackspace;

  const _DialPadKey({
    super.key,
    required this.label,
    required this.onTap,
    this.isBackspace = false,
  });

  @override
  State<_DialPadKey> createState() => _DialPadKeyState();
}

class _DialPadKeyState extends State<_DialPadKey> with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _pressController.reverse();
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _handleTapCancel() {
    _pressController.reverse();
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Color bgColor = widget.isBackspace
        ? scheme.surfaceContainerHighest
        : scheme.surface;
    final Color fgColor = widget.isBackspace
        ? scheme.onSurfaceVariant
        : scheme.onSurface;
    final Color shadowColor = (widget.isBackspace
            ? scheme.surfaceContainerHighest
            : scheme.surface)
        .withValues(alpha: 0.4);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: Semantics(
          button: true,
          label: widget.isBackspace ? 'Backspace' : widget.label,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
              boxShadow: _isPressed
                  ? null
                  : [
                      BoxShadow(
                        color: shadowColor,
                        offset: const Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ],
            ),
            child: Center(
              child: widget.isBackspace
                  ? Icon(
                      Icons.backspace_outlined,
                      size: 28,
                      color: fgColor,
                    )
                  : Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: fgColor,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}