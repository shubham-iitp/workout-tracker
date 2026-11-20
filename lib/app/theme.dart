import 'package:material_ui/material_ui.dart';

/// The four colour palettes from the design. Screens only use [AppTokens],
/// never raw colours.
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
      accent: Color(0xFFC8F03C),
      onAccent: Color(0xFF111111),
      dark: Color(0xFF161616),
      onDark: Color(0xFFFFFFFF),
      ink: Color(0xFF111111),
      muted: Color(0xFF6B6B66),
      ground: Color(0xFFF4F4EF),
      surface: Color(0xFFFFFFFF),
      line: Color(0xFFE6E6DF),
      border: Color(0xFFD6D6CE),
      badge: Color(0xFFFF5A36),
      up: Color(0xFF2E9E44),
      danger: Color(0xFFD93025),
    ),
    AppPalette.ocean => const AppTokens(
      accent: Color(0xFF4FB3FF),
      onAccent: Color(0xFF0B1B2E),
      dark: Color(0xFF0B2545),
      onDark: Color(0xFFFFFFFF),
      ink: Color(0xFF0B1B2E),
      muted: Color(0xFF5C6B7A),
      ground: Color(0xFFF1F6FB),
      surface: Color(0xFFFFFFFF),
      line: Color(0xFFDCE6F0),
      border: Color(0xFFC9D6E3),
      badge: Color(0xFFFF6B35),
      up: Color(0xFF1F8A70),
      danger: Color(0xFFD93025),
    ),
    AppPalette.gold => const AppTokens(
      accent: Color(0xFFE6B84A),
      onAccent: Color(0xFF1C2326),
      dark: Color(0xFF2A3439),
      onDark: Color(0xFFFFFFFF),
      ink: Color(0xFF1C2326),
      muted: Color(0xFF6E7376),
      ground: Color(0xFFF6F4EE),
      surface: Color(0xFFFFFFFF),
      line: Color(0xFFE5E1D6),
      border: Color(0xFFD2CEC2),
      badge: Color(0xFFB5452F),
      up: Color(0xFF4E7D3A),
      danger: Color(0xFFC0392B),
    ),
    AppPalette.rose => const AppTokens(
      accent: Color(0xFF8EE3EF),
      onAccent: Color(0xFF142B3E),
      dark: Color(0xFF254E70),
      onDark: Color(0xFFFFFFFF),
      ink: Color(0xFF142B3E),
      muted: Color(0xFF557083),
      ground: Color(0xFFEEFBF8),
      surface: Color(0xFFFFFFFF),
      line: Color(0xFFD5EDEA),
      border: Color(0xFFBFDCD9),
      badge: Color(0xFFC33C54),
      up: Color(0xFF37718E),
      danger: Color(0xFFC33C54),
    ),
  };
}

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.accent,
    required this.onAccent,
    required this.dark,
    required this.onDark,
    required this.ink,
    required this.muted,
    required this.ground,
    required this.surface,
    required this.line,
    required this.border,
    required this.badge,
    required this.up,
    required this.danger,
  });

  /// Highlight colour: primary buttons, progress, checked items.
  final Color accent;
  final Color onAccent;

  /// Dark blocks: headers, secondary buttons.
  final Color dark;
  final Color onDark;

  /// Main text.
  final Color ink;

  /// Secondary text.
  final Color muted;

  /// Page background.
  final Color ground;

  /// Card background.
  final Color surface;

  /// Dividers.
  final Color line;

  /// Input / card outlines.
  final Color border;

  /// Count badges.
  final Color badge;

  /// "Higher than last time".
  final Color up;

  /// Errors and destructive actions.
  final Color danger;

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      dark: l(dark, other.dark),
      onDark: l(onDark, other.onDark),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      ground: l(ground, other.ground),
      surface: l(surface, other.surface),
      line: l(line, other.line),
      border: l(border, other.border),
      badge: l(badge, other.badge),
      up: l(up, other.up),
      danger: l(danger, other.danger),
    );
  }
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}

const headingFont = 'SpaceGrotesk';
const bodyFont = 'Inter';

ThemeData buildTheme(AppPalette palette) {
  final t = palette.tokens;
  final scheme = ColorScheme.light(
    primary: t.dark,
    onPrimary: t.onDark,
    secondary: t.accent,
    onSecondary: t.onAccent,
    surface: t.surface,
    onSurface: t.ink,
    error: t.danger,
    outline: t.border,
    outlineVariant: t.line,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: bodyFont,
    scaffoldBackgroundColor: t.ground,
    extensions: [t],
  );
  TextStyle? h(TextStyle? s) => s?.copyWith(
    fontFamily: headingFont,
    fontWeight: FontWeight.w700,
    color: t.ink,
  );
  final text = base.textTheme;

  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  return base.copyWith(
    textTheme: text.copyWith(
      displaySmall: h(text.displaySmall),
      headlineLarge: h(text.headlineLarge),
      headlineMedium: h(text.headlineMedium),
      headlineSmall: h(text.headlineSmall),
      titleLarge: h(text.titleLarge),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.ground,
      foregroundColor: t.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: headingFont,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: t.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: t.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: t.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        disabledBackgroundColor: t.line,
        disabledForegroundColor: t.muted,
        minimumSize: const Size(0, 48),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.ink,
        side: BorderSide(color: t.border),
        minimumSize: const Size(0, 48),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: t.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: t.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: t.dark, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.surface,
      indicatorColor: t.accent,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.ink),
      ),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: t.ink)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.surface,
      showDragHandle: true,
    ),
    dividerTheme: DividerThemeData(color: t.line, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.dark,
      contentTextStyle: TextStyle(color: t.onDark),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
