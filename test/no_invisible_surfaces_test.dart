import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

/// A source-level guard against the two bugs that repeatedly shipped invisible
/// UI during the move to the dark Nightshift palette.
///
/// Both were caught by a person looking at the running app rather than by any
/// check, several times over. These assertions make them mechanical.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.contains('otp_screen'))
      .toList();

  /// Files that legitimately hold raw colour values.
  bool isPaletteFile(String path) =>
      path.endsWith('flettra_colors.dart') ||
      path.endsWith('app_colors.dart') ||
      path.endsWith('app_theme.dart');

  test('no screen paints a hard-coded white surface', () {
    // `ink` is near-white in the dark theme, so any surface still forced to
    // white renders as a white card full of invisible text.
    final surfaceWhite = RegExp(
        r'(?:color|backgroundColor|fillColor)\s*:\s*(?:const\s+)?'
        r'(?:Colors\.white\b(?!\d)|Color\(0x[fF]{8}\))');

    final offenders = <String>[];
    for (final file in dartFiles) {
      if (isPaletteFile(file.path)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Text and icons over photographs are legitimately white. A style can
        // span several lines, so look back as well as at this one — checking
        // only the current line missed both cases.
        final window =
            lines.sublist(i - 10 < 0 ? 0 : i - 10, i + 1).join('\n');
        if (RegExp(r'TextStyle\(|AppTypography\.|Icon\(|withOpacity|withValues')
            .hasMatch(window)) {
          continue;
        }
        if (surfaceWhite.hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Surfaces must come from context.c.* so both themes apply:\n'
            '${offenders.join('\n')}');
  });

  test('no BoxDecoration is left without a fill', () {
    // Stripping the decorative brand gradients left several containers painting
    // nothing, while their children still used onBrand — near-black text on a
    // near-black canvas. Invisible, and impossible to spot in a diff.
    final offenders = <String>[];
    for (final file in dartFiles) {
      final src = file.readAsStringSync();
      for (final match in RegExp(r'BoxDecoration\(').allMatches(src)) {
        var depth = 1;
        var j = match.end;
        while (j < src.length && depth > 0) {
          if (src[j] == '(') depth++;
          if (src[j] == ')') depth--;
          j++;
        }
        final body = src.substring(match.end, j - 1);
        final paints = body.contains('color:') ||
            body.contains('gradient:') ||
            body.contains('image:');
        if (!paints) {
          final line = src.substring(0, match.start).split('\n').length;
          offenders.add('${file.path}:$line');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'A BoxDecoration with no color/gradient/image paints nothing. '
            'Give it a fill, or use a plain Container:\n'
            '${offenders.join('\n')}');
  });

  test('no surface token is used as a text or icon colour', () {
    // The bug that shipped repeatedly: a white *foreground* (text on a photo, a
    // label on a filled button) was swept onto a surface token. surfaceRaised is
    // near-black in Nightshift, so the text vanished. Foregrounds must use ink*,
    // onBrand, or a literal white when they sit on media.
    final offenders = <String>[];
    for (final file in dartFiles) {
      if (isPaletteFile(file.path)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final match = RegExp(
                r'color:\s*context\.c\.(surface|surfaceRaised|surfaceSunken)\b')
            .firstMatch(line);
        if (match == null) continue;

        // Only a hit when a text/icon constructor opens before this colour and
        // no container decoration intervenes. Without the position check, a
        // Container whose child is an Icon on the same line reads as a false
        // positive.
        final before = line.substring(0, match.start);
        final opensForeground =
            RegExp(r'AppTypography\.|TextStyle\(|Icon\(').hasMatch(before);
        final opensContainer =
            RegExp(r'BoxDecoration\(|Container\(|decoration:').hasMatch(before);
        if (opensForeground && !opensContainer) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Surface tokens are backgrounds. Use ink/ink2/ink3, onBrand, or '
            'Colors.white over media:\n${offenders.join('\n')}');
  });

  test('no near-black colour literal survives outside the palette', () {
    // Any hand-written near-black is invisible on the Nightshift canvas. This is
    // what left the login inputs and the onboarding headline unreadable.
    double luminance(String hex) {
      double channel(int v) {
        final c = v / 255;
        return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;
      }
      // 0xAARRGGBB — RGB begins at index 4.
      return 0.2126 * channel(int.parse(hex.substring(4, 6), radix: 16)) +
          0.7152 * channel(int.parse(hex.substring(6, 8), radix: 16)) +
          0.0722 * channel(int.parse(hex.substring(8, 10), radix: 16));
    }

    final offenders = <String>[];
    final literal = RegExp(r'Color\((0x[0-9A-Fa-f]{8})\)');
    for (final file in dartFiles) {
      if (isPaletteFile(file.path)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Scrims and shadows are deliberately dark and semi-transparent.
        if (RegExp(r'Shadow|scrim|withOpacity|withValues|barrier|colors: \[')
            .hasMatch(lines[i])) continue;
        for (final m in literal.allMatches(lines[i])) {
          final hex = m.group(1)!;
          if (hex.substring(2, 4).toUpperCase() != 'FF') continue; // translucent
          if (luminance(hex) < 0.02) {
            offenders.add('${file.path}:${i + 1}  $hex');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Near-black literals are invisible on the dark canvas; use '
            'context.c.ink*:\n${offenders.join('\n')}');
  });
}
