// Question-card prompt image: copyright caption + tap-to-expand full-screen
// view (issue #094).
//
// A deliberately separate widget from `FoxItemImage` (#014): that one is a
// small, fixed-square, non-interactive thumbnail for summary contexts
// (set-detail/library rows) where a caption bar and tap target don't fit
// (Material's `ListTile.leading` caps height well under what an image +
// caption needs) and a thumbnail-sized credit line isn't legible anyway.
// This widget is for the *question* context only — the lesson exercise
// card and the full-screen view it opens — where the real image deserves
// more room and should show at its natural aspect ratio, not forced into a
// square crop.
//
// Scope mirrors #094 Decisions: only `base64`/`url` images get a caption
// and are tappable — a system `emoji` glyph has no meaningful copyright and
// isn't worth zooming into. Kit widgets never resolve l10n themselves (see
// `fox_confirm_dialog.dart`), so [expandHint] is a plain string the caller
// resolves from `AppLocalizations` once and passes in.

import 'package:flutter/material.dart';

import 'fox_item_image.dart' show decodeImageBase64;
import '../theme/fox_streak_theme.dart';

/// Renders [item]'s prompt-side image for the lesson/question context,
/// given its validated `imageType`/`imageContent` pair (see
/// `validation.dart`'s `validateImagePair`) and optional [imageCopyright].
class FoxQuestionImage extends StatelessWidget {
  final String imageType;
  final String imageContent;
  final String semanticLabel;
  final String? imageCopyright;
  final String expandHint;

  /// Emoji glyph box height — emoji doesn't need the extra room real
  /// images get below.
  final double emojiSize;

  /// Max height for a `base64`/`url` image — generous, not forced square;
  /// the actual rendered size preserves aspect ratio (`BoxFit.contain`) and
  /// may be smaller.
  final double maxImageHeight;

  const FoxQuestionImage({
    super.key,
    required this.imageType,
    required this.imageContent,
    required this.semanticLabel,
    required this.expandHint,
    this.imageCopyright,
    this.emojiSize = 96,
    this.maxImageHeight = 240,
  });

  /// `base64`/`url` only (#094 Decisions) — `emoji` and malformed types
  /// never expand.
  bool get _isExpandable => imageType == 'base64' || imageType == 'url';

  @override
  Widget build(BuildContext context) {
    final Widget image = switch (imageType) {
      'emoji' => SizedBox(height: emojiSize, child: _buildEmoji()),
      'base64' => _buildBase64(context),
      'url' => _buildUrl(context),
      _ => SizedBox(
        height: emojiSize,
        width: emojiSize,
        child: _buildPlaceholder(context),
      ),
    };
    final expandable = _isExpandable;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        expandable
            ? InkWell(
                key: const Key('foxQuestionImageTapTarget'),
                onTap: () => _openFullScreen(context),
                child: image,
              )
            : image,
        if (imageCopyright != null)
          buildFoxImageCaptionBar(context, imageCopyright!, double.infinity),
      ],
    );
    final label = imageCopyright == null
        ? semanticLabel
        : '$semanticLabel. $imageCopyright';
    return Semantics(
      label: label,
      image: true,
      hint: expandable ? expandHint : null,
      // Without this, the emoji path's `Text` contributes its own
      // semantics, merging into the declared label (mirrors `FoxItemImage`,
      // see #014 Decisions: no separate alt-text field).
      child: ExcludeSemantics(child: body),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FoxFullScreenImageViewer(
          imageType: imageType,
          imageContent: imageContent,
          imageCopyright: imageCopyright,
        ),
      ),
    );
  }

  Widget _buildEmoji() {
    return Center(
      child: Text(
        imageContent,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: TextStyle(fontSize: emojiSize * 0.6),
      ),
    );
  }

  Widget _buildBase64(BuildContext context) {
    final bytes = decodeImageBase64(imageContent);
    if (bytes == null) {
      return SizedBox(
        width: double.infinity,
        height: maxImageHeight,
        child: _buildPlaceholder(context),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(FoxRadius.md),
      // Both `width` and `height` are explicit (not left to the source
      // image's own decoded-frame size): a render box that depends on the
      // real decoded `ui.Image` can stay a zero-size box indefinitely in a
      // headless test environment (the codec Future may never resolve
      // within a pump/pumpAndSettle loop) — fixing both dimensions keeps
      // layout (and hit-testing) deterministic regardless of decode
      // timing. `BoxFit.contain` still letterboxes within this box rather
      // than cropping, so a non-square image's aspect ratio is preserved.
      child: SizedBox(
        width: double.infinity,
        height: maxImageHeight,
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholder(context),
        ),
      ),
    );
  }

  Widget _buildUrl(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(FoxRadius.md),
      child: SizedBox(
        width: double.infinity,
        height: maxImageHeight,
        child: Image.network(
          imageContent,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _buildLoading(context);
          },
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholder(context),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: SizedBox(
        key: const Key('foxQuestionImageLoading'),
        width: emojiSize * 0.4,
        height: emojiSize * 0.4,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('foxQuestionImagePlaceholder'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(FoxRadius.md),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
    );
  }
}

/// The right-aligned caption bar shown below an image when a copyright/
/// credit line is set (#094) — identical styling in [FoxQuestionImage] and
/// [FoxFullScreenImageViewer]. Themed via the Material `ColorScheme` (not a
/// fixed black/white bar), matching the surface colors `FoxItemImage`
/// already uses for its loading/placeholder states.
Widget buildFoxImageCaptionBar(
  BuildContext context,
  String text,
  double width,
) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    key: const Key('foxItemImageCaption'),
    width: width,
    padding: const EdgeInsets.symmetric(
      horizontal: FoxSpacing.sm,
      vertical: FoxSpacing.xs,
    ),
    color: scheme.surfaceContainerHighest,
    child: Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: scheme.onSurfaceVariant),
    ),
  );
}

/// Full-screen, standard-page-push view of a single `base64`/`url` image
/// (#094) — a bigger static image, not an interactive pinch-to-zoom/pan
/// viewer (out of scope). Tapping the image or the platform back
/// button/gesture both pop the route.
class FoxFullScreenImageViewer extends StatelessWidget {
  final String imageType;
  final String imageContent;
  final String? imageCopyright;

  const FoxFullScreenImageViewer({
    super.key,
    required this.imageType,
    required this.imageContent,
    this.imageCopyright,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      key: const Key('fullScreenImageView'),
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: GestureDetector(
                key: const Key('fullScreenImageViewTapTarget'),
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Center(child: _buildImage(context)),
              ),
            ),
            if (imageCopyright != null)
              buildFoxImageCaptionBar(
                context,
                imageCopyright!,
                double.infinity,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    switch (imageType) {
      case 'base64':
        final bytes = decodeImageBase64(imageContent);
        if (bytes == null) return _buildPlaceholder(context);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholder(context),
        );
      case 'url':
        return Image.network(
          imageContent,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _buildLoading(context);
          },
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholder(context),
        );
      default:
        return _buildPlaceholder(context);
    }
  }

  Widget _buildLoading(BuildContext context) {
    return const SizedBox(
      key: Key('fullScreenImageViewLoading'),
      width: 48,
      height: 48,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Icon(
      key: const Key('fullScreenImageViewPlaceholder'),
      Icons.broken_image_outlined,
      size: 96,
      color: scheme.onSurfaceVariant,
    );
  }
}
