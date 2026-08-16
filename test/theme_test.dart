import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flettra_mobile/src/theme/app_theme.dart';
import 'package:flettra_mobile/src/theme/app_typography.dart';
import 'package:flettra_mobile/src/theme/flettra_colors.dart';

void main() {
  test('both themes build and carry the colour tokens', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final colors = theme.extension<FlettraColors>();
      expect(colors, isNotNull,
          reason: 'FlettraColors must be registered as a ThemeExtension, or '
              'context.c silently falls back to the light palette.');
      expect(theme.colorScheme.primary, colors!.brand);
      expect(theme.scaffoldBackgroundColor, colors.surface);
    }
  });

  test('light and dark are actually different', () {
    final light = AppTheme.light.extension<FlettraColors>()!;
    final dark = AppTheme.dark.extension<FlettraColors>()!;
    expect(light.surface, isNot(dark.surface));
    expect(light.ink, isNot(dark.ink));
    expect(light.brand, isNot(dark.brand));
  });

  test('nothing in the type scale ships below 11pt', () {
    const scale = <String, TextStyle>{
      'display': AppTypography.display,
      'title': AppTypography.title,
      'heading': AppTypography.heading,
      'body': AppTypography.body,
      'bodyStrong': AppTypography.bodyStrong,
      'callout': AppTypography.callout,
      'footnote': AppTypography.footnote,
      'caption': AppTypography.caption,
    };
    scale.forEach((name, style) {
      expect(style.fontSize, greaterThanOrEqualTo(AppTypography.minSize),
          reason: '$name is below the ${AppTypography.minSize}pt floor');
      expect(style.fontFamily, AppTypography.fontFamily,
          reason: '$name must use the bundled family, not a runtime-fetched one');
    });
  });

  testWidgets('context.c resolves tokens from the active theme', (tester) async {
    late FlettraColors seen;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(builder: (context) {
        seen = context.c;
        return const SizedBox();
      }),
    ));
    expect(seen.surface, FlettraColors.dark.surface);
  });
}
