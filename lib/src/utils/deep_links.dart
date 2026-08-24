/// Deep links into Flettra.
///
/// Two link forms reach the app:
///
///   `https://flettra.com/ride/<token>` — a Universal Link (iOS) / App Link
///   (Android). Verified against `/.well-known/apple-app-site-association` and
///   `/.well-known/assetlinks.json` on flettra.com. With the app installed the
///   OS routes it here without the browser appearing at all; without it, the
///   web landing page offers the store.
///
///   `flettra://ride/<token>` — the custom scheme. Needs no domain setup, so it
///   is the fallback the landing page's "Open in the app" button uses.
///
/// Before this, "Share ride" copied `https://api.flettra.com/rides/share/<token>`
/// — the REST endpoint. Tapping it showed a page of JSON.
library;

/// Custom URL scheme, registered in Info.plist and AndroidManifest.xml.
const String appScheme = 'flettra';

/// The web origin that hosts the association files and the landing page.
const String webOrigin = 'https://flettra.com';

/// The shareable link for a ride's share token.
String rideShareUrl(String token) => '$webOrigin/ride/$token';

/// What an incoming link is asking the app to open.
enum DeepLinkKind { ride }

/// A parsed incoming link.
class DeepLink {
  const DeepLink(this.kind, this.value);

  final DeepLinkKind kind;

  /// The identifier from the path — a ride share token, for [DeepLinkKind.ride].
  final String value;

  @override
  String toString() => 'DeepLink(${kind.name}, $value)';
}

/// Parses an incoming URI, or null when it is not a link the app handles.
///
/// Accepts every path form that has ever been shared, since links live on in
/// chat threads long after the format changes:
///
///   flettra://ride/<token>
///   https://flettra.com/ride/<token>
///   https://flettra.com/ride/share/<token>   (the pre-shortening web route)
///   https://flettra.com/r/<token>            (short form)
DeepLink? parseDeepLink(Uri? uri) {
  if (uri == null) return null;

  final scheme = uri.scheme.toLowerCase();
  final isApp = scheme == appScheme;
  final isWeb = (scheme == 'https' || scheme == 'http') &&
      (uri.host == 'flettra.com' || uri.host == 'www.flettra.com');
  if (!isApp && !isWeb) return null;

  // flettra://ride/<token> puts "ride" in the host, not the path.
  final segments = <String>[
    if (isApp && uri.host.isNotEmpty) uri.host,
    ...uri.pathSegments,
  ].where((s) => s.isNotEmpty).toList();

  if (segments.isEmpty) return null;

  if (segments.first == 'r' && segments.length >= 2) {
    return DeepLink(DeepLinkKind.ride, segments[1]);
  }

  if (segments.first == 'ride') {
    // Skip the optional "share" segment from the older web route.
    final rest = segments.sublist(1).where((s) => s != 'share').toList();
    if (rest.isNotEmpty) return DeepLink(DeepLinkKind.ride, rest.first);
  }

  return null;
}
