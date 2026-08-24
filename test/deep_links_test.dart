import 'package:flutter_test/flutter_test.dart';
import 'package:flettra_mobile/src/utils/deep_links.dart';

/// "Share ride copies the link, and when I open the copied link it shows the
/// page with the ride details instead of opening in the app."
///
/// The old link was `https://api.flettra.com/rides/share/<token>` — the REST
/// endpoint, which renders JSON and can never deep link. These tests pin the
/// new link format and the parser that receives it back.
void main() {
  group('rideShareUrl', () {
    test('points at the web landing page, not the API', () {
      final url = rideShareUrl('0746aaab00bebe3a3bd27cb15a655ba6');
      expect(url, 'https://flettra.com/ride/0746aaab00bebe3a3bd27cb15a655ba6');
      expect(url, isNot(contains('api.')));
      expect(url, isNot(contains('/rides/share/')));
    });

    test('round-trips through the parser', () {
      const token = 'abc123';
      final link = parseDeepLink(Uri.parse(rideShareUrl(token)));
      expect(link?.kind, DeepLinkKind.ride);
      expect(link?.value, token);
    });
  });

  group('parseDeepLink', () {
    void expectsRide(String uri, String token) {
      final link = parseDeepLink(Uri.parse(uri));
      expect(link, isNotNull, reason: '$uri should parse');
      expect(link!.kind, DeepLinkKind.ride);
      expect(link.value, token, reason: uri);
    }

    test('accepts the custom scheme', () {
      expectsRide('flettra://ride/tok1', 'tok1');
    });

    test('accepts the https link on both hosts', () {
      expectsRide('https://flettra.com/ride/tok2', 'tok2');
      expectsRide('https://www.flettra.com/ride/tok3', 'tok3');
    });

    test('accepts the older /ride/share/ web route', () {
      // Links shared before the URL was shortened are still in chat threads.
      expectsRide('https://flettra.com/ride/share/tok4', 'tok4');
    });

    test('accepts the short /r/ form', () {
      expectsRide('https://flettra.com/r/tok5', 'tok5');
      expectsRide('flettra://r/tok6', 'tok6');
    });

    test('ignores a trailing slash and query string', () {
      expectsRide('https://flettra.com/ride/tok7?utm_source=whatsapp', 'tok7');
    });

    test('rejects links for other hosts', () {
      expect(parseDeepLink(Uri.parse('https://evil.example/ride/tok')), isNull);
      // Notably the old API link: it must not be mistaken for a deep link.
      expect(
        parseDeepLink(Uri.parse('https://api.flettra.com/rides/share/tok')),
        isNull,
      );
    });

    test('rejects paths the app does not handle', () {
      expect(parseDeepLink(Uri.parse('https://flettra.com/')), isNull);
      expect(parseDeepLink(Uri.parse('https://flettra.com/privacy')), isNull);
      expect(parseDeepLink(Uri.parse('flettra://ride')), isNull);
      expect(parseDeepLink(Uri.parse('flettra://')), isNull);
    });

    test('rejects null', () {
      expect(parseDeepLink(null), isNull);
    });
  });
}
