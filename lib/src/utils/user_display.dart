/// Turning an API user object into something safe to show.
///
/// The backend stores names AES-256-GCM encrypted and serialises them as
/// `<iv_hex>:<tag_hex>:<ciphertext_hex>`. Several endpoints used to return the
/// raw column, so the app rendered strings like
/// `1ff1c69de911…:5fb5155c…:d67368add5fc` as a person's name — in chat, on
/// expenses, and as the initial on a live-map pin.
///
/// The server side is fixed, but the guard stays for two reasons: an old app
/// build talks to the new server and vice versa during a staged rollout, and a
/// cached response can outlive a deploy. A name that fails [looksEncrypted]
/// falls through to the next candidate rather than reaching the screen.
library;

/// Matches the `iv:tag:ciphertext` serialisation: three long all-hex segments.
final RegExp _ciphertext = RegExp(r'^[0-9a-f]{8,}:[0-9a-f]{8,}:[0-9a-f]{8,}$');

/// True when [value] is a stored ciphertext rather than a readable name.
bool looksEncrypted(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return false;
  return _ciphertext.hasMatch(v.toLowerCase());
}

/// A candidate is usable when it is non-blank, not 'null', and not ciphertext.
String? _clean(Object? raw) {
  final v = raw?.toString().trim() ?? '';
  if (v.isEmpty || v == 'null') return null;
  if (looksEncrypted(v)) return null;
  return v;
}

/// Display name for an API user object.
///
/// Prefers the server-computed `name`, then `firstName lastName`, then the
/// local part of the email, then [fallback].
String userName(Object? user, {String fallback = 'User'}) {
  if (user is! Map) return fallback;

  final name = _clean(user['name']);
  if (name != null) return name;

  final first = _clean(user['firstName']);
  final last = _clean(user['lastName']);
  final full = [first, last].whereType<String>().join(' ').trim();
  if (full.isNotEmpty) return full;

  final email = _clean(user['email']);
  if (email != null && email.contains('@')) return email.split('@').first;

  return fallback;
}

/// Display name for a chat message's sender, whether the payload nests the
/// sender object or only carries `senderId`.
String senderName(Object? message, {String fallback = 'User'}) {
  if (message is! Map) return fallback;
  final sender = message['sender'];
  if (sender is Map) return userName(sender, fallback: fallback);
  return fallback;
}

/// Profile picture path from a user object, or null when there is none.
String? userPicture(Object? user) {
  if (user is! Map) return null;
  final raw =
      user['profilePicture'] ?? user['profile_picture'] ?? user['avatar'];
  final v = raw?.toString().trim() ?? '';
  return v.isEmpty ? null : v;
}
