import 'package:flutter/material.dart';

class AppTheme {
  // CRED NeoPOP Color Palette - 100% Authentic (2026)
  // Based on official CRED design system
  
  // Background Layers (Charcoal Dark)
  static const Color credPureBackground = Color(0xFF0D0D0D); // Deepest base layer
  static const Color credSurfaceCard = Color(0xFF0F0F0F); // Slightly lighter for floating elements
  
  // Text Colors
  static const Color credPopWhite = Color(0xFFF8F8F8); // Primary text and bright buttons
  
  // Brand Accents
  static const Color credOrangeSunshine = Color(0xFFFF8744); // Primary brand accent (Buttons/Highlights)
  static const Color credNeonGreen = Color(0xFFE5FE40); // Success states and "Cash" highlights
  static const Color credNeoPaccha = credNeonGreen; // Alias for backward compatibility
  static const Color credPinkPong = Color(0xFFFF426F); // Rewards and "Exclusive" sections
  
  // Supporting colors for depth
  static const Color credDarkGray = Color(0xFF1A1A1A);
  static const Color credMediumGray = Color(0xFF2A2A2A);
  static const Color credLightGray = Color(0xFF3A3A3A);
  static const Color credTextSecondary = Color(0xFFB0B0B0);
  static const Color credTextTertiary = Color(0xFF808080);
  static const Color credError = Color(0xFFFF3B5C);
  static const Color credRed = credError; // Alias for backward compatibility
  
  // Legacy colors for backward compatibility
  static const Color credBlack = credPureBackground;
  static const Color credCharcoalBlack = credPureBackground;
  static const Color credGray = credSurfaceCard;
  static const Color credWhite = credPopWhite;
  static const Color credTextPrimary = credPopWhite;
  static const Color primaryGreen = credNeonGreen;
  static const Color backgroundColor = credPureBackground;
  static const Color textDark = credPopWhite;
  static const Color textLight = credTextSecondary;
  static const Color white = credPopWhite;
  static const Color grey = credTextTertiary;
  static const Color lightGrey = credMediumGray;
  static const Color red = credError;
  static const Color lightRed = Color(0xFFFF6B8A);
  static const Color credGreen = credNeonGreen;
  static const Color credOrange = credOrangeSunshine;
  static const Color credPurple = credOrangeSunshine; // Use orange as primary
  static const Color credPurpleLight = Color(0xFFFFA366);
  static const Color credPurpleDark = Color(0xFFE66A00);
  static const Color credBlue = Color(0xFF007AFF);
  static const Color darkGreen = credNeonGreen; // Legacy alias
  
