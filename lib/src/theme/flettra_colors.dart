import 'package:flutter/material.dart';

/// Semantic colour tokens for Flettra, in both themes.
///
/// Material's [ColorScheme] covers primary/surface/error and little else, so
/// the tokens the app actually reasons about — "the route colour", "the wash
/// behind a success badge" — live here as a [ThemeExtension].
///
/// Read them with `context.c` (see [FlettraColorsX]) rather than importing
/// hex literals. The audit counted 675 hard-coded `Color(0x…)` values in widget
/// code; every one of them is a place the dark theme would have broken.
@immutable
class FlettraColors extends ThemeExtension<FlettraColors> {
  const FlettraColors({
    required this.brand,
    required this.brandWash,
    required this.onBrand,
    required this.route,
    required this.routeWash,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.surface,
    required this.surfaceSunken,
    required this.surfaceRaised,
    required this.rule,
    required this.ruleSoft,
    required this.ok,
    required this.okWash,
    required this.warn,
    required this.warnWash,
    required this.bad,
    required this.badWash,
    required this.scrim,
  });

  /// The action colour. Filled buttons, active states, links.
  final Color brand;

  /// Tinted ground for brand-coloured badges and highlighted rows.
  final Color brandWash;

  /// Foreground on top of [brand].
  final Color onBrand;

  /// "Something is moving" — live tracking, map polylines, the departure
  /// timeline, shared location. Distinct from [brand], which means "act".
  final Color route;
  final Color routeWash;

  /// Primary text.
  final Color ink;

  /// Secondary text — supporting lines that are still meant to be read.
  final Color ink2;

  /// Tertiary text — metadata, placeholders, disabled glyphs.
  final Color ink3;

  /// Default screen background.
  final Color surface;

  /// Recessed fill: grouped-list backgrounds, search fields, chip grounds.
  final Color surfaceSunken;

  /// Raised fill: cards, sheets, list groups.
  final Color surfaceRaised;

  /// Hairline separators between rows.
  final Color rule;

  /// A softer separator, for divisions inside a group.
  final Color ruleSoft;

  final Color ok;
  final Color okWash;
  final Color warn;
  final Color warnWash;
  final Color bad;
  final Color badWash;

  /// Overlay behind modals and sheets.
  final Color scrim;

  // ── Light ────────────────────────────────────────────────────────────────

  static const FlettraColors light = FlettraColors(
    // Deepened from the original #FF6B2C so white text on a filled button
    // clears contrast at button sizes.
    brand: Color(0xFFE8551A),
    brandWash: Color(0xFFFDEFE7),
    onBrand: Color(0xFFFFFFFF),
    route: Color(0xFF0F6E68),
    routeWash: Color(0xFFE4F1EF),
    ink: Color(0xFF17120E),
    ink2: Color(0xFF6B625B),
    ink3: Color(0xFF9C918A),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF6F3F0),
    surfaceRaised: Color(0xFFFFFFFF),
    rule: Color(0xFFE6DFD8),
    ruleSoft: Color(0xFFF0EAE4),
    ok: Color(0xFF12805C),
    okWash: Color(0xFFE4F3EE),
    warn: Color(0xFFB4690E),
    warnWash: Color(0xFFFBF0DF),
    bad: Color(0xFFC2321F),
    badWash: Color(0xFFFBEBE8),
    scrim: Color(0x8C17120E),
  );

  // ── Dark ─────────────────────────────────────────────────────────────────

  static const FlettraColors dark = FlettraColors(
    // Brightened — #E8551A goes muddy on a dark ground.
    brand: Color(0xFFFF7A3D),
    brandWash: Color(0xFF33200F),
    onBrand: Color(0xFF1A0B03),
    route: Color(0xFF48B3AB),
    routeWash: Color(0xFF0F2B29),
    ink: Color(0xFFF5F1ED),
    ink2: Color(0xFFADA49C),
    ink3: Color(0xFF7E756E),
    surface: Color(0xFF131110),
    surfaceSunken: Color(0xFF0C0B0A),
    surfaceRaised: Color(0xFF1D1A18),
    rule: Color(0xFF302B27),
    ruleSoft: Color(0xFF241F1C),
    ok: Color(0xFF3BB98C),
    okWash: Color(0xFF0F2A22),
    warn: Color(0xFFDFA02F),
    warnWash: Color(0xFF2E2211),
    bad: Color(0xFFE8705C),
    badWash: Color(0xFF2E1815),
    scrim: Color(0x99000000),
  );

  @override
  FlettraColors copyWith({
    Color? brand,
    Color? brandWash,
    Color? onBrand,
    Color? route,
    Color? routeWash,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? surface,
    Color? surfaceSunken,
    Color? surfaceRaised,
    Color? rule,
    Color? ruleSoft,
    Color? ok,
    Color? okWash,
    Color? warn,
    Color? warnWash,
    Color? bad,
    Color? badWash,
    Color? scrim,
  }) {
    return FlettraColors(
      brand: brand ?? this.brand,
      brandWash: brandWash ?? this.brandWash,
      onBrand: onBrand ?? this.onBrand,
      route: route ?? this.route,
      routeWash: routeWash ?? this.routeWash,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      surface: surface ?? this.surface,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      rule: rule ?? this.rule,
      ruleSoft: ruleSoft ?? this.ruleSoft,
      ok: ok ?? this.ok,
      okWash: okWash ?? this.okWash,
      warn: warn ?? this.warn,
      warnWash: warnWash ?? this.warnWash,
      bad: bad ?? this.bad,
      badWash: badWash ?? this.badWash,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  FlettraColors lerp(ThemeExtension<FlettraColors>? other, double t) {
    if (other is! FlettraColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FlettraColors(
      brand: l(brand, other.brand),
      brandWash: l(brandWash, other.brandWash),
      onBrand: l(onBrand, other.onBrand),
      route: l(route, other.route),
      routeWash: l(routeWash, other.routeWash),
      ink: l(ink, other.ink),
      ink2: l(ink2, other.ink2),
      ink3: l(ink3, other.ink3),
      surface: l(surface, other.surface),
      surfaceSunken: l(surfaceSunken, other.surfaceSunken),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      rule: l(rule, other.rule),
      ruleSoft: l(ruleSoft, other.ruleSoft),
      ok: l(ok, other.ok),
      okWash: l(okWash, other.okWash),
      warn: l(warn, other.warn),
      warnWash: l(warnWash, other.warnWash),
      bad: l(bad, other.bad),
      badWash: l(badWash, other.badWash),
      scrim: l(scrim, other.scrim),
    );
  }
}

/// `context.c.brand` — the way widget code should reach a colour.
extension FlettraColorsX on BuildContext {
  FlettraColors get c =>
      Theme.of(this).extension<FlettraColors>() ?? FlettraColors.light;
}
