import 'package:flutter/material.dart';

class AppTheme {
  // Primary brand color
  static const Color brandBlue = Color(0xFF1565C0);
  static const double radius = 14.0;

  static ThemeData buildTheme(ThemeData base) {
    // Build a color scheme explicitly based on the provided base ThemeData
    final isDark = base.brightness == Brightness.dark;
    final baseScheme = isDark ? ColorScheme.dark() : ColorScheme.light();
    final colorScheme = baseScheme.copyWith(
      primary: brandBlue,
      secondary: const Color(0xFF2E3A59),
      surface: Colors.white,
    );

    final resultBase = ThemeData.from(colorScheme: colorScheme);

    return resultBase.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: brandBlue,
        unselectedItemColor: Color(0xFF9E9E9E),
        showUnselectedLabels: true,
        selectedIconTheme: IconThemeData(size: 22),
        unselectedIconTheme: IconThemeData(size: 20),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandBlue, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(color: Colors.black87),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
        space: 20,
      ),
      cardColor: Colors.white,
    );
  }
}
