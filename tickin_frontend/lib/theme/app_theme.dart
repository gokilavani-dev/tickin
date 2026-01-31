import 'package:flutter/material.dart';

class AppTheme {
  // ✅ Background / surfaces (dark blue)
  static const Color navy = Color(0xFF0B1C2D);
  static const Color darkNavy = Color(0xFF081726);
  static const Color card = Color(0xFF102A43);

  // ✅ Foreground (white)
  static const Color white = Colors.white;

  static ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: navy,

    // ✅ default text = white
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: white),
      displayMedium: TextStyle(color: white),
      displaySmall: TextStyle(color: white),
      headlineLarge: TextStyle(color: white),
      headlineMedium: TextStyle(color: white),
      headlineSmall: TextStyle(color: white),
      titleLarge: TextStyle(color: white, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: white, fontWeight: FontWeight.w700),
      titleSmall: TextStyle(color: white, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: white),
      bodyMedium: TextStyle(color: white),
      bodySmall: TextStyle(color: Colors.white70),
      labelLarge: TextStyle(color: white, fontWeight: FontWeight.w700),
      labelMedium: TextStyle(color: white),
      labelSmall: TextStyle(color: Colors.white70),
    ),

    // ✅ default icons = white
    iconTheme: const IconThemeData(color: white),

    // ✅ AppBar dark blue + white text
    appBarTheme: const AppBarTheme(
      backgroundColor: darkNavy,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: white),
    ),

    // ✅ Cards dark blue
    cardTheme: CardThemeData(
      color: card,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),

    // ✅ Buttons FULL WHITE
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: white,
        foregroundColor: darkNavy, // ✅ button text/icon dark blue
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),

    // ✅ TextButton white text
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: white,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),

    // ✅ Inputs: dark blue field + white text
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      labelStyle: const TextStyle(color: white),
      hintStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: white, width: 1.2),
      ),
    ),

    // ✅ Dividers subtle
    dividerTheme: DividerThemeData(
      color: Colors.white.withValues(alpha: 0.12),
      thickness: 1,
    ),

    // ✅ Chips dark blue + white label
    chipTheme: ChipThemeData(
      backgroundColor: card,
      labelStyle: const TextStyle(color: white, fontWeight: FontWeight.w700),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
