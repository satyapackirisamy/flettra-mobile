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
        return errorWidget ??
            Container(
              width: width,
              height: height,
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
      },
    );
  }
}
