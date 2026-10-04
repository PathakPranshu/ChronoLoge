import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData light(Color accentColor) {
    return _build(accentColor, Brightness.light);
  }

  static ThemeData dark(Color accentColor) {
    return _build(accentColor, Brightness.dark);
  }

  static ThemeData _build(Color accentColor, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final seededScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
      contrastLevel: 0.05,
    );
    final colorScheme = seededScheme.copyWith(
      surface: isDark ? Colors.black : Colors.white,
      surfaceDim: isDark ? const Color(0xff0a0a0a) : const Color(0xffdedede),
      surfaceBright: isDark ? const Color(0xff242424) : Colors.white,
      surfaceContainerLowest: isDark ? Colors.black : Colors.white,
      surfaceContainerLow: isDark
          ? const Color(0xff101010)
          : const Color(0xfff8f8f8),
      surfaceContainer: isDark
          ? const Color(0xff171717)
          : const Color(0xfff2f2f2),
      surfaceContainerHigh: isDark
          ? const Color(0xff202020)
          : const Color(0xffeaeaea),
      surfaceContainerHighest: isDark
          ? const Color(0xff2a2a2a)
          : const Color(0xffe2e2e2),
      onSurface: isDark ? Colors.white : Colors.black,
      onSurfaceVariant: isDark
          ? const Color(0xffc8c8c8)
          : const Color(0xff4d4d4d),
      outline: isDark ? const Color(0xff8a8a8a) : const Color(0xff747474),
      outlineVariant: isDark
          ? const Color(0xff3a3a3a)
          : const Color(0xffd2d2d2),
      inverseSurface: isDark ? Colors.white : Colors.black,
      onInverseSurface: isDark ? Colors.black : Colors.white,
    );
    final baseTheme = ThemeData.from(
      colorScheme: colorScheme,
      useMaterial3: true,
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: colorScheme.primaryContainer,
        elevation: 0,
        height: 72,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return baseTheme.textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(
          colorScheme.surfaceContainerHigh,
        ),
        elevation: const WidgetStatePropertyAll(0),
        hintStyle: WidgetStatePropertyAll(
          baseTheme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainer,
        selectedColor: colorScheme.secondaryContainer,
        side: BorderSide(color: colorScheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
