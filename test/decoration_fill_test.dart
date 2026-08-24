import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Which branches of a decoration's condition a paint expression covers.
///
/// `condition` is null for an unconditional expression, in which case
/// [whenTrue] and [whenFalse] are both true.
class PaintCoverage {
  const PaintCoverage(this.condition, this.whenTrue, this.whenFalse);

  final String? condition;
  final bool whenTrue;
  final bool whenFalse;

  bool get coversEverything => whenTrue && whenFalse;
  bool get coversNothing => !whenTrue && !whenFalse;
}

/// Splits `expr` on its top-level ternary and reports which arms paint.
///
/// A `null` arm paints nothing. `X ? null : null` therefore covers nothing at
/// all — the shape a gradient-removal sweep left behind in several buttons.
PaintCoverage coverageOf(String expr) {
  final e = expr.trim();
  if (e.isEmpty || e == 'null') return const PaintCoverage(null, false, false);

  // Find the top-level `?` and its matching `:`.
  var depth = 0;
  var q = -1;
  for (var i = 0; i < e.length; i++) {
    final ch = e[i];
    if (ch == '(' || ch == '[' || ch == '{') depth++;
    if (ch == ')' || ch == ']' || ch == '}') depth--;
    // `??` is a null-coalesce, not a conditional.
    if (ch == '?' && depth == 0) {
      if (i + 1 < e.length && e[i + 1] == '?') {
        i++;
        continue;
      }
      q = i;
      break;
    }
  }
  if (q == -1) return PaintCoverage(null, true, true);

  depth = 0;
  var colon = -1;
  for (var i = q + 1; i < e.length; i++) {
    final ch = e[i];
    if (ch == '(' || ch == '[' || ch == '{') depth++;
    if (ch == ')' || ch == ']' || ch == '}') depth--;
    if (ch == ':' && depth == 0) {
      colon = i;
      break;
    }
  }
  if (colon == -1) return PaintCoverage(null, true, true);

  final condition = e.substring(0, q).replaceAll(RegExp(r'\s+'), '');
  final ifTrue = e.substring(q + 1, colon).trim();
  final ifFalse = e.substring(colon + 1).trim();
  return PaintCoverage(condition, ifTrue != 'null', ifFalse != 'null');
}

/// Splits a decoration body into top-level `key: value` pairs, ignoring commas
/// nested inside brackets.
Map<String, String> topLevelArgs(String body) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < body.length; i++) {
    final ch = body[i];
    if (ch == '(' || ch == '[' || ch == '{') depth++;
    if (ch == ')' || ch == ']' || ch == '}') depth--;
    if (ch == ',' && depth == 0) {
      parts.add(body.substring(start, i));
      start = i + 1;
    }
  }
  parts.add(body.substring(start));

  final args = <String, String>{};
  final keyPattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
  for (final part in parts) {
    final colon = part.indexOf(':');
    if (colon == -1) continue;
    final key = part.substring(0, colon).trim();
    if (!keyPattern.hasMatch(key)) continue;
    args[key] = part.substring(colon + 1).trim();
  }
  return args;
}

/// True when this decoration's paint keys leave no branch unpainted.
bool decorationAlwaysPaints(Iterable<String> paintExpressions) {
  final coverages = paintExpressions.map(coverageOf).toList();
  if (coverages.isEmpty) return true; // the other test's business

  // An unconditional fill settles it.
  if (coverages.any((c) => c.condition == null && c.coversEverything)) {
    return true;
  }

  // Otherwise a single condition must be fully covered between the keys that
  // share it — the legitimate "gradient when enabled, flat colour when
  // loading" split on the auth buttons.
  final byCondition = <String, List<PaintCoverage>>{};
  for (final c in coverages) {
    if (c.condition == null) continue;
    byCondition.putIfAbsent(c.condition!, () => []).add(c);
  }
  return byCondition.values.any((group) =>
      group.any((c) => c.whenTrue) && group.any((c) => c.whenFalse));
}

void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.contains('otp_screen'))
      .toList();

  test('every BoxDecoration paints in every branch', () {
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
        final args = topLevelArgs(src.substring(match.end, j - 1));
        final paints = <String>[
          for (final k in const ['color', 'gradient', 'image'])
            if (args.containsKey(k)) args[k]!,
        ];
        if (paints.isEmpty) continue;
        if (decorationAlwaysPaints(paints)) continue;

        final line = src.substring(0, match.start).split('\n').length;
        offenders.add('${file.path}:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These decorations have a branch in which nothing is painted, '
          'while their children still use onBrand — near-black on near-black:\n'
          '${offenders.join('\n')}',
    );
  });

  group('coverageOf', () {
    test('treats an unconditional colour as full coverage', () {
      final c = coverageOf('context.c.brand');
      expect(c.condition, isNull);
      expect(c.coversEverything, isTrue);
    });

    test('reads both arms of a ternary', () {
      final c = coverageOf('enabled ? c.brand : c.surfaceSunken');
      expect(c.condition, 'enabled');
      expect(c.coversEverything, isTrue);
    });

    test('spots a null arm', () {
      expect(coverageOf('_isLoading ? grey : null').whenFalse, isFalse);
      expect(coverageOf('_isLoading ? null : grey').whenTrue, isFalse);
    });

    test('spots the doubly-dead sweep leftover', () {
      expect(coverageOf('_isLoading ? null : null').coversNothing, isTrue);
    });

    test('does not mistake ?? for a ternary', () {
      final c = coverageOf('activeColor ?? context.c.brand');
      expect(c.condition, isNull);
      expect(c.coversEverything, isTrue);
    });

    test('ignores a colon nested inside a call', () {
      final c = coverageOf(
          'on ? c.brand.withValues(alpha: 0.2) : c.ink3.withValues(alpha: 0.1)');
      expect(c.condition, 'on');
      expect(c.coversEverything, isTrue);
    });
  });

  group('decorationAlwaysPaints', () {
    test('accepts a gradient/colour split on one condition', () {
      // The login and registration buttons: gradient when enabled, flat grey
      // while loading. Between them every branch is painted.
      expect(
        decorationAlwaysPaints([
          '_isLoading ? const Color(0xFFE0E0E0) : null',
          '_isLoading ? null : LinearGradient(colors: [a, b])',
        ]),
        isTrue,
      );
    });

    test('rejects the Publish-button shape', () {
      expect(
        decorationAlwaysPaints([
          '_isLoading ? const Color(0xFFE2E8F0) : null',
          '_isLoading ? null : null',
        ]),
        isFalse,
      );
    });

    test('rejects two keys nulled on the same branch', () {
      expect(
        decorationAlwaysPaints(['x ? a : null', 'x ? b : null']),
        isFalse,
      );
    });
  });
}
