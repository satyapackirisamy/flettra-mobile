import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_typography.dart';
import '../theme/flettra_colors.dart';
import 'network_image_widget.dart';

/// The one way to draw a person in Flettra.
///
/// Replaces `ApiService.getAvatarUrl`, which built a `ui-avatars.com` URL when
/// someone had no profile picture. Two things were wrong with that:
///
///  1. The name was interpolated with an escaped `$` — `'…&name=\$encoded'` in a
///     single-quoted Dart string — so the literal text `$encoded` was sent to
///     ui-avatars for *every* user without a photo. ui-avatars took the first
///     two letters of "encoded" and rendered **EN**, which is the green "EN"
///     tile on every avatar in the app.
///  2. Even with the interpolation fixed it sent the person's real name to a
///     third party on every single render, which the App Store privacy manifest
///     does not declare, and cost a network round trip per avatar.
///
/// Initials are drawn locally instead: instant, offline, and nothing leaves the
/// device. When there is no name to take initials from, a person glyph is used
/// rather than a meaningless letter.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 40,
    this.showRing = false,
    this.onTap,
  });

  /// Raw value from the API — may be null, empty, a relative path, or absolute.
  final String? imageUrl;

  /// Display name. Initials come from this; null or blank gives the glyph.
  final String? name;

  /// Diameter in logical pixels.
  final double size;

  /// A hairline brand ring, for "this is you" or an active state.
  final bool showRing;

  final VoidCallback? onTap;

  /// Up to two initials: "Sathya Prakash" → "SP", "gowtham" → "G".
  ///
  /// Guards against a value that is not a real name. An encrypted field leaking
  /// through would start with a hex digit, and a lone "5" on an avatar is worse
  /// than the glyph — so anything not starting with a letter gets the glyph.
  static String? initialsOf(String? name) {
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return null;

    final words = trimmed
        .split(RegExp(r'\s+'))
        .where(
            (w) => w.isNotEmpty && RegExp(r'^\p{L}', unicode: true).hasMatch(w))
        .toList();
    if (words.isEmpty) return null;

    if (words.length == 1) return words.first.characters.first.toUpperCase();
    return (words.first.characters.first + words.last.characters.first)
        .toUpperCase();
  }

  /// Absolute URL for a stored picture, or null when there is nothing to load.
  ///
  /// Unlike the old helper this never invents a placeholder URL — an absent
  /// photo is drawn locally, not fetched.
  static String? resolveUrl(String? raw) {
    final path = (raw ?? '').trim();
    if (path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    // Pre-Cloudinary uploads lived on a container disk that is wiped on every
    // deploy, so these are guaranteed 404s. Skip straight to the fallback.
    if (path.contains('/uploads/')) return null;
    return '${ApiService.baseUrl}${path.startsWith('/') ? '' : '/'}$path';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final url = resolveUrl(imageUrl);

    Widget content = url == null
        ? _fallback(context)
        : ClipOval(
            child: SafeNetworkImage(
              url: url,
              width: size,
              height: size,
              errorWidget: _fallback(context),
            ),
          );

    if (showRing) {
      content = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.brand, width: 1.5),
        ),
        child: content,
      );
    }

    final sized = SizedBox(
      width: showRing ? size + 7 : size,
      height: showRing ? size + 7 : size,
      child: Center(child: content),
    );

    if (onTap == null) return sized;
    return GestureDetector(onTap: onTap, child: sized);
  }

  /// Initials on a brand wash, or a person glyph when there are no initials.
  Widget _fallback(BuildContext context) {
    final c = context.c;
    final initials = initialsOf(name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.brandWash,
        shape: BoxShape.circle,
        border: Border.all(color: c.brand.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      child: initials == null
          ? Icon(
              Icons.person_rounded,
              size: size * 0.56,
              color: c.brand.withValues(alpha: 0.75),
            )
          : Text(
              initials,
              textAlign: TextAlign.center,
              style: AppTypography.dmSans(
                // Two characters need to be a touch smaller than one to fit.
                fontSize: size * (initials.length > 1 ? 0.36 : 0.42),
                fontWeight: FontWeight.w700,
                color: c.brand,
                letterSpacing: 0,
              ),
            ),
    );
  }
}

/// Overlapping avatars for "who's coming" rows.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.people,
    this.size = 32,
    this.max = 4,
  });

  /// Each entry is a user map — `name` and `profilePicture` are read from it.
  final List<Map<String, dynamic>> people;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = people.take(max).toList();
    final extra = people.length - shown.length;
    final overlap = size * 0.32;

    return SizedBox(
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.c.surface, width: 2),
                ),
                child: Avatar(
                  size: size - 4,
                  name: shown[i]['name']?.toString(),
                  imageUrl: shown[i]['profilePicture']?.toString(),
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * (size - overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: context.c.surfaceSunken,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.c.surface, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$extra',
                  style: AppTypography.caption.copyWith(color: context.c.ink2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
