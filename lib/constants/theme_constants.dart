import 'package:flutter/material.dart';

/// 앱의 테마 관련 상수를 정의합니다.
class ThemeConstants {
  /// 라이트 테마 설정
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: Colors.grey.shade800,
      onPrimary: Colors.white,
      secondary: Colors.grey.shade600,
      onSecondary: Colors.white,
      surface: Colors.white,
      error: Colors.red.shade400,
      onSurface: Colors.grey.shade900,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.grey.shade900,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.grey.shade900),
      actionsIconTheme: IconThemeData(color: Colors.grey.shade900),
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey.shade800,
      ),
    ),
    iconTheme: IconThemeData(
      color: Colors.grey.shade800,
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        color: Colors.grey.shade900,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: Colors.grey.shade900,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(color: Colors.grey.shade800),
      bodyMedium: TextStyle(color: Colors.grey.shade700),
      bodySmall: TextStyle(color: Colors.grey.shade600),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade200,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      labelStyle: TextStyle(color: Colors.grey.shade700),
      hintStyle: TextStyle(color: Colors.grey.shade500),
    ),
  );

  /// 다크 테마 설정
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: Colors.grey.shade300,
      onPrimary: Colors.black,
      secondary: Colors.grey.shade400,
      onSecondary: Colors.black,
      surface: Colors.grey.shade900,
      error: Colors.red.shade300,
      onSurface: Colors.grey.shade200,
    ),
    scaffoldBackgroundColor: Colors.grey.shade900,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey.shade900,
      foregroundColor: Colors.grey.shade200,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.grey.shade200),
      actionsIconTheme: IconThemeData(color: Colors.grey.shade200),
    ),
    cardTheme: CardTheme(
      color: Colors.grey.shade800,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade300,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey.shade300,
      ),
    ),
    iconTheme: IconThemeData(
      color: Colors.grey.shade300,
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        color: Colors.grey.shade200,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: Colors.grey.shade200,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(color: Colors.grey.shade300),
      bodyMedium: TextStyle(color: Colors.grey.shade400),
      bodySmall: TextStyle(color: Colors.grey.shade500),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade700,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade800,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade600),
      ),
      labelStyle: TextStyle(color: Colors.grey.shade400),
      hintStyle: TextStyle(color: Colors.grey.shade500),
    ),
  );
}