  // CRED NeoPOP Gradients
  static const LinearGradient credOrangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [credOrangeSunshine, Color(0xFFE66A00)],
  );
  
  static const LinearGradient credNeonGreenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [credNeonGreen, Color(0xFFB8D600)],
  );
  
  static const LinearGradient credPinkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [credPinkPong, Color(0xFFCC1A4F)],
  );
  
  static const LinearGradient credCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [credSurfaceCard, credPureBackground],
  );
  
  static const LinearGradient credCharcoalGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [credPureBackground, credSurfaceCard],
  );
  
  // Legacy gradient for backward compatibility
  static const LinearGradient credPurpleGradient = credOrangeGradient;
  static const LinearGradient credBlackGradient = credCharcoalGradient;
  static const LinearGradient credOrangeSunshineGradient = credOrangeGradient;
  
  // NeoPOP Hard Shadow (45-degree, 8dp depth)
  static List<BoxShadow> neopopHardShadow({
    Color? shadowColor,
    double depth = 8.0,
    bool isPressed = false,
  }) {
    final color = shadowColor ?? Colors.black.withOpacity(0.5);
    if (isPressed) {
      // Inset shadow when pressed
      return [
        BoxShadow(
          color: Colors.white.withOpacity(0.05),
          offset: const Offset(2, 2),
        ),
        BoxShadow(
          color: color,
          offset: const Offset(-2, -2),
        ),
      ];
    }
    // Extruded shadow (popping out)
    return [
      BoxShadow(
        color: color,
        offset: Offset(depth, depth), // 45-degree hard shadow
      ),
      BoxShadow(
        color: Colors.white.withOpacity(0.05),
        offset: Offset(-depth * 0.5, -depth * 0.5),
      ),
    ];
  }
  
  // 8px Grid System Helper
  static double grid(double multiplier) => multiplier * 8.0;
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: credOrangeSunshine,
      scaffoldBackgroundColor: credPureBackground,
      fontFamily: 'Inter', // Fallback if Gilroy not available
      appBarTheme: const AppBarTheme(
        backgroundColor: credPureBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: credPopWhite),
        titleTextStyle: TextStyle(
          color: credPopWhite,
          fontSize: 20,
          fontWeight: FontWeight.w900, // ExtraBold
          letterSpacing: -0.5,
          fontFamily: 'Inter',
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: credPopWhite,
          fontSize: 34,
          fontWeight: FontWeight.w900, // ExtraBold
          letterSpacing: -1,
          fontFamily: 'Inter',
        ),
        displayMedium: TextStyle(
          color: credPopWhite,
          fontSize: 28,
          fontWeight: FontWeight.w900, // ExtraBold
          letterSpacing: -0.5,
          fontFamily: 'Inter',
        ),
        displaySmall: TextStyle(
          color: credPopWhite,
          fontSize: 24,
          fontWeight: FontWeight.w900, // ExtraBold
          letterSpacing: -0.5,
          fontFamily: 'Inter',
        ),
        headlineMedium: TextStyle(
          color: credPopWhite,
          fontSize: 20,
          fontWeight: FontWeight.w900, // ExtraBold
          letterSpacing: -0.5,
          fontFamily: 'Inter',
        ),
        titleLarge: TextStyle(
          color: credPopWhite,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          fontFamily: 'Inter',
        ),
        titleMedium: TextStyle(
          color: credPopWhite,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          fontFamily: 'Inter',
        ),
        bodyLarge: TextStyle(
          color: credTextSecondary,
          fontSize: 16,
          fontWeight: FontWeight.w500, // Medium
          letterSpacing: 0,
          fontFamily: 'Inter',
        ),
        bodyMedium: TextStyle(
          color: credTextSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500, // Medium
          letterSpacing: 0,
          fontFamily: 'Inter',
        ),
        bodySmall: TextStyle(
          color: credTextTertiary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          fontFamily: 'Inter',
        ),
        labelLarge: TextStyle(
          color: credPopWhite,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
        labelMedium: TextStyle(
          color: credTextSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        ),
        labelSmall: TextStyle(
          color: credTextTertiary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        ),
      ),
      cardTheme: CardThemeData(
        color: credSurfaceCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(grid(2.5)), // 20px (8px grid)
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: credOrangeSunshine,
          foregroundColor: credPureBackground,
          padding: EdgeInsets.symmetric(
            horizontal: grid(4), // 32px
            vertical: grid(2.25), // 18px
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(grid(2)), // 16px
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900, // ExtraBold
            letterSpacing: 0.5,
            fontFamily: 'Inter',
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: credOrangeSunshine,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: credSurfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(grid(2)), // 16px
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(grid(2)), // 16px
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(grid(2)), // 16px
          borderSide: const BorderSide(color: credOrangeSunshine, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: grid(2.5), // 20px
          vertical: grid(2.25), // 18px
        ),
        hintStyle: const TextStyle(
          color: credTextTertiary,
          fontSize: 16,
          fontFamily: 'Inter',
        ),
        labelStyle: const TextStyle(
          color: credTextSecondary,
          fontSize: 14,
          fontFamily: 'Inter',
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: credMediumGray,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: credSurfaceCard,
        selectedItemColor: credOrangeSunshine,
        unselectedItemColor: credTextTertiary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w900, // ExtraBold
          fontFamily: 'Inter',
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w400,
          fontFamily: 'Inter',
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: credSurfaceCard,
        contentTextStyle: const TextStyle(
          color: credPopWhite,
          fontSize: 14,
          fontFamily: 'Inter',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(grid(1.5)), // 12px
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: credSurfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(grid(3)), // 24px
        ),
        titleTextStyle: const TextStyle(
          color: credPopWhite,
          fontSize: 20,
          fontWeight: FontWeight.w900, // ExtraBold
          fontFamily: 'Inter',
        ),
        contentTextStyle: const TextStyle(
          color: credTextSecondary,
          fontSize: 16,
          fontFamily: 'Inter',
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: credOrangeSunshine,
        secondary: credNeonGreen,
        tertiary: credPinkPong,
        surface: credSurfaceCard,
        error: credError,
        onPrimary: credPureBackground,
        onSecondary: credPureBackground,
        onTertiary: credPopWhite,
        onSurface: credPopWhite,
        onError: credPopWhite,
      ),
    );
  }
  
  // Legacy theme getter for backward compatibility
  static ThemeData get theme => lightTheme;
}
