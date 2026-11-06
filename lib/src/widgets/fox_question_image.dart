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
//
// `url` images auto-retry on load failure, then fall back to a manual-retry
// placeholder (issue #102) — see `_RetryingNetworkImage` below. `base64`
// never needs this: it has no network round-trip to retry.
//
// The tap-to-expand flies the image into its full-screen position/size via
// a `Hero` (issue #103), mirroring `pet_hero.dart`'s convention (#100): a
// constant tag, bypassed when OS reduce-motion is on (both delegate to the
// shared helper in `fox_hero.dart`, see #105). A constant tag is safe here
// for the same reason it is there — only one `FoxQuestionImage` is ever
// mounted at a time (the lesson screen swaps a single exercise card in
// place, not a kept-alive `PageView`), so there's exactly one match on each
// side of the push/pop. Only the image box itself is wrapped, not the
// caption bar below it — that appears on the full-screen view as a normal
// fading-in element, not part of the flight.

import 'package:flutter/material.dart';

import 'fox_buttons.dart';
import 'fox_hero.dart';
import 'fox_item_image.dart' show decodeImageBase64;
import '../theme/fox_streak_theme.dart';

/// Hero tag shared by [FoxQuestionImage]'s tappable image box and
/// [FoxFullScreenImageViewer]'s image — see the file-level comment above.
const Object _questionImageHeroTag = 'questionImageHero';

/// Wraps [child] in a `Hero` sharing [_questionImageHeroTag], unless OS
/// reduce-motion is on — then [child] is returned bare, so the full-screen
/// view opens/closes instantly with no flight, matching `pet_hero.dart`'s
/// convention (#100).
Widget _wrapQuestionImageHero(BuildContext context, Widget child) {
  return wrapInReducedMotionHero(context, _questionImageHeroTag, child);
}

/// Renders [item]'s prompt-side image for the lesson/question context,
/// given its validated `imageType`/`imageContent` pair (see
/// `validation.dart`'s `validateImagePair`) and optional [imageCopyright].
class FoxQuestionImage extends StatelessWidget {
  final String imageType;
  final String imageContent;
  final String semanticLabel;
  final String? imageCopyright;
  final String expandHint;

  /// "Couldn't load this image" / retry-button copy shown once automatic
  /// retries on a `url` image are exhausted (#102) — resolved by the caller
  /// from `AppLocalizations`, same convention as [expandHint].
  final String imageLoadFailedMessage;
  final String retryButtonLabel;

  /// Emoji glyph box height — emoji doesn't need the extra room real
  /// images get below.
  final double emojiSize;

  /// Max height for a `base64`/`url` image — generous, not forced square;
  /// the actual rendered size preserves aspect ratio (`BoxFit.contain`) and
  /// may be smaller.
  final double maxImageHeight;

  /// Grow the `base64`/`url` image box into whatever height the parent
  /// gives it (#112), with [maxImageHeight] as the floor instead of the
  /// fixed height. Requires a bounded-height parent (e.g. an `Expanded`) and, to keep the
  /// floor, an enclosing `IntrinsicHeight` (an `Expanded` squeezed below
  /// [maxImageHeight] would otherwise shrink the image under it).
  /// The floor is also what an enclosing `IntrinsicHeight` sees, so the
  /// image is never smaller than the non-growing variant. No effect on
  /// `emoji`/unknown types, which keep their fixed [emojiSize] box.
  final bool expandToFill;

  const FoxQuestionImage({
    super.key,
    required this.imageType,
    required this.imageContent,
    required this.semanticLabel,
    required this.expandHint,
    required this.imageLoadFailedMessage,
    required this.retryButtonLabel,
    this.imageCopyright,
    this.emojiSize = 96,
    this.maxImageHeight = 240,
    this.expandToFill = false,
  });

  /// `base64`/`url` only (#094 Decisions) — `emoji` and malformed types
  /// never expand.
  bool get _isExpandable => imageType == 'base64' || imageType == 'url';

