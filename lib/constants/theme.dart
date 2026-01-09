import 'package:flutter/material.dart';

class AppTheme {
  // CRED Color Palette - Pure Black Theme
  static const Color credBlack = Color(0xFF000000);
  static const Color credDarkGray = Color(0xFF0A0A0A);
  static const Color credGray = Color(0xFF1A1A1A);
  static const Color credLightGray = Color(0xFF2A2A2A);
  static const Color credPurple = Color(0xFF7B2CBF);
  static const Color credPurpleLight = Color(0xFF9D4EDD);
  static const Color credPurpleDark = Color(0xFF5A189A);
  static const Color credWhite = Color(0xFFFFFFFF);
  static const Color credTextPrimary = Color(0xFFFFFFFF);
  static const Color credTextSecondary = Color(0xFFB0B0B0);
  static const Color credTextTertiary = Color(0xFF808080);
  static const Color credGreen = Color(0xFF00D4AA);
  static const Color credRed = Color(0xFFFF3B5C);
  static const Color credOrange = Color(0xFFFF9500);
  static const Color credBlue = Color(0xFF007AFF);
  
  // Legacy colors for backward compatibility
  static const Color primaryGreen = credPurple;
  static const Color darkGreen = credPurpleDark;
  static const Color lightGreen = credPurpleLight;
  static const Color backgroundColor = credBlack;
  static const Color textDark = credTextPrimary;
  static const Color textLight = credTextSecondary;
  static const Color white = credWhite;
  static const Color grey = credTextTertiary;
  static const Color lightGrey = credLightGray;
  static const Color red = credRed;
  static const Color lightRed = Color(0xFFFF6B8A);
  static const Color blue = credBlue;
  
  // CRED Gradients
  static const LinearGradient credPurpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [credPurple, credPurpleDark],
  );
  
  static const LinearGradient credCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [credGray, credDarkGray],
  );
  
  static const LinearGradient credBlackGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [credBlack, credDarkGray],
  );
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: credPurple,
      scaffoldBackgroundColor: credBlack,
      appBarTheme: const AppBarTheme(
        backgroundColor: credBlack,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: credTextPrimary),
        titleTextStyle: TextStyle(
          color: credTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: credTextPrimary,
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        displayMedium: TextStyle(
          color: credTextPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          color: credTextPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: credTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: credTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(
          color: credTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        bodyLarge: TextStyle(
          color: credTextSecondary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        bodyMedium: TextStyle(
          color: credTextSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        bodySmall: TextStyle(
          color: credTextTertiary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        labelLarge: TextStyle(
          color: credTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(
          color: credTextSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: TextStyle(
          color: credTextTertiary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: credGray,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: credPurple,
          foregroundColor: credWhite,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: credPurple,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: credGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: credPurple, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: const TextStyle(
          color: credTextTertiary,
          fontSize: 16,
        ),
        labelStyle: const TextStyle(
          color: credTextSecondary,
          fontSize: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: credLightGray,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: credGray,
        selectedItemColor: credPurple,
        unselectedItemColor: credTextTertiary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: credGray,
        contentTextStyle: const TextStyle(
          color: credTextPrimary,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: credGray,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: const TextStyle(
          color: credTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color: credTextSecondary,
          fontSize: 16,
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: credPurple,
        secondary: credPurpleLight,
        surface: credGray,
        background: credBlack,
        error: credRed,
        onPrimary: credWhite,
        onSecondary: credWhite,
        onSurface: credTextPrimary,
        onBackground: credTextPrimary,
        onError: credWhite,
      ),
    );
  }
  
  // Legacy theme getter for backward compatibility
  static ThemeData get theme => lightTheme;
}
