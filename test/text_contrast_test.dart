import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flettra_mobile/src/screens/onboarding_screen.dart';
import 'package:flettra_mobile/src/theme/app_theme.dart';
import 'package:flettra_mobile/src/theme/flettra_colors.dart';

/// Renders real screens under the dark theme and asserts their text is actually
/// legible. The source-level guards catch known-bad tokens; this catches the
/// outcome, which is what the reports were about — text present but unreadable.
double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding slides render legible text on the dark theme',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const OnboardingScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    final dark = FlettraColors.dark;
    final canvasLum = _lum(dark.surfaceSunken);

    final texts = tester.widgetList<Text>(find.byType(Text));
    expect(texts, isNotEmpty, reason: 'Nothing rendered to check.');

    final unreadable = <String>[];
    for (final t in texts) {
      final color = t.style?.color;
      if (color == null) continue; // inherits from the theme, which is correct
      if (color.a < 0.5) continue; // deliberately faint
      // Text must differ from the canvas by a real margin. Both near-black text
      // on the dark canvas and a surface token used as a colour fail here.
      if ((_lum(color) - canvasLum).abs() < 0.05) {
        unreadable.add('"${t.data}" -> ${color.toARGB32().toRadixString(16)}');
      }
    }
    expect(unreadable, isEmpty,
        reason: 'Text indistinguishable from the canvas:\n'
            '${unreadable.join('\n')}');
  });
}
