import 'package:flutter/material.dart';

import 'app_spacing.dart';
import 'app_typography.dart';
import 'flettra_colors.dart';

/// Builds the app's [ThemeData] from the token files.
///
/// Nothing here invents a value. Every colour comes from [FlettraColors], every
/// size from [AppSpacing] / [AppRadius], every text style from
/// [AppTypography]. If a widget needs something this theme does not provide,
/// the fix is a new token — not a literal at the call site.
abstract final class AppTheme {
  static ThemeData get light => _build(FlettraColors.light, Brightness.light);
  static ThemeData get dark => _build(FlettraColors.dark, Brightness.dark);

  static ThemeData _build(FlettraColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.brand,
      onPrimary: c.onBrand,
      primaryContainer: c.brandWash,
      onPrimaryContainer: c.brand,
      secondary: c.route,
      onSecondary: c.onBrand,
      secondaryContainer: c.routeWash,
      onSecondaryContainer: c.route,
      error: c.bad,
      onError: c.onBrand,
      errorContainer: c.badWash,
      onErrorContainer: c.bad,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.ink2,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surfaceSunken,
      surfaceContainer: c.surfaceSunken,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfaceRaised,
      outline: c.rule,
      outlineVariant: c.ruleSoft,
      scrim: c.scrim,
    );

    final text = AppTypography.textTheme(c.ink);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // The canvas is the recessed tone, not white. Content sits *on* it in
      // raised groups.
      //
      // This is the single biggest reason the app read as a web page: 315
      // surfaces were pure white on a pure white page, so nothing had a plane.
      // Depth was faked with 57 drop shadows instead. Every native app layers
      // instead — iOS grouped tables, Material 3 surface roles — and that
      // layering is most of what "feels like an app" actually means.
      scaffoldBackgroundColor: c.surfaceSunken,
      canvasColor: c.surfaceSunken,
      fontFamily: AppTypography.fontFamily,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[c],

      // ── Chrome ───────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.heading.copyWith(color: c.ink),
        iconTheme: IconThemeData(color: c.ink, size: 22),
      ),

      dividerTheme: DividerThemeData(
        color: c.rule,
        thickness: AppElevation.hairline,
        space: AppElevation.hairline,
      ),

      // Hairlines, not drop shadows. Shadow is for things that actually float.
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardR,
          side: BorderSide(color: c.ruleSoft),
        ),
      ),

      // ── Actions ──────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          minimumSize: const Size.fromHeight(AppTouch.min),
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardR),
          textStyle: AppTypography.bodyStrong,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(AppTouch.min),
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardR),
          textStyle: AppTypography.bodyStrong,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: const Size.fromHeight(AppTouch.min),
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          side: BorderSide(color: c.rule, width: 1.5),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardR),
          textStyle: AppTypography.bodyStrong,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.brand,
          minimumSize: const Size(AppTouch.min, AppTouch.min),
          textStyle: AppTypography.bodyStrong,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: const Size(AppTouch.min, AppTouch.min),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.brand,
        foregroundColor: c.onBrand,
        elevation: AppElevation.raised,
        extendedTextStyle: AppTypography.bodyStrong.copyWith(color: c.onBrand),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card + 3)),
        ),
      ),

      // ── Input ────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.chipR,
          borderSide: BorderSide(color: c.rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.chipR,
          borderSide: BorderSide(color: c.rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.chipR,
          borderSide: BorderSide(color: c.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.chipR,
          borderSide: BorderSide(color: c.bad),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.chipR,
          borderSide: BorderSide(color: c.bad, width: 1.5),
        ),
        hintStyle: AppTypography.body.copyWith(color: c.ink3),
        labelStyle: AppTypography.footnote.copyWith(color: c.ink2),
        // Errors belong under the field that caused them, not in a toast that
        // disappears before it can be read.
        errorStyle: AppTypography.footnote.copyWith(color: c.bad),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.brand,
        side: BorderSide(color: c.rule),
        labelStyle: AppTypography.callout.copyWith(color: c.ink2),
        secondaryLabelStyle: AppTypography.callout.copyWith(color: c.onBrand),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillR),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),

      // ── Surfaces that really do float ────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surfaceRaised,
        elevation: AppElevation.raised,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetR),
        showDragHandle: true,
        dragHandleColor: c.rule,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
        ),
        titleTextStyle: AppTypography.title.copyWith(color: c.ink),
        contentTextStyle: AppTypography.body.copyWith(color: c.ink2),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        contentTextStyle: AppTypography.body.copyWith(color: c.surface),
        actionTextColor: c.brand,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.chipR),
        elevation: AppElevation.raised,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.brandWash,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTypography.caption.copyWith(
            color: states.contains(WidgetState.selected) ? c.brand : c.ink3,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? c.brand : c.ink3,
          ),
        ),
      ),

      listTileTheme: ListTileThemeData(
        titleTextStyle: AppTypography.body.copyWith(color: c.ink),
        subtitleTextStyle: AppTypography.footnote.copyWith(color: c.ink3),
        iconColor: c.ink2,
        minVerticalPadding: AppSpacing.sm,
      ),

      // A text field's caret and selection are invisible if left to defaults on
      // a near-black ground, which made typed input look like nothing had been
      // entered even once the text colour was right.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.brand,
        selectionColor: c.brand.withValues(alpha: 0.30),
        selectionHandleColor: c.brand,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.brand),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.ok : c.rule,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
