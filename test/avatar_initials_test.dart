import 'package:flutter_test/flutter_test.dart';
import 'package:flettra_mobile/src/widgets/avatar.dart';

/// Regression tests for the "EN" avatar.
///
/// Every user without a profile picture rendered a green tile reading **EN**,
/// because `ApiService.getAvatarUrl` built its ui-avatars.com URL with
/// `'…&name=\$encoded'` — an escaped `$` inside a single-quoted string, so the
/// literal text `$encoded` was sent as the name and ui-avatars returned the
/// first two letters of "encoded".
///
/// Initials are now computed locally by [Avatar.initialsOf], so these tests
/// pin the behaviour that replaced it.
void main() {
  group('Avatar.initialsOf', () {
    test('takes first and last initials of a full name', () {
      expect(Avatar.initialsOf('Sathya Prakash'), 'SP');
    });

    test('takes one initial from a single word', () {
      expect(Avatar.initialsOf('gowtham'), 'G');
    });

    test('skips middle names', () {
      expect(Avatar.initialsOf('Bagyalakshmi Rani Traveler'), 'BT');
    });

    test('collapses extra whitespace', () {
      expect(Avatar.initialsOf('  Sathya   Prakash  '), 'SP');
    });

    test('never returns "EN" for an absent name', () {
      for (final value in <String?>[null, '', '   ']) {
        expect(Avatar.initialsOf(value), isNull,
            reason: 'a missing name must fall through to the person glyph');
      }
    });

    test('returns null for an encrypted value rather than a hex digit', () {
      // If a stale server or cached response leaks the raw column, one hex
      // character on an avatar is worse than the glyph.
      const ciphertext =
          '1ff1c69de91109f3d3f2377b:5fb5155c03449fcc3a68b6789b99c432:d67368add5fc';
      expect(Avatar.initialsOf(ciphertext), isNull);
    });

    test('returns null for a value with no letters', () {
      expect(Avatar.initialsOf('12345'), isNull);
      expect(Avatar.initialsOf('!!!'), isNull);
    });

    test('takes whole grapheme clusters for non-Latin names', () {
      // 'பி' is one cluster (consonant + vowel sign), so the initial is 'பி'
      // and not the bare consonant. Slicing by code unit would split it and
      // render a broken glyph.
      expect(Avatar.initialsOf('சத்யா பிரகாஷ்'), 'சபி');
    });
  });

  group('Avatar.resolveUrl', () {
    test('passes absolute URLs through', () {
      const url = 'https://res.cloudinary.com/x/image/upload/v1/a.jpg';
      expect(Avatar.resolveUrl(url), url);
    });

    test('returns null for an absent picture instead of inventing a URL', () {
      expect(Avatar.resolveUrl(null), isNull);
      expect(Avatar.resolveUrl(''), isNull);
      expect(Avatar.resolveUrl('   '), isNull);
    });

    test('returns null for a pre-Cloudinary /uploads path', () {
      // Those files lived on a container disk that is wiped on every deploy,
      // so requesting them is a guaranteed 404 and a guaranteed broken image.
      expect(Avatar.resolveUrl('/uploads/files/abc.jpg'), isNull);
    });

    test('makes a relative path absolute', () {
      expect(Avatar.resolveUrl('media/a.jpg'), endsWith('/media/a.jpg'));
      expect(Avatar.resolveUrl('/media/a.jpg'), endsWith('/media/a.jpg'));
    });
  });
}
