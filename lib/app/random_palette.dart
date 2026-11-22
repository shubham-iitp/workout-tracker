/// Random palette generator (design canvas, "Random palette" page, spec §4.1).
///
/// Pure Dart and seedable: a straight port of the canvas's `generatePalette`,
/// so a seed gives exactly the colours the design shows (seed 7 = 7.2–7.9).
/// No network, no Flutter imports, so it can be unit-tested and used by the
/// CSV codec.
library;

import 'dart:math' as math;

/// Every colour token a palette defines, in a fixed order (used by storage
/// and the CSV `palette` row).
const paletteTokenKeys = [
  'ink',
  'dark',
  'badge',
  'ground',
  'muted',
  'line',
  'border',
  'border2',
  'divider',
  'field',
  'darkMuted',
  'darkText',
  'darkTrack',
  'darkLine',
  'checkIdle',
  'up',
  'accent',
];

const paletteSchemes = ['analogous', 'complementary', 'triad'];

/// The five swatches shown for a generated palette, and their roles.
const swatchRoles = ['ground', 'ink', 'dark', 'accent', 'badge'];

/// Names a saved palette may not use (the four presets).
const presetPaletteNames = [
  'Lime',
  'Ocean blue',
  'Gold & gunmetal',
  'Rosewood & aqua',
];

const maxPaletteNameLength = 24;

/// Attempts before giving up ("Couldn't find a readable palette").
const maxPaletteAttempts = 50;

final _hexPattern = RegExp(r'^#[0-9A-F]{6}$');

bool isPaletteHex(String v) => _hexPattern.hasMatch(v);

/// A full set of colours as `#RRGGBB` strings, keyed by [paletteTokenKeys].
class PaletteColors {
  PaletteColors(Map<String, String> colors)
    : colors = Map.unmodifiable({
        for (final k in paletteTokenKeys) k: colors[k]!.toUpperCase(),
      });

  final Map<String, String> colors;

  String operator [](String key) => colors[key]!;

  List<String> get swatches => [for (final r in swatchRoles) colors[r]!];

  @override
  bool operator ==(Object other) =>
      other is PaletteColors &&
      paletteTokenKeys.every((k) => colors[k] == other.colors[k]);

  @override
  int get hashCode => Object.hashAll(paletteTokenKeys.map((k) => colors[k]));
}

/// A palette from the generator: its colours plus how it was made.
class GeneratedPalette {
  GeneratedPalette({
    required this.scheme,
    required this.hue,
    required this.colors,
  });

  /// One of [paletteSchemes].
  final String scheme;

  /// Base hue, 0–359.
  final int hue;
  final PaletteColors colors;

  /// "Analogous · hue 4°".
  String get label =>
      '${scheme[0].toUpperCase()}${scheme.substring(1)} · hue $hue°';
}

// ---------------------------------------------------------------------------
// RNG: mulberry32, bit-exact with the canvas's JS `rng(seed)`.
// ---------------------------------------------------------------------------

const _mask = 0xFFFFFFFF;

/// 32-bit multiply, low 32 bits (JS `Math.imul`), without 64-bit overflow.
int _imul(int a, int b) {
  a &= _mask;
  b &= _mask;
  final lo = a * (b & 0xFFFF);
  final hi = ((a * (b >> 16)) & 0xFFFF) << 16;
  return (lo + hi) & _mask;
}

/// Returns a function giving numbers in [0, 1).
double Function() seededRandom(int seed) {
  var a = seed & _mask;
  return () {
    a = (a + 0x6D2B79F5) & _mask;
    var t = a;
    t = _imul(t ^ (t >> 15), t | 1);
    t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & _mask)) & _mask;
    return ((t ^ (t >> 14)) & _mask) / 4294967296;
  };
}

// ---------------------------------------------------------------------------
// Colour maths (WCAG relative luminance / contrast ratio).
// ---------------------------------------------------------------------------

String hslToHex(num h, num s, num l) {
  final hh = ((h % 360) + 360) % 360;
  final ss = s / 100, ll = l / 100;
  double k(int n) => (n + hh / 30) % 12;
  final a = ss * (ll < 1 - ll ? ll : 1 - ll);
  double f(int n) {
    final kn = k(n);
    final inner = [kn - 3, 9 - kn, 1.0].reduce((x, y) => x < y ? x : y);
    return ll - a * (inner > -1 ? inner : -1);
  }

  return '#${[f(0), f(8), f(4)].map(_byte).join()}';
}

String _byte(double x) =>
    _jsRound(x * 255).toRadixString(16).padLeft(2, '0').toUpperCase();

/// JS `Math.round`: halves go up (towards +∞).
int _jsRound(double x) => (x + 0.5).floor();

int _channel(String hex, int i) =>
    int.parse(hex.substring(1 + i * 2, 3 + i * 2), radix: 16);

double luminance(String hex) {
  double lin(int c) {
    final v = c / 255;
    return v <= 0.03928 ? v / 12.92 : _pow((v + 0.055) / 1.055, 2.4);
  }

  return 0.2126 * lin(_channel(hex, 0)) +
      0.7152 * lin(_channel(hex, 1)) +
      0.0722 * lin(_channel(hex, 2));
}

double _pow(double x, double e) => math.pow(x, e).toDouble();

