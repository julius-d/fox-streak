// Shared prompt-side item image renderer (issue #014).
//
// Switches on an item's `imageType` (`emoji|base64|url`): `emoji` renders as
// large inline text, `base64` via `Image.memory`, `url` via `Image.network`
// with a loading spinner + a graceful broken-image placeholder on failure —
// never crashes or hangs the lesson. `url` is only ever produced by
// user-added items (bundled seed content never uses it, see
// `assets/seed/README.md`), so the loading/error paths are exercised by
// real network conditions, not a local-only guarantee.
//
// No separate alt-text field in v1 (#014 Decisions): callers must pass the
// item's `prompt` text as [semanticLabel].

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/validation.dart' show normalizeImageContent;
import '../theme/fox_streak_theme.dart';

/// Renders one item's prompt-side image, given its validated
/// `imageType`/`imageContent` pair (see `validation.dart`'s
/// `validateImagePair`).
class FoxItemImage extends StatelessWidget {
  final String imageType;
  final String imageContent;
  final String semanticLabel;
  final double size;

  const FoxItemImage({
    super.key,
    required this.imageType,
    required this.imageContent,
    required this.semanticLabel,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content = switch (imageType) {
      'emoji' => _buildEmoji(),
      'base64' => _buildBase64(context),
      'url' => _buildUrl(context),
      _ => _buildPlaceholder(context),
    };
    return Semantics(
      label: semanticLabel,
      image: true,
      // Without this, the emoji path's `Text` contributes its own
      // semantics, merging into e.g. "Hund\n🐶" instead of the single
      // declared label — the prompt text is already the authoritative a11y
      // label (#014 Decisions: no separate alt-text field), so the
      // rendering below is presentation-only.
      child: ExcludeSemantics(
        child: SizedBox(width: size, height: size, child: content),
      ),
    );
  }

  Widget _buildEmoji() {
    // `isValidImageContent('emoji', ...)` only requires non-empty content
    // (short symbol combos are intentionally allowed, #014 Decisions), so
    // nothing stops a much longer pasted string — clip it to one line
    // instead of overflowing the fixed-size box.
    return Center(
      child: Text(
        imageContent,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: TextStyle(fontSize: size * 0.6),
      ),
    );
  }

  Widget _buildBase64(BuildContext context) {
    final bytes = _decodeBase64(imageContent);
    if (bytes == null) return _buildPlaceholder(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(FoxRadius.md),
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildPlaceholder(context),
      ),
    );
  }

  Widget _buildUrl(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(FoxRadius.md),
      child: Image.network(
        imageContent,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildLoading(context);
        },
        errorBuilder: (context, error, stackTrace) =>
            _buildPlaceholder(context),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: SizedBox(
        key: const Key('foxItemImageLoading'),
        width: size * 0.4,
        height: size * 0.4,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('foxItemImagePlaceholder'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(FoxRadius.md),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
    );
  }
}

/// `null` on malformed base64 — corrupt data (e.g. from a hand-edited share
/// file) falls back to the placeholder instead of throwing. Stored content
/// is already whitespace-stripped (see `normalizeImageContent`), but
/// stripping again here is cheap and defends against any pre-existing row
/// that predates that normalization.
Uint8List? _decodeBase64(String content) {
  try {
    return base64Decode(normalizeImageContent('base64', content));
  } on FormatException {
    return null;
  }
}
