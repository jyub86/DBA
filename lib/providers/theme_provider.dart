import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱의 테마 상태를 관리하는 Provider
class ThemeProvider extends ChangeNotifier {
  /// 테마 저장용 키
  static const String _themePreferenceKey = 'theme_mode';

  /// 현재 테마 모드 (기본값: 라이트 모드)
  ThemeMode _themeMode = ThemeMode.light;

  /// 현재 테마 모드 getter
  ThemeMode get themeMode => _themeMode;

  /// 다크 모드 여부 확인
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Provider 초기화
  ThemeProvider() {
    _loadThemePreference();
  }

  /// 테마 모드 설정 (라이트/다크)
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    // 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePreferenceKey, mode.toString());
  }

  /// 테마 모드 전환 (라이트 <-> 다크)
  Future<void> toggleTheme() async {
    final newMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(newMode);
  }

  /// 저장된 테마 설정 불러오기
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themePreferenceKey);

      if (savedMode != null) {
        if (savedMode == ThemeMode.dark.toString()) {
          _themeMode = ThemeMode.dark;
        } else {
          _themeMode = ThemeMode.light;
        }
        notifyListeners();
      }
    } catch (e) {
      // 오류 발생 시 기본 테마(라이트) 유지
      debugPrint('테마 설정 불러오기 실패: $e');
    }
  }
}
