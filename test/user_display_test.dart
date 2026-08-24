import 'package:flutter_test/flutter_test.dart';
import 'package:flettra_mobile/src/utils/user_display.dart';

/// The backend stores names AES-256-GCM encrypted, serialised as
/// `iv:tag:ciphertext`. Several endpoints returned the raw column, so the app
/// showed strings like `1ff1c69de911…:5fb5155c…:d67368add5fc` as a person's
/// name — in chat, on the expenses list, and as the initial on a map pin.
///
/// The server is fixed; this guard exists so an old build against a new server
/// (or a cached response) still cannot put a hex blob on screen.
void main() {
  const ciphertext =
      '1ff1c69de91109f3d3f2377b:5fb5155c03449fcc3a68b6789b99c432:d67368add5fc';

  group('looksEncrypted', () {
    test('detects the iv:tag:ciphertext shape', () {
      expect(looksEncrypted(ciphertext), isTrue);
    });

    test('does not flag ordinary names', () {
      for (final name in [
        'Sathya Prakash',
        'gowtham',
        'Bagyalakshmi Traveler',
        'Anne-Marie O\'Brien',
        '',
        null,
      ]) {
        expect(looksEncrypted(name), isFalse, reason: '$name');
      }
    });

    test('does not flag a time or a ratio that happens to contain colons', () {
      expect(looksEncrypted('10:47:32'), isFalse);
    });
  });

  group('userName', () {
    test('prefers the server-computed name', () {
      expect(
        userName({'name': 'Sathya Prakash', 'firstName': 'ignored'}),
        'Sathya Prakash',
      );
    });

    test('falls back to firstName lastName', () {
      expect(userName({'firstName': 'Sathya', 'lastName': 'Prakash'}),
          'Sathya Prakash');
    });

    test('falls back to the email local part', () {
      expect(userName({'email': 'satya@alchemdigital.com'}), 'satya');
    });

    test('skips an encrypted name and keeps looking', () {
      expect(
        userName({'name': ciphertext, 'email': 'satya@alchemdigital.com'}),
        'satya',
      );
    });

    test('skips encrypted firstName and lastName', () {
      expect(
        userName({'firstName': ciphertext, 'lastName': ciphertext}),
        'User',
      );
    });

    test('never returns a ciphertext, whatever the payload', () {
      final result = userName({
        'name': ciphertext,
        'firstName': ciphertext,
        'lastName': ciphertext,
        'email': ciphertext,
      });
      expect(looksEncrypted(result), isFalse);
      expect(result, 'User');
    });

    test('treats the literal string "null" as absent', () {
      expect(userName({'name': 'null', 'firstName': 'Sathya'}), 'Sathya');
    });

    test('uses the given fallback', () {
      expect(userName(null, fallback: 'Chat'), 'Chat');
      expect(userName(<String, dynamic>{}, fallback: 'Chat'), 'Chat');
    });
  });

  group('senderName', () {
    test('reads the nested sender object', () {
      expect(
        senderName({'sender': {'name': 'Sathya Prakash'}}),
        'Sathya Prakash',
      );
    });

    test('falls back when only senderId is present', () {
      expect(senderName({'senderId': 'abc'}), 'User');
    });

    test('does not surface an encrypted sender name', () {
      expect(senderName({'sender': {'firstName': ciphertext}}), 'User');
    });
  });

  group('userPicture', () {
    test('reads the common field spellings', () {
      expect(userPicture({'profilePicture': 'a.jpg'}), 'a.jpg');
      expect(userPicture({'profile_picture': 'b.jpg'}), 'b.jpg');
      expect(userPicture({'avatar': 'c.jpg'}), 'c.jpg');
    });

    test('returns null for an empty or missing value', () {
      expect(userPicture({'profilePicture': ''}), isNull);
      expect(userPicture(<String, dynamic>{}), isNull);
      expect(userPicture(null), isNull);
    });
  });
}
