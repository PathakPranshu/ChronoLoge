import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Theme for complete application: colors and typography

// Color Schemas for light and dark mode theme

class CustomTheme {

  // Light Mode color schemas

  static ThemeData lightThemeData(BuildContext context) {
    return ThemeData(
      textTheme: buildTextTheme(),
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xffa2391a),
        surfaceTint: Color(0xffa53b1c),
        onPrimary: Color(0xffffffff),
        primaryContainer: Color(0xffc35030),
        onPrimaryContainer: Color(0xfffffbff),
        secondary: Color(0xff50630a),
        onSecondary: Color(0xffffffff),
        secondaryContainer: Color(0xff687c25),
        onSecondaryContainer: Color(0xfffbffe4),
        tertiary: Color(0xff715c00),
        onTertiary: Color(0xffffffff),
        tertiaryContainer: Color(0xfff6E1A6),
        onTertiaryContainer: Color(0xff534619),
        error: Color(0xffba1a1a),
        onError: Color(0xffffffff),
        errorContainer: Color(0xffffdad6),
        onErrorContainer: Color(0xff93000a),
        surface: Color(0xfffff8f6),
        onSurface: Color(0xff241916),
        onSurfaceVariant: Color(0xff57423c),
        outline: Color(0xff8b716b),
        outlineVariant: Color(0xffdfc0b8),
        shadow: Color(0xff000000),
        scrim: Color(0xff000000),
        inverseSurface: Color(0xff3a2d2a),
        inversePrimary: Color(0xffffb5a0),
        primaryFixed: Color(0xffffdbd1),
        onPrimaryFixed: Color(0xff3b0900),
        primaryFixedDim: Color(0xffffb5a0),
        onPrimaryFixedVariant: Color(0xff852406),
        secondaryFixed: Color(0xffd4ed87),
        onSecondaryFixed: Color(0xff171e00),
        secondaryFixedDim: Color(0xffb9d06f),
        onSecondaryFixedVariant: Color(0xff3d4d00),
        tertiaryFixed: Color(0xffffe17a),
        onTertiaryFixed: Color(0xff231b00),
        tertiaryFixedDim: Color(0xffe4c453),
        onTertiaryFixedVariant: Color(0xff554500),
        surfaceDim: Color(0xffebd5d0),
        surfaceBright: Color(0xfffff8f6),
        surfaceContainerLowest: Color(0xffffffff),
        surfaceContainerLow: Color(0xfffff1ed),
        surfaceContainer: Color(0xffffe9e4),
        surfaceContainerHigh: Color(0xfffae3de),
        surfaceContainerHighest: Color(0xfff4ded8),
      ),
    );
  }

  // Dark Mode Color schema

  static ThemeData darkThemeData(BuildContext context) {
    return ThemeData(
      textTheme: buildTextTheme(),
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xffffb5a0),
        surfaceTint: Color(0xffffb5a0),
        onPrimary: Color(0xff601400),
        primaryContainer: Color(0xffe86b48),
        onPrimaryContainer: Color(0xff230300),
        secondary: Color(0xffb9d06f),
        onSecondary: Color(0xff293500),
        secondaryContainer: Color(0xff84993f),
        onSecondaryContainer: Color(0xff151c00),
        tertiary: Color(0xffe4c453),
        onTertiary: Color(0xff3b2f00),
        tertiaryContainer: Color(0xff534619),
        onTertiaryContainer: Color(0xffF6E1A6),
        error: Color(0xffffb4ab),
        onError: Color(0xff690005),
        errorContainer: Color(0xff93000a),
        onErrorContainer: Color(0xffffdad6),
        surface: Color(0xff1b110e),
        onSurface: Color(0xfff4ded8),
        onSurfaceVariant: Color(0xffdfc0b8),
        outline: Color(0xffa68b84),
        outlineVariant: Color(0xff57423c),
        shadow: Color(0xff000000),
        scrim: Color(0xff000000),
        inverseSurface: Color(0xfff4ded8),
        inversePrimary: Color(0xffa53b1c),
        primaryFixed: Color(0xffffdbd1),
        onPrimaryFixed: Color(0xff3b0900),
        primaryFixedDim: Color(0xffffb5a0),
        onPrimaryFixedVariant: Color(0xff852406),
        secondaryFixed: Color(0xffd4ed87),
        onSecondaryFixed: Color(0xff171e00),
        secondaryFixedDim: Color(0xffb9d06f),
        onSecondaryFixedVariant: Color(0xff3d4d00),
        tertiaryFixed: Color(0xffffe17a),
        onTertiaryFixed: Color(0xff231b00),
        tertiaryFixedDim: Color(0xffe4c453),
        onTertiaryFixedVariant: Color(0xff554500),
        surfaceDim: Color(0xff1b110e),
        surfaceBright: Color(0xff443633),
        surfaceContainerLowest: Color(0xff160c09),
        surfaceContainerLow: Color(0xff241916),
        surfaceContainer: Color(0xff291d1a),
        surfaceContainerHigh: Color(0xff342724),
        surfaceContainerHighest: Color(0xff3f322e),
      ),
    );
  }

  // Text Theme
  static TextTheme buildTextTheme() {
    return TextTheme(
      displayMedium: TextStyle(
        fontFamily: "Fraunces",
        fontWeight: FontWeight(450),
        fontVariations: [
          FontVariation.opticalSize(80),
          FontVariation('SOFT', 24),
          FontVariation("WONK", 0),
        ],
      ),
      displaySmall: TextStyle(
        fontFamily: "Fraunces",
        fontWeight: FontWeight(450),
        fontVariations: [
          FontVariation.opticalSize(76),
          FontVariation('SOFT', 30),
          FontVariation("WONK", 0),
        ],
      ),
      headlineLarge: GoogleFonts.geist(),
      headlineMedium: GoogleFonts.geist(),
      headlineSmall: GoogleFonts.geist(),
      titleLarge: GoogleFonts.geist(),
      titleMedium: GoogleFonts.geist(),
      titleSmall: GoogleFonts.geist(fontWeight: FontWeight.w500),
      labelLarge: GoogleFonts.geist(),
      labelMedium: GoogleFonts.geist(),
      labelSmall: GoogleFonts.geist(),
      bodyLarge: GoogleFonts.geist(),
      bodyMedium: GoogleFonts.geist(),
      bodySmall: GoogleFonts.geist(),
    );
  }
}