  /// Height of the `base64`/`url` image box: fixed, or `null` (take the
  /// parent's tight height) in [expandToFill] mode.
  double? get _boxHeight => _fills ? null : maxImageHeight;

  bool get _fills => expandToFill && _isExpandable;

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
    final Widget tappable = expandable
        ? InkWell(
            key: const Key('foxQuestionImageTapTarget'),
            onTap: () => _openFullScreen(context),
            child: _wrapQuestionImageHero(context, image),
          )
        : image;
    final body = Column(
      mainAxisSize: _fills ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // `IntrinsicHeight` ancestors ignore positioned Stack children, so
        // the fixed-height sizer is what they measure (the floor) while
        // the image itself fills whatever the Expanded actually gets.
        if (_fills)
          Expanded(
            child: Stack(
              children: [
                SizedBox(height: maxImageHeight, width: double.infinity),
                Positioned.fill(child: tappable),
              ],
            ),
          )
        else
          tappable,
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
          imageLoadFailedMessage: imageLoadFailedMessage,
          retryButtonLabel: retryButtonLabel,
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
        height: _boxHeight,
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
        height: _boxHeight,
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
        height: _boxHeight,
        child: _RetryingNetworkImage(
          url: imageContent,
          fit: BoxFit.contain,
          loadingBuilder: _buildLoading,
          failedBuilder: (context, onRetry) =>
              buildFoxImageLoadFailedPlaceholder(
                context,
                key: const Key('foxQuestionImageLoadFailed'),
                message: imageLoadFailedMessage,
                retryLabel: retryButtonLabel,
                onRetry: onRetry,
              ),
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

/// The manual-retry failure placeholder shown in place of a `url` image's
/// normal space once automatic retries are exhausted (#102) — scoped to
/// just the image area, not the full-screen `FoxEmptyState` kit widget, so
/// the rest of the question (or the full-screen viewer's caption) renders
/// normally around it. Shared by [FoxQuestionImage] and
/// [FoxFullScreenImageViewer].
Widget buildFoxImageLoadFailedPlaceholder(
  BuildContext context, {
  required Key key,
  required String message,
  required String retryLabel,
  required VoidCallback onRetry,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    key: key,
    decoration: BoxDecoration(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(FoxRadius.md),
    ),
    alignment: Alignment.center,
    padding: const EdgeInsets.all(FoxSpacing.md),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off_outlined, color: scheme.onSurfaceVariant),
        const SizedBox(height: FoxSpacing.xs),
        Text(
          message,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: FoxSpacing.sm),
        FoxSecondaryButton(label: retryLabel, onPressed: onRetry),
      ],
    ),
  );
}

/// Automatic-retry delays for a failed `url` image load (#102 Decisions:
/// "e.g. 3 attempts total" — the initial attempt plus one delay per entry
/// here — "short, increasing delays ... under a few seconds"). Once these
/// are exhausted, [_RetryingNetworkImage] hands off to its manual-retry
/// placeholder.
const List<Duration> _kAutoRetryDelays = [
  Duration(milliseconds: 300),
  Duration(milliseconds: 700),
];

/// Resolves a `url` image via [Image.network], automatically retrying a
/// few times on failure before falling back to a manual-retry placeholder
/// (#102). Automatic retries look identical to a first-time load — the
/// same [loadingBuilder] throughout, no "retrying…" indicator (#102
/// Decisions) — only [failedBuilder] differs, and only once automatic
/// retries are exhausted. The manual retry it hands to [failedBuilder] can
/// be tapped indefinitely, re-running the same cycle.
///
/// A failed [Image.network] load leaves its [ImageCache] entry in place
/// (Flutter never auto-evicts a failed load), so simply rebuilding with
/// the same URL would keep replaying the same failure — each retry here
/// explicitly evicts the image's cache entry first, then forces a fresh
/// [Image] element (via a new `key`) so it resolves from scratch rather
/// than treating an unchanged `NetworkImage(url)` as already resolved.
class _RetryingNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget Function(BuildContext context) loadingBuilder;
  final Widget Function(BuildContext context, VoidCallback onRetry)
  failedBuilder;

  const _RetryingNetworkImage({
    required this.url,
    required this.fit,
    required this.loadingBuilder,
    required this.failedBuilder,
  });

  @override
  State<_RetryingNetworkImage> createState() => _RetryingNetworkImageState();
}

