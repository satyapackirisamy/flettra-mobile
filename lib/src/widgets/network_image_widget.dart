import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/flettra_colors.dart';

/// Image loading for Flettra.
///
/// Previously these used a bare [NetworkImage], which caches only in memory for
/// the lifetime of the provider — so every rebuild and every scroll back up
/// re-downloaded the same photo. On a list of ride covers that is the scroll
/// stutter testers described.
///
/// [CachedNetworkImage] adds a disk cache, and `memCacheWidth` decodes to the
/// size actually being drawn instead of holding a full-resolution bitmap for a
/// 52 pt thumbnail.
///
/// On web we keep the plain [Image] path: CanvasKit cannot read pixels from a
/// cross-origin image, so the HTML element strategy is still required there.
ImageProvider networkImageProvider(String url) {
  if (kIsWeb) {
    return NetworkImage(url, webHtmlElementStrategy: WebHtmlElementStrategy.prefer);
  }
  return CachedNetworkImageProvider(url);
}

/// Device pixel ratio is applied on top of the logical width so the decoded
/// bitmap is sharp without being wasteful.
int? _memCacheWidth(BuildContext context, double? logicalWidth) {
  if (logicalWidth == null || !logicalWidth.isFinite) return null;
  final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
  return (logicalWidth * dpr).round();
}

/// Drop-in replacement for CircleAvatar with a backgroundImage.
class WebCircleAvatar extends StatelessWidget {
  final String url;
  final double radius;
  final Widget? child;
  final Color? backgroundColor;

  const WebCircleAvatar({
    super.key,
    required this.url,
    this.radius = 20,
    this.child,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ClipOval(
            child: SafeNetworkImage(
              url: url,
              width: size,
              height: size,
              errorWidget: CircleAvatar(
                radius: radius,
                backgroundColor: backgroundColor ?? context.c.brandWash,
                child: Icon(Icons.person_rounded,
                    size: radius, color: context.c.brand),
              ),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class SafeNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorWidget;

  const SafeNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _fallback(context);

    if (kIsWeb) {
      return Image(
        image: networkImageProvider(url),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _fallback(context),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: _memCacheWidth(context, width),
      fadeInDuration: AppDuration.fast,
      // A tinted block in the image's own shape reads as "loading"; a spinner
      // inside a 52 pt thumbnail reads as broken.
      placeholder: (context, _) => Container(color: context.c.surfaceSunken),
      errorWidget: (context, _, __) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    if (errorWidget != null) return errorWidget!;
    return Container(
      width: width,
      height: height,
      color: context.c.surfaceSunken,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: context.c.ink3,
        size: (width != null && width! < 64) ? 18 : 28,
      ),
    );
  }
}
