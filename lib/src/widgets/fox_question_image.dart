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
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

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

  /// Full-screen view's close-button label (#113), resolved by the caller.
  final String closeLabel;

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
    required this.closeLabel,
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

  bool get _fills => expandToFill && _isExpandable;

  @override
  Widget build(BuildContext context) {
    final label = imageCopyright == null
        ? semanticLabel
        : '$semanticLabel. $imageCopyright';
    return Semantics(
      label: label,
      image: true,
      hint: _isExpandable ? expandHint : null,
      // Without this, the emoji path's `Text` contributes its own
      // semantics, merging into the declared label (mirrors `FoxItemImage`,
      // see #014 Decisions: no separate alt-text field).
      child: ExcludeSemantics(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (imageType) {
      case 'emoji':
        return SizedBox(height: emojiSize, child: _buildEmoji());
      case 'base64':
      case 'url':
        return _buildPhotoBlock(context);
      default:
        return SizedBox(
          height: emojiSize,
          width: emojiSize,
          child: _buildPlaceholder(context),
        );
    }
  }

  /// The `base64`/`url` image plus its copyright note as one block (#113):
  /// [maxImageHeight] for the image and room for the note below it. In
  /// [expandToFill] mode that total is the floor and the block grows into
  /// the parent's height.
  Widget _buildPhotoBlock(BuildContext context) {
    final reserve = imageCopyright == null
        ? 0.0
        : foxImageCaptionReserve(context);
    final block = _buildImageAndCaption(context);
    if (!_fills) {
      return SizedBox(
        width: double.infinity,
        height: maxImageHeight + reserve,
        child: block,
      );
    }
    // `IntrinsicHeight` ancestors ignore positioned Stack children, so the
    // fixed-height sizer is what they measure (the floor) while the block
    // itself fills whatever the Expanded actually gets.
    return Stack(
      children: [
        SizedBox(height: maxImageHeight + reserve, width: double.infinity),
        Positioned.fill(child: block),
      ],
    );
  }

  Widget _buildImageAndCaption(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget layout(BuildContext context, Widget raw, Size? size) =>
        _CaptionedImage(
          imageSize: size,
          image: InkWell(
            key: const Key('foxQuestionImageTapTarget'),
            onTap: () => _openFullScreen(context),
            child: _wrapQuestionImageHero(
              context,
              ClipRRect(
                borderRadius: BorderRadius.circular(FoxRadius.md),
                child: raw,
              ),
            ),
          ),
          caption: imageCopyright,
          captionColor: color,
          captionWithoutSize: true,
        );
    if (imageType == 'url') return _buildUrl(layout);
    final provider = _memoryImageFor(imageContent);
    if (provider == null) {
      return layout(context, _buildPlaceholder(context), null);
    }
    return _ImageSizeBuilder(
      provider: provider,
      builder: (context, size) => layout(
        context,
        Image(
          image: provider,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholder(context),
        ),
        size,
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FoxFullScreenImageViewer(
          imageType: imageType,
          imageContent: imageContent,
          imageCopyright: imageCopyright,
          question: semanticLabel,
          closeLabel: closeLabel,
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

  Widget _buildUrl(
    Widget Function(BuildContext context, Widget child, Size? size) layout,
  ) {
    return _RetryingNetworkImage(
      url: imageContent,
      fit: BoxFit.contain,
      loadingBuilder: _buildLoading,
      layoutBuilder: layout,
      failedBuilder: (context, onRetry) => buildFoxImageLoadFailedPlaceholder(
        context,
        key: const Key('foxQuestionImageLoadFailed'),
        message: imageLoadFailedMessage,
        retryLabel: retryButtonLabel,
        onRetry: onRetry,
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

String? _lastBase64;
MemoryImage? _lastMemoryImage;

/// Decodes [base64] into a [MemoryImage], or `null` if invalid. A fresh
/// `MemoryImage` never equals an earlier one (identity of the byte list),
/// so rebuilds would re-resolve the image and reset its measured size;
/// remembering the last decode keeps the provider stable across rebuilds.
MemoryImage? _memoryImageFor(String base64) {
  if (base64 != _lastBase64) {
    final bytes = decodeImageBase64(base64);
    _lastBase64 = base64;
    _lastMemoryImage = bytes == null ? null : MemoryImage(bytes);
  }
  return _lastMemoryImage;
}

/// Font size / line height of the copyright note (#113) — fixed so
/// [foxImageCaptionReserve] is exact for the 2-line maximum.
const double _kCaptionFontSize = 11;
const double _kCaptionLineHeight = 1.3;
const int _kCaptionMaxLines = 2;

/// Vertical space (gap + 2 text lines at the current text scale) that an
/// image block reserves below the image for the copyright note (#113), so
/// the block's height does not depend on the note's actual length.
double foxImageCaptionReserve(BuildContext context) {
  final lineHeight = MediaQuery.textScalerOf(context)
      .scale(_kCaptionFontSize * _kCaptionLineHeight);
  // +1: font-metric rounding of the wrapped lines must never overflow.
  return FoxSpacing.xs + lineHeight * _kCaptionMaxLines + 1;
}

/// The plain, tiny, right-aligned copyright note below an image (#113) —
/// no background, max 2 lines. Identical in [FoxQuestionImage] (muted
/// theme colour) and [FoxFullScreenImageViewer] (dimmed white); only
/// [color] differs. Callers constrain its width to the rendered image.
Widget buildFoxImageCaption(
  BuildContext context,
  String text, {
  required Color color,
}) {
  return Padding(
    key: const Key('foxItemImageCaption'),
    padding: const EdgeInsets.only(top: FoxSpacing.xs),
    child: Text(
      text,
      textAlign: TextAlign.end,
      maxLines: _kCaptionMaxLines,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: color,
        fontSize: _kCaptionFontSize,
        height: _kCaptionLineHeight,
      ),
    ),
  );
}

/// Resolves [provider]'s intrinsic pixel size and hands it to [builder]
/// (`null` until known, or if the image fails to load).
class _ImageSizeBuilder extends StatefulWidget {
  final ImageProvider provider;
  final Widget Function(BuildContext context, Size? size) builder;

  const _ImageSizeBuilder({
    super.key,
    required this.provider,
    required this.builder,
  });

  @override
  State<_ImageSizeBuilder> createState() => _ImageSizeBuilderState();
}

class _ImageSizeBuilderState extends State<_ImageSizeBuilder> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _size;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_ImageSizeBuilder old) {
    super.didUpdateWidget(old);
    if (old.provider != widget.provider) {
      _size = null;
      _resolve();
    }
  }

  void _resolve() {
    final stream = widget.provider.resolve(
      createLocalImageConfiguration(context),
    );
    if (stream.key == _stream?.key) return;
    _detach();
    _stream = stream;
    _listener = ImageStreamListener((info, _) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      if (mounted && size != _size) setState(() => _size = size);
    }, onError: (_, _) {});
    stream.addListener(_listener!);
  }

  void _detach() {
    if (_listener != null) _stream?.removeListener(_listener!);
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _size);
}

/// Lays out an [image] and its optional copyright [caption] as one block
/// inside the bounded space it is given (#113).
///
/// With a known [imageSize] the image is sized to its exact `contain`
/// rectangle and the caption sits directly below it, right-aligned to the
/// image's real right edge and no wider than the image. Without a size
/// (loading, failed, placeholder) the [image] fills the space above the
/// reserved caption row; the caption is then only drawn if
/// [captionWithoutSize] (full width) — keeping the block's height stable.
class _CaptionedImage extends StatelessWidget {
  final Size? imageSize;
  final Widget image;
  final String? caption;
  final Color captionColor;
  final bool captionWithoutSize;

  const _CaptionedImage({
    required this.imageSize,
    required this.image,
    required this.caption,
    required this.captionColor,
    this.captionWithoutSize = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = caption;
    final reserve = text == null ? 0.0 : foxImageCaptionReserve(context);
    final size = imageSize;
    if (size == null || size.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: image),
          if (text != null)
            SizedBox(
              height: reserve,
              child: captionWithoutSize
                  ? Align(
                      alignment: AlignmentDirectional.topEnd,
                      child: buildFoxImageCaption(
                        context,
                        text,
                        color: captionColor,
                      ),
                    )
                  : null,
            ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = [
          constraints.maxWidth / size.width,
          (constraints.maxHeight - reserve) / size.height,
        ].reduce((a, b) => a < b ? a : b).clamp(0.0, double.infinity);
        final width = size.width * scale;
        final height = size.height * scale;
        return Center(
          child: SizedBox(
            width: width,
            height: height + reserve,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: height, child: image),
                if (text != null)
                  buildFoxImageCaption(context, text, color: captionColor),
              ],
            ),
          ),
        );
      },
    );
  }
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

  /// Places the current [child] (image, loading or failed state) in its
  /// surroundings, given the image's intrinsic size once known (#113).
  final Widget Function(BuildContext context, Widget child, Size? size)
  layoutBuilder;

  const _RetryingNetworkImage({
    required this.url,
    required this.fit,
    required this.loadingBuilder,
    required this.failedBuilder,
    required this.layoutBuilder,
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
      return widget.layoutBuilder(
        context,
        widget.failedBuilder(context, _retry),
        null,
      );
    }
    return _ImageSizeBuilder(
      key: ValueKey(_generation),
      provider: NetworkImage(widget.url),
      builder: (context, size) => widget.layoutBuilder(
        context,
        Image.network(
          widget.url,
          fit: widget.fit,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return widget.loadingBuilder(context);
          },
          errorBuilder: (context, error, stackTrace) {
            _handleError();
            return widget.loadingBuilder(context);
          },
        ),
        size,
      ),
    );
  }
}

/// Full-screen, standard-page-push view of a single `base64`/`url` image
/// (#094) — a bigger static image, not an interactive pinch-to-zoom/pan
/// viewer (out of scope). Gallery-style (#113): always black, a white close
/// button top-left, the [question] in white above the image and the
/// copyright note directly under the image. Tapping the image, the close
/// button or the platform back button/gesture all pop the route.
class FoxFullScreenImageViewer extends StatelessWidget {
  final String imageType;
  final String imageContent;
  final String? imageCopyright;

  /// Question text shown above the image (max 3 lines).
  final String question;

  /// Close button's tooltip / screen-reader label, resolved by the caller.
  final String closeLabel;

  /// "Couldn't load this image" / retry-button copy for a `url` image
  /// (#102) — see `FoxQuestionImage.imageLoadFailedMessage`. This viewer
  /// fetches independently of the inline image, so it retries on its own.
  final String imageLoadFailedMessage;
  final String retryButtonLabel;

  const FoxFullScreenImageViewer({
    super.key,
    required this.imageType,
    required this.imageContent,
    required this.question,
    required this.closeLabel,
    required this.imageLoadFailedMessage,
    required this.retryButtonLabel,
    this.imageCopyright,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        key: const Key('fullScreenImageView'),
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  key: const Key('fullScreenImageViewClose'),
                  tooltip: closeLabel,
                  color: Colors.white,
                  constraints: const BoxConstraints(
                    minWidth: FoxButtonMetrics.minSize,
                    minHeight: FoxButtonMetrics.minSize,
                  ),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FoxSpacing.md,
                  vertical: FoxSpacing.xs,
                ),
                child: Text(
                  question,
                  key: const Key('fullScreenImageViewQuestion'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: Colors.white),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  key: const Key('fullScreenImageViewTapTarget'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.all(FoxSpacing.md),
                    child: _buildImageAndCaption(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageAndCaption(BuildContext context) {
    Widget layout(BuildContext context, Widget raw, Size? size) =>
        _CaptionedImage(
          imageSize: size,
          // Flutter's default Hero flight shuttle shows this (the "to"
          // Hero's) child for the whole flight, in both directions —
          // without matching the card's own `ClipRRect`, the corners would
          // visibly snap from rounded to square (or back) at flight start.
          image: _wrapQuestionImageHero(
            context,
            ClipRRect(
              borderRadius: BorderRadius.circular(FoxRadius.md),
              child: raw,
            ),
          ),
          caption: imageCopyright,
          captionColor: Colors.white.withValues(alpha: 0.7),
        );
    switch (imageType) {
      case 'base64':
        final provider = _memoryImageFor(imageContent);
        if (provider == null) return layout(context, _buildPlaceholder(), null);
        return _ImageSizeBuilder(
          provider: provider,
          builder: (context, size) => layout(
            context,
            Image(
              image: provider,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
            ),
            size,
          ),
        );
      case 'url':
        return _RetryingNetworkImage(
          url: imageContent,
          fit: BoxFit.contain,
          loadingBuilder: _buildLoading,
          layoutBuilder: layout,
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
        return layout(context, _buildPlaceholder(), null);
    }
  }

  Widget _buildLoading(BuildContext context) {
    return const Center(
      child: SizedBox(
        key: Key('fullScreenImageViewLoading'),
        width: 48,
        height: 48,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Icon(
        key: Key('fullScreenImageViewPlaceholder'),
        Icons.broken_image_outlined,
        size: 96,
        color: Colors.white70,
      ),
    );
  }
}
