import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  AppThemeMode _currentTheme = AppThemeMode.dark;

  AppThemeMode get currentTheme => _currentTheme;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to dark mode (0)
    int themeIndex = prefs.getInt('theme') ?? 0;

    // Safety check: if index is out of bounds (old indices for light/blue/etc), reset to dark (0)
    if (themeIndex >= AppThemeMode.values.length) {
      themeIndex = 0;
    }

    _currentTheme = AppThemeMode.values[themeIndex];
    notifyListeners();
  }

  Future<void> setTheme(AppThemeMode theme) async {
    _currentTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme', theme.index);
    notifyListeners();
  }
}
