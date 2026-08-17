import 'dart:io';

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
        // Text and icons over photographs are legitimately white.
        if (line.contains('TextStyle') ||
            line.contains('Icon(') ||
            line.contains('withOpacity') ||
            line.contains('withValues')) {
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
}
