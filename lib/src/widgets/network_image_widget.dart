import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// On web, uses <img> HTML element strategy to avoid CanvasKit CORS issues
// when loading images from a different origin (e.g. localhost:3000 vs localhost:52345).
ImageProvider networkImageProvider(String url) {
  if (kIsWeb) {
    return NetworkImage(url, webHtmlElementStrategy: WebHtmlElementStrategy.prefer);
  }
  return NetworkImage(url);
}

// Drop-in replacement for CircleAvatar with backgroundImage.
// On web, CircleAvatar tries to read pixel data for circle clipping, triggering
// Same-Origin Policy errors. This widget uses ClipOval + Image instead.
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
            child: Image(
              image: networkImageProvider(url),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => CircleAvatar(
                radius: radius,
                backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Icon(Icons.person_rounded, size: radius, color: Theme.of(context).colorScheme.primary),
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
    return Image(
      image: networkImageProvider(url),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        if (kDebugMode) debugPrint('[SafeNetworkImage] FAILED: $url — $error');
        return errorWidget ??
            Container(
              width: width,
              height: height,
              color: Colors.grey[100],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
                  if (kDebugMode) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(url, style: const TextStyle(fontSize: 9, color: Colors.red), textAlign: TextAlign.center, maxLines: 3),
                    ),
                  ],
                ],
              ),
            );
      },
    );
  }
}
