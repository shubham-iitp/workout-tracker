import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app/random_palette.dart';

void main() {
  // Produced by the design canvas's own JS generator (MainThemed artboard)
  // for these seeds, so the app shows exactly the design's colours.
  final reference = (jsonDecode(
    File('test/fixtures/random_palettes.json').readAsStringSync(),
  ) as Map).cast<String, dynamic>();

  test('matches the design generator bit for bit', () {
    for (final MapEntry(key: seed, value: expected) in reference.entries) {
      final p = generatePalette(seededRandom(int.parse(seed)))!;
      final e = (expected as Map).cast<String, dynamic>();
      expect(p.scheme, e['scheme'], reason: 'seed $seed scheme');
      expect(p.hue, e['hue'], reason: 'seed $seed hue');
      for (final k in paletteTokenKeys) {
        expect(p.colors[k], e[k], reason: 'seed $seed $k');
      }
    }
  });

  test('seed 7 is the design\'s "Analogous · hue 4°"', () {
    final p = generatePalette(seededRandom(7))!;
    expect(p.label, 'Analogous · hue 4°');
    expect(p.colors.swatches, hasLength(5));
  });

  test('every generated palette is readable', () {
    const white = '#FFFFFF';
    for (var seed = 0; seed < 500; seed++) {
      final p = generatePalette(seededRandom(seed));
      if (p == null) continue;
      final c = p.colors;
      expect(contrast(c['ink'], c['ground']), greaterThanOrEqualTo(4.5));
      expect(contrast(c['ink'], white), greaterThanOrEqualTo(4.5));
      expect(contrast(c['muted'], white), greaterThanOrEqualTo(4.5));
      expect(contrast(white, c['dark']), greaterThanOrEqualTo(4.5));
      expect(contrast(c['ink'], c['accent']), greaterThanOrEqualTo(4.5));
      expect(contrast(c['accent'], c['dark']), greaterThanOrEqualTo(3));
      expect(contrast(white, c['badge']), greaterThanOrEqualTo(4.5));
      expect(contrast(c['up'], white), greaterThanOrEqualTo(4.5));
      expect(contrast(c['up'], c['ground']), greaterThanOrEqualTo(4.5));
      for (final k in paletteTokenKeys) {
        expect(isPaletteHex(c[k]), isTrue, reason: 'seed $seed $k');
      }
    }
  });

  test('gives up after 50 unreadable attempts', () {
    // A "random" source stuck at 0.5 makes every attempt identical; whether
    // it passes or not, the generator must stop rather than loop forever.
    var calls = 0;
    generatePalette(() {
      calls++;
      return 0.5;
    });
    expect(calls, lessThanOrEqualTo(maxPaletteAttempts * 12));
  });

  test('names', () {
    expect(paletteNameProblem(''), isNotNull);
    expect(paletteNameProblem('lime'), contains('built-in'));
    expect(paletteNameProblem('Ocean Blue'), contains('built-in'));
    expect(paletteNameProblem('x' * 25), isNotNull);
    expect(paletteNameProblem('Sunset'), isNull);
    expect(samePaletteName('Sunset', ' sunset '), isTrue);
  });
}
