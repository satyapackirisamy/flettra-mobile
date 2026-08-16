import 'package:flutter/material.dart';

/// Typography for Flettra.
///
/// DM Sans, bundled in `assets/fonts` rather than fetched by `google_fonts` at
/// launch. Same typeface the app has always used — it just no longer costs a
/// network round trip before the first frame can paint.
///
/// Eight sizes, down from the 25 the audit counted. Sizes are unitless logical
/// pixels, which Flutter treats as points.
abstract final class AppTypography {
  static const String fontFamily = 'DMSans';

  /// Nothing below this ships. 11 is reserved for badges and tab labels.
  static const double minSize = 11;

  // ── The scale ─────────────────────────────────────────────────────────────

  /// Large screen titles. 24 / 29, bold.
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 29 / 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );

  /// Screen and sheet titles. 19 / 25, bold.
  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 19,
    height: 25 / 19,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  /// Section headers, card titles. 16 / 21, semibold.
  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 21 / 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.28,
  );

  /// Primary content and list rows. 15 / 20.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
  );

  /// Emphasis within body text — prices, names, the thing being acted on.
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  /// Secondary content. 13.5 / 18.
  static const TextStyle callout = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.5,
    height: 18 / 13.5,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
  );

  /// Metadata and timestamps. 12 / 16, medium.
  static const TextStyle footnote = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );

  /// Badges, tab labels, overlines. 11 / 14, semibold. The floor.
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: minSize,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  /// Ad-hoc DM Sans style.
  ///
  /// Migration shim for the ~560 `AppTypography.dmSans(...)` call sites. It takes
  /// the same named arguments, so the swap is mechanical, but resolves the
  /// bundled family instead of asking `google_fonts` to find a font it cannot
  /// (Flutter's directory asset inclusion skips the space in "DM Sans-*.ttf",
  /// so with runtime fetching off every one of those calls threw).
  ///
  /// Prefer the named styles above. Reach for this only while migrating a
  /// screen — a call site that passes its own `fontSize` is a call site that
  /// has opted out of the scale.
  static TextStyle dmSans({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    TextDecoration? decoration,
    List<Shadow>? shadows,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
      decoration: decoration,
      shadows: shadows,
    );
  }

  // ── Material mapping ──────────────────────────────────────────────────────

  /// Maps the scale onto Material's [TextTheme] so framework widgets that read
  /// `Theme.of(context).textTheme` pick up the right style without being told.
  static TextTheme textTheme(Color onSurface) {
    TextStyle c(TextStyle s) => s.copyWith(color: onSurface);
    return TextTheme(
      displaySmall: c(display),
      headlineMedium: c(display),
      headlineSmall: c(title),
      titleLarge: c(title),
      titleMedium: c(heading),
      titleSmall: c(bodyStrong),
      bodyLarge: c(body),
      bodyMedium: c(callout),
      bodySmall: c(footnote),
      labelLarge: c(bodyStrong),
      labelMedium: c(footnote),
      labelSmall: c(caption),
    );
  }

  /// Clamp for Dynamic Type / font-size accessibility settings.
  ///
  /// Honouring the setting matters; honouring it without bound breaks every
  /// fixed-height row in the app. 0.85–1.3 is the range the layouts hold at.
  static const double minScale = 0.85;
  static const double maxScale = 1.3;

  static TextScaler clampScaler(TextScaler scaler) =>
      scaler.clamp(minScaleFactor: minScale, maxScaleFactor: maxScale);
}
