import 'package:material_ui/material_ui.dart';

/// The four colour palettes from the design canvas ("Workout Tracker",
/// MainThemed artboard). Screens only use [AppTokens], never raw colours.
enum AppPalette {
  lime('Lime'),
  ocean('Ocean blue'),
  gold('Gold & gunmetal'),
  rose('Rosewood & aqua');

  const AppPalette(this.label);
  final String label;

  static AppPalette fromName(String? name) => AppPalette.values.firstWhere(
    (p) => p.name == name,
    orElse: () => AppPalette.lime,
  );

  AppTokens get tokens => switch (this) {
    AppPalette.lime => const AppTokens(
      ink: Color(0xFF15171C),
      dark: Color(0xFF15171C),
      badge: Color(0xFF15171C),
      ground: Color(0xFFF3F3EE),
      muted: Color(0xFF5B606B),
      line: Color(0xFFE2E2DA),
      border: Color(0xFFD4D4CA),
      border2: Color(0xFFC9C9BE),
      divider: Color(0xFFEDEDE6),
      field: Color(0xFFFAFAF7),
      darkMuted: Color(0xFFA9ADB5),
      darkText: Color(0xFFD6D8DC),
      darkTrack: Color(0xFF2C2F36),
      darkLine: Color(0xFF3A3D45),
      checkIdle: Color(0xFFB5B5AA),
      up: Color(0xFF3F6B00),
      accent: Color(0xFFC8F03C),
      swatches: [
        Color(0xFFC8F03C),
        Color(0xFF15171C),
        Color(0xFF5B606B),
        Color(0xFFE2E2DA),
        Color(0xFFF3F3EE),
      ],
    ),
    AppPalette.ocean => const AppTokens(
      ink: Color(0xFF051923),
      dark: Color(0xFF003554),
      badge: Color(0xFF003554),
      ground: Color(0xFFEAF3F9),
      muted: Color(0xFF3D5A6C),
      line: Color(0xFFD5E3EC),
      border: Color(0xFFC3D6E2),
      border2: Color(0xFFA9C3D3),
      divider: Color(0xFFE3EDF3),
      field: Color(0xFFF6FAFC),
      darkMuted: Color(0xFF8FB3C8),
      darkText: Color(0xFFC9DCE8),
      darkTrack: Color(0xFF0A4A6E),
      darkLine: Color(0xFF1B5778),
      checkIdle: Color(0xFF8FAABB),
      up: Color(0xFF006494),
      accent: Color(0xFF00A6FB),
      swatches: [
        Color(0xFF00A6FB),
        Color(0xFF0582CA),
        Color(0xFF006494),
        Color(0xFF003554),
        Color(0xFF051923),
      ],
    ),
    AppPalette.gold => const AppTokens(
      ink: Color(0xFF1E2019),
      dark: Color(0xFF393E41),
      badge: Color(0xFF587B7F),
      ground: Color(0xFFEEECE8),
      muted: Color(0xFF4E5356),
      line: Color(0xFFD3D0CB),
      border: Color(0xFFC4C0B9),
      border2: Color(0xFFB3AFA7),
      divider: Color(0xFFE4E1DC),
      field: Color(0xFFF8F7F5),
      darkMuted: Color(0xFFC9C6C1),
      darkText: Color(0xFFE3E1DD),
      darkTrack: Color(0xFF4C5256),
      darkLine: Color(0xFF5A6064),
      checkIdle: Color(0xFF9E9A92),
      up: Color(0xFF476468),
      accent: Color(0xFFE2C044),
      swatches: [
        Color(0xFFE2C044),
        Color(0xFF393E41),
        Color(0xFF587B7F),
        Color(0xFFD3D0CB),
        Color(0xFF1E2019),
      ],
    ),
    AppPalette.rose => const AppTokens(
      ink: Color(0xFF142B3E),
      dark: Color(0xFF254E70),
      badge: Color(0xFFC33C54),
      ground: Color(0xFFEEFBF8),
      muted: Color(0xFF44606F),
      line: Color(0xFFD3E9E6),
      border: Color(0xFFBFDCD8),
      border2: Color(0xFFA3C9C5),
      divider: Color(0xFFE2F3F0),
      field: Color(0xFFF7FDFC),
      darkMuted: Color(0xFFB6CFDF),
      darkText: Color(0xFFD9E8F1),
      darkTrack: Color(0xFF33628A),
      darkLine: Color(0xFF3E6C92),
      checkIdle: Color(0xFF93B5B2),
      up: Color(0xFF37718E),
      accent: Color(0xFF8EE3EF),
      swatches: [
        Color(0xFFC33C54),
        Color(0xFF254E70),
        Color(0xFF37718E),
        Color(0xFF8EE3EF),
        Color(0xFFAEF3E7),
      ],
    ),
  };
}

/// Colours shared by every palette.
abstract final class Fixed {
  static const white = Color(0xFFFFFFFF);
  static const scrim = Color(0x8C15171C); // rgba(21,23,28,.55)
  static const dangerText = Color(0xFFB42318);
  static const dangerBorder = Color(0xFFF1C4BE);
  static const dangerBg = Color(0xFFFDF0EE);
  static const dangerTitle = Color(0xFF8A1C12);
}

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.ink,
    required this.dark,
    required this.badge,
    required this.ground,
    required this.muted,
    required this.line,
    required this.border,
    required this.border2,
    required this.divider,
    required this.field,
    required this.darkMuted,
    required this.darkText,
    required this.darkTrack,
    required this.darkLine,
    required this.checkIdle,
    required this.up,
    required this.accent,
    required this.swatches,
  });

  final Color ink;
  final Color dark;
  final Color badge;
  final Color ground;
  final Color muted;
  final Color line;
  final Color border;
  final Color border2;
  final Color divider;
  final Color field;
  final Color darkMuted;
  final Color darkText;
  final Color darkTrack;
  final Color darkLine;
  final Color checkIdle;
  final Color up;
  final Color accent;
  final List<Color> swatches;

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(AppTokens? other, double t) =>
      (other == null || t < 0.5) ? this : other;
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}

const headingFont = 'SpaceGrotesk';
const bodyFont = 'Inter';

/// Space Grotesk heading style.
TextStyle grotesk(
  double size, {
  FontWeight weight = FontWeight.w700,
  Color? color,
  double? letterSpacing,
  double? height,
  TextDecoration? decoration,
}) => TextStyle(
  fontFamily: headingFont,
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing == null ? null : letterSpacing * size,
  height: height,
  decoration: decoration,
);

/// Inter body style.
TextStyle inter(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? letterSpacing,
  double? height,
  TextDecoration? decoration,
}) => TextStyle(
  fontFamily: bodyFont,
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing == null ? null : letterSpacing * size,
  height: height,
  decoration: decoration,
);

ThemeData buildTheme(AppPalette palette) {
  final t = palette.tokens;
  return ThemeData(
    useMaterial3: true,
    fontFamily: bodyFont,
    scaffoldBackgroundColor: t.ground,
    colorScheme: ColorScheme.light(
      primary: t.dark,
      onPrimary: Fixed.white,
      secondary: t.accent,
      onSecondary: t.ink,
      surface: Fixed.white,
      onSurface: t.ink,
      error: Fixed.dangerText,
      outline: t.border,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.ink,
      selectionColor: t.accent.withValues(alpha: 0.5),
      selectionHandleColor: t.ink,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.dark,
      contentTextStyle: inter(14, color: Fixed.white),
      behavior: SnackBarBehavior.floating,
    ),
    extensions: [t],
  );
}