double contrast(String a, String b) {
  final x = luminance(a), y = luminance(b);
  final hi = x > y ? x : y, lo = x > y ? y : x;
  return (hi + 0.05) / (lo + 0.05);
}

/// Mixes [a] towards [b] by [w] (0 = a, 1 = b).
String mixHex(String a, String b, double w) =>
    '#${[for (var i = 0; i < 3; i++) _jsRound(_channel(a, i) * (1 - w) + _channel(b, i) * w).toRadixString(16).padLeft(2, '0').toUpperCase()].join()}';

// ---------------------------------------------------------------------------
// The generator
// ---------------------------------------------------------------------------

class _Hsl {
  _Hsl(this.h, this.s, this.l) : hex = hslToHex(h, s, l);
  final num h;
  final double s;
  final double l;
  final String hex;
}

const _white = '#FFFFFF';

/// Tries up to [maxPaletteAttempts] palettes and returns the first one whose
/// text, buttons and badges are all readable (WCAG 4.5:1, accent on dark
/// 3:1). Null when none passed (very rare).
GeneratedPalette? generatePalette(double Function() rnd) {
  double r(double lo, double hi) => lo + rnd() * (hi - lo);

  for (var attempt = 0; attempt < maxPaletteAttempts; attempt++) {
    final h = (rnd() * 360).floor();
    final scheme = paletteSchemes[(rnd() * 3).floor()];
    final hues = switch (scheme) {
      'analogous' => [h, h + 30, h - 30],
      'complementary' => [h, h + 180],
      _ => [h, h + 120, h + 240],
    };
    // Same evaluation order as the JS object literals: s, then l.
    _Hsl col(num hue, double sLo, double sHi, double lLo, double lHi) {
      final s = r(sLo, sHi);
      final l = r(lLo, lHi);
      return _Hsl(hue, s, l);
    }

    final cols = [
      col(h, 20, 40, 93, 97),
      col(h, 25, 50, 8, 15),
      col(h, 25, 50, 18, 30),
      col(hues[1], 70, 95, 62, 75),
      col(hues.length > 2 ? hues[2] : h + 180, 50, 75, 30, 42),
    ];

    final byL = _stableSorted(cols, (a, b) => a.l.compareTo(b.l));
    final ink = byL[0], dark = byL[1], ground = byL[4];
    final rest = _stableSorted([byL[2], byL[3]], (a, b) => b.s.compareTo(a.s));
    final accent = rest[0], badge = rest[1];

    final muted = mixHex(ink.hex, ground.hex, 0.35);
    final line = hslToHex(ground.h, ground.s, ground.l - 4);
    final border = hslToHex(ground.h, ground.s, ground.l - 12);

    var ul = accent.l;
    var up = accent.hex;
    while (ul > 0 &&
        (contrast(up, _white) < 4.5 || contrast(up, ground.hex) < 4.5)) {
      ul -= 2;
      up = hslToHex(accent.h, accent.s, ul);
    }

    final ok =
        contrast(ink.hex, ground.hex) >= 4.5 &&
        contrast(ink.hex, _white) >= 4.5 &&
        contrast(muted, _white) >= 4.5 &&
        contrast(_white, dark.hex) >= 4.5 &&
        contrast(ink.hex, accent.hex) >= 4.5 &&
        contrast(accent.hex, dark.hex) >= 3 &&
        contrast(_white, badge.hex) >= 4.5 &&
        contrast(up, _white) >= 4.5 &&
        contrast(up, ground.hex) >= 4.5;
    if (!ok) continue;

    return GeneratedPalette(
      scheme: scheme,
      hue: h,
      colors: PaletteColors({
        'ink': ink.hex,
        'dark': dark.hex,
        'badge': badge.hex,
        'ground': ground.hex,
        'accent': accent.hex,
        'up': up,
        'muted': muted,
        'line': line,
        'border': border,
        // Derived the same way (not random).
        'border2': hslToHex(ground.h, ground.s, ground.l - 20),
        'divider': hslToHex(ground.h, ground.s, ground.l - 2),
        'field': mixHex(ground.hex, _white, 0.6),
        'darkMuted': mixHex(_white, dark.hex, 0.3),
        'darkText': mixHex(_white, dark.hex, 0.15),
        'darkTrack': mixHex(dark.hex, _white, 0.12),
        'darkLine': mixHex(dark.hex, _white, 0.2),
        'checkIdle': hslToHex(ground.h, ground.s, ground.l - 28),
      }),
    );
  }
  return null;
}

List<T> _stableSorted<T>(List<T> items, int Function(T, T) compare) {
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

// ---------------------------------------------------------------------------
// Names
// ---------------------------------------------------------------------------

/// Why [name] can't be saved, or null if it can. [name] is already trimmed.
String? paletteNameProblem(String name) {
  if (name.isEmpty) return 'Give the palette a name.';
  if (name.length > maxPaletteNameLength) {
    return 'Use $maxPaletteNameLength characters or fewer.';
  }
  if (isPresetPaletteName(name)) {
    return 'That name is used by a built-in palette. Pick another one.';
  }
  return null;
}

bool isPresetPaletteName(String name) =>
    presetPaletteNames.any((p) => p.toLowerCase() == name.trim().toLowerCase());

bool samePaletteName(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();