class _RetryingNetworkImageState extends State<_RetryingNetworkImage> {
  /// Forces a fresh [Image] element (new resolve) on every attempt, auto or
  /// manual — never reused, so there's no risk of colliding with a
  /// still-live earlier attempt's element.
  int _generation = 0;

  /// How many automatic attempts have failed in the current cycle; reset
  /// to 0 whenever the user taps manual retry.
  int _autoAttempt = 0;
  bool _failed = false;

  /// Guards against scheduling a retry more than once per attempt —
  /// `errorBuilder` re-runs on every rebuild while an `Image` is still in
  /// its error state, not just the first time.
  int? _scheduledForGeneration;

  void _handleError() {
    if (_scheduledForGeneration == _generation) return;
    _scheduledForGeneration = _generation;
    if (_autoAttempt < _kAutoRetryDelays.length) {
      final delay = _kAutoRetryDelays[_autoAttempt];
      Future<void>.delayed(delay, () async {
        await NetworkImage(widget.url).evict();
        if (!mounted) return;
        setState(() {
          _autoAttempt++;
          _generation++;
        });
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _failed = true);
      });
    }
  }

  void _retry() {
    NetworkImage(widget.url).evict().then((_) {
      if (!mounted) return;
      setState(() {
        _autoAttempt = 0;
        _generation++;
        _scheduledForGeneration = null;
        _failed = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return widget.failedBuilder(context, _retry);
    }
    return Image.network(
      widget.url,
      key: ValueKey(_generation),
      fit: widget.fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return widget.loadingBuilder(context);
      },
      errorBuilder: (context, error, stackTrace) {
        _handleError();
        return widget.loadingBuilder(context);
      },
    );
  }
}

/// Full-screen, standard-page-push view of a single `base64`/`url` image
/// (#094) — a bigger static image, not an interactive pinch-to-zoom/pan
/// viewer (out of scope). Tapping the image or the platform back
/// button/gesture both pop the route.
class FoxFullScreenImageViewer extends StatelessWidget {
  final String imageType;
  final String imageContent;
  final String? imageCopyright;

  /// "Couldn't load this image" / retry-button copy for a `url` image
  /// (#102) — see `FoxQuestionImage.imageLoadFailedMessage`. This viewer
  /// fetches independently of the inline image, so it retries on its own.
  final String imageLoadFailedMessage;
  final String retryButtonLabel;

  const FoxFullScreenImageViewer({
    super.key,
    required this.imageType,
    required this.imageContent,
    required this.imageLoadFailedMessage,
    required this.retryButtonLabel,
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
                child: Center(
                  child: _wrapQuestionImageHero(
                    context,
                    // Flutter's default Hero flight shuttle shows this
                    // (the "to" Hero's) child for the whole flight, in
                    // both directions — without matching the card's own
                    // `ClipRRect` (see `_buildBase64`/`_buildUrl` above),
                    // the corners would visibly snap from rounded to
                    // square (or back) right as the flight starts.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(FoxRadius.md),
                      child: _buildImage(context),
                    ),
                  ),
                ),
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
        return _RetryingNetworkImage(
          url: imageContent,
          fit: BoxFit.contain,
          loadingBuilder: _buildLoading,
          failedBuilder: (context, onRetry) =>
              buildFoxImageLoadFailedPlaceholder(
                context,
                key: const Key('fullScreenImageViewLoadFailed'),
                message: imageLoadFailedMessage,
                retryLabel: retryButtonLabel,
                onRetry: onRetry,
              ),
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
