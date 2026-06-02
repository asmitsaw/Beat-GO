import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  // ── Light (Neobrutalism) ─────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary:   AppColors.textPrimary,
        secondary: AppColors.yellow,
        surface:   AppColors.background,
        error:     AppColors.pink,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: _buildTextTheme(AppColors.textPrimary),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color:      AppColors.textPrimary,
          fontSize:   24,
          fontWeight: FontWeight.bold,
          fontFamily: 'Space Mono',
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:      AppColors.yellow,
        selectedItemColor:    AppColors.textPrimary,
        unselectedItemColor:  Color(0xFF555555),
        selectedLabelStyle:   TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
        elevation: 0,
      ),
      dividerColor: AppColors.border,
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
      ),
    );
  }

  // ── Dark (Neobrutalism — inverted) ───────────────────────────────────────
  static ThemeData get darkTheme {
    const bgDark    = Color(0xFF111111);
    const surfDark  = Color(0xFF1C1C1C);
    const textDark  = Colors.white;
    const textSecDark = Color(0xFFAAAAAA);

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary:   textDark,
        secondary: AppColors.yellow,
        surface:   surfDark,
        error:     AppColors.pink,
        onSurface: textDark,
      ),
      textTheme: _buildTextTheme(textDark),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textDark),
        titleTextStyle: TextStyle(
          color:      textDark,
          fontSize:   24,
          fontWeight: FontWeight.bold,
          fontFamily: 'Space Mono',
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:      Color(0xFF1C1C1C),
        selectedItemColor:    AppColors.yellow,
        unselectedItemColor:  Color(0xFF777777),
        selectedLabelStyle:   TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
        elevation: 0,
      ),
      dividerColor: Colors.white24,
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: textSecDark),
      ),
    );
  }

  // ── Shared text theme builder ────────────────────────────────────────────
  static TextTheme _buildTextTheme(Color color) {
    return GoogleFonts.spaceMonoTextTheme().copyWith(
      displayLarge:  GoogleFonts.spaceMono(color: color, fontWeight: FontWeight.bold),
      displayMedium: GoogleFonts.spaceMono(color: color, fontWeight: FontWeight.bold),
      displaySmall:  GoogleFonts.spaceMono(color: color, fontWeight: FontWeight.bold),
      headlineMedium:GoogleFonts.spaceMono(color: color, fontWeight: FontWeight.w700),
      titleLarge:    GoogleFonts.spaceMono(color: color, fontWeight: FontWeight.bold),
      bodyLarge:     GoogleFonts.spaceMono(color: color),
      bodyMedium:    GoogleFonts.spaceMono(color: color),
    );
  }
}
