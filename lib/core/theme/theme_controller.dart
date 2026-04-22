import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController extends ChangeNotifier {
  bool _isDark = true;

  bool get isDark => _isDark;

  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool('isDark') ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme(bool value) async {
    _isDark = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', value);

    notifyListeners();
  }
}
