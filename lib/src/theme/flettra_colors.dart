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
    // Nightshift's daylight counterpart. Lime is unreadable as text on a light
    // ground, so in this mode the brand resolves to the deep olive end of the
    // same hue — legible as a label and usable as a fill with white on top.
    // Dark is the default; this exists for anyone who forces light.
    brand: Color(0xFF43600A),
    brandWash: Color(0xFFEDF6D5),
    onBrand: Color(0xFFFFFFFF),
    route: Color(0xFF1A56B8),
    routeWash: Color(0xFFE6EEFB),
    ink: Color(0xFF12140F),
    ink2: Color(0xFF5C6156),
    ink3: Color(0xFF8D9385),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF3F4EF),
    surfaceRaised: Color(0xFFFFFFFF),
    rule: Color(0xFFE2E4DA),
    ruleSoft: Color(0xFFEDEEE6),
    ok: Color(0xFF1B7F4B),
    okWash: Color(0xFFE4F3E9),
    warn: Color(0xFF8A5B0A),
    warnWash: Color(0xFFFBF1DC),
    bad: Color(0xFFB3271A),
    badWash: Color(0xFFFCE9E7),
    scrim: Color(0x8C12140F),
  );

  // ── Dark ─────────────────────────────────────────────────────────────────

  static const FlettraColors dark = FlettraColors(
    // Nightshift. The lime is loud enough that it can only carry one thing per
    // screen — which is the point: the palette enforces the accent discipline
    // instead of relying on us to.
    brand: Color(0xFFB9F227),
    brandWash: Color(0xFF232D0C),
    onBrand: Color(0xFF0F1405),
    // Movement reads blue so it never competes with the lime for attention.
    route: Color(0xFF7FB2FF),
    routeWash: Color(0xFF121C2E),
    ink: Color(0xFFEDF2E6),
    ink2: Color(0xFF9AA692),
    ink3: Color(0xFF6B7565),
    surface: Color(0xFF161915),
    surfaceSunken: Color(0xFF0B0D0A),
    surfaceRaised: Color(0xFF161915),
    rule: Color(0xFF272B24),
    ruleSoft: Color(0xFF1F231C),
    ok: Color(0xFF5FD98A),
    okWash: Color(0xFF122A1C),
    warn: Color(0xFFE8B33D),
    warnWash: Color(0xFF2C2210),
    bad: Color(0xFFFF7A6B),
    badWash: Color(0xFF2E1815),
    scrim: Color(0xB3000000),
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
