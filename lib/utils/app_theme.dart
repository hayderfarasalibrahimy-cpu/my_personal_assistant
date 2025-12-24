import 'package:flutter/material.dart';
import '../services/font_service.dart';

enum AppThemeMode { dark, amoled }

class AppTheme {
  static const Color darkPrimary = Color(0xFFBB86FC);
  static const Color darkSecondary = Color(0xFF03DAC6);

  static const Color priorityLow = Color(0xFF4CAF50);
  static const Color priorityMedium = Color(0xFFFFC107);
  static const Color priorityHigh = Color(0xFFFF5722);
  static const Color priorityCritical = Color(0xFFF44336);

  static ThemeData getTheme(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return _darkTheme();
      case AppThemeMode.amoled:
        return _amoledTheme();
    }
  }

  static ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: darkPrimary,
        secondary: darkSecondary,
        surface: const Color(0xFF1E1E1E),
        surfaceContainerLow: const Color(0xFF252525),
        surfaceContainer: const Color(0xFF2C2C2C),
        surfaceContainerHigh: const Color(0xFF333333),
        outlineVariant: const Color(0xFF404040),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF252525),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFF404040).withValues(alpha: 0.85),
            width: 1.2,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: const Color(0xFF404040).withValues(alpha: 0.8),
            width: 1,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: Color(0xFF404040), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF252525),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF404040), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF404040), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: darkPrimary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: const Color(0xFF404040).withValues(alpha: 0.5),
        thickness: 0.8,
        space: 1,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: darkPrimary,
        selectionColor: darkPrimary.withValues(alpha: 0.3),
        selectionHandleColor: darkPrimary,
      ),
      textTheme: FontService.getTextTheme(ThemeData.dark().textTheme),
    );
  }

  static ThemeData _amoledTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        secondary: darkSecondary,
        surface: Color(0xFF000000),
        surfaceContainerLow: Color(0xFF0A0A0A),
        surfaceContainer: Color(0xFF121212),
        surfaceContainerHigh: Color(0xFF1A1A1A),
        outlineVariant: Color(0xFF333333),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF121212),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFF333333).withValues(alpha: 0.95),
            width: 1.2,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: const Color(0xFF333333).withValues(alpha: 0.8),
            width: 1,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: Color(0xFF333333), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0A0A0A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF333333), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF333333), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: darkPrimary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: const Color(0xFF333333).withValues(alpha: 0.5),
        thickness: 0.8,
        space: 1,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: darkPrimary,
        selectionColor: darkPrimary.withValues(alpha: 0.3),
        selectionHandleColor: darkPrimary,
      ),
      textTheme: FontService.getTextTheme(ThemeData.dark().textTheme),
    );
  }

  static Color getPriorityColor(int priority) {
    switch (priority) {
      case 0:
        return priorityLow;
      case 1:
        return priorityMedium;
      case 2:
        return priorityHigh;
      case 3:
        return priorityCritical;
      default:
        return priorityMedium;
    }
  }
}
