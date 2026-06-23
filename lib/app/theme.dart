import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF06B6D4);
  static const accentDark = Color(0xFF22D3EE);
  static const accentLight = Color(0xFF0891B2);
  static const bgLight = Color(0xFFF8FAFC);
  static const bgDark = Color(0xFF020617);
  static const panelLight = Color(0xEFFFFFFF);
  static const panelDark = Color(0xCC0F172A);
  static const borderLight = Color(0xFFE2E8F0);
  static const borderDark = Color(0xCC1E293B);
  static const textLight = Color(0xFF0F172A);
  static const textDark = Color(0xFFF8FAFC);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate700 = Color(0xFF334155);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  static ThemeData light() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      surface: panelLight,
      surfaceContainerHighest: const Color(0xFFEFF6F8),
      outline: borderLight,
    ),
    scaffoldBackgroundColor: bgLight,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: textLight,
      titleTextStyle: TextStyle(
        color: textLight,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: panelLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: borderLight),
      ),
    ),
    dividerTheme: const DividerThemeData(color: borderLight, thickness: 1),
    navigationBarTheme: _navigationBarTheme(Brightness.light),
    navigationRailTheme: _navigationRailTheme(Brightness.light),
    chipTheme: _chipTheme(Brightness.light),
    switchTheme: _switchTheme(),
    sliderTheme: _sliderTheme(),
    elevatedButtonTheme: _elevatedButtonTheme(),
    outlinedButtonTheme: _outlinedButtonTheme(),
    textButtonTheme: _textButtonTheme(),
    inputDecorationTheme: _inputDecorationTheme(Brightness.light),
    textTheme: _textTheme(Brightness.light),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      surface: panelDark,
      surfaceContainerHighest: const Color(0xFF0F172A),
      outline: borderDark,
      error: danger,
    ),
    scaffoldBackgroundColor: bgDark,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: textDark,
      titleTextStyle: TextStyle(
        color: textDark,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: panelDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: borderDark),
      ),
    ),
    dividerTheme: const DividerThemeData(color: borderDark, thickness: 1),
    navigationBarTheme: _navigationBarTheme(Brightness.dark),
    navigationRailTheme: _navigationRailTheme(Brightness.dark),
    chipTheme: _chipTheme(Brightness.dark),
    switchTheme: _switchTheme(),
    sliderTheme: _sliderTheme(),
    elevatedButtonTheme: _elevatedButtonTheme(),
    outlinedButtonTheme: _outlinedButtonTheme(),
    textButtonTheme: _textButtonTheme(),
    inputDecorationTheme: _inputDecorationTheme(Brightness.dark),
    textTheme: _textTheme(Brightness.dark),
  );

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color panelColor(BuildContext context) =>
      isDark(context) ? panelDark : panelLight;

  static Color borderColor(BuildContext context) =>
      isDark(context) ? borderDark : borderLight;

  static Color mutedText(BuildContext context) =>
      isDark(context) ? slate400 : slate500;

  static Color subtleFill(BuildContext context) =>
      isDark(context) ? const Color(0xFF0B1220) : const Color(0xFFF1F5F9);

  static TextTheme _textTheme(Brightness brightness) {
    final color = brightness == Brightness.dark ? textDark : textLight;
    final muted = brightness == Brightness.dark ? slate400 : slate500;
    return TextTheme(
      titleLarge: TextStyle(
        color: color,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
      titleMedium: TextStyle(color: color, fontWeight: FontWeight.w700),
      titleSmall: TextStyle(
        color: muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
      ),
      bodyMedium: TextStyle(color: color),
      bodySmall: TextStyle(color: muted),
      labelMedium: TextStyle(
        color: muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final fill = dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final border = dark ? const Color(0xFF334155) : borderLight;
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryColor, width: 1.4),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  static NavigationBarThemeData _navigationBarTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: dark ? const Color(0xEE020617) : const Color(0xEEF8FAFC),
      indicatorColor: primaryColor.withValues(alpha: 0.16),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? primaryColor : (dark ? slate400 : slate500),
          size: 22,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? primaryColor : (dark ? slate400 : slate500),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        );
      }),
    );
  }

  static NavigationRailThemeData _navigationRailTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return NavigationRailThemeData(
      backgroundColor: dark ? const Color(0xDD020617) : const Color(0xDDF8FAFC),
      indicatorColor: primaryColor.withValues(alpha: 0.16),
      selectedIconTheme: const IconThemeData(color: primaryColor),
      selectedLabelTextStyle: const TextStyle(
        color: primaryColor,
        fontWeight: FontWeight.w700,
      ),
      unselectedIconTheme: IconThemeData(color: dark ? slate400 : slate500),
      unselectedLabelTextStyle: TextStyle(color: dark ? slate400 : slate500),
    );
  }

  static ChipThemeData _chipTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ChipThemeData(
      backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      selectedColor: primaryColor.withValues(alpha: 0.16),
      side: BorderSide(color: dark ? borderDark : borderLight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: TextStyle(
        color: dark ? slate400 : slate500,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  static SwitchThemeData _switchTheme() => SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.selected) ? primaryColor : slate400,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? primaryColor.withValues(alpha: 0.22)
          : slate700.withValues(alpha: 0.22),
    ),
    trackOutlineColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? primaryColor.withValues(alpha: 0.55)
          : slate500.withValues(alpha: 0.35),
    ),
  );

  static SliderThemeData _sliderTheme() => SliderThemeData(
    activeTrackColor: primaryColor,
    inactiveTrackColor: slate500.withValues(alpha: 0.22),
    thumbColor: primaryColor,
    overlayColor: primaryColor.withValues(alpha: 0.14),
    trackHeight: 3,
  );

  static ElevatedButtonThemeData _elevatedButtonTheme() =>
      ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? slate500.withValues(alpha: 0.18)
                : primaryColor.withValues(alpha: 0.16),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ? slate500 : primaryColor,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? slate500.withValues(alpha: 0.2)
                  : primaryColor.withValues(alpha: 0.42),
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
          ),
        ),
      );

  static OutlinedButtonThemeData _outlinedButtonTheme() =>
      OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(primaryColor),
          side: WidgetStatePropertyAll(
            BorderSide(color: primaryColor.withValues(alpha: 0.36)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );

  static TextButtonThemeData _textButtonTheme() => TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: const WidgetStatePropertyAll(primaryColor),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}
