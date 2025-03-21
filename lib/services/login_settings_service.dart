import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/logger_service.dart';

class LoginSettingsService {
  static final LoginSettingsService _instance =
      LoginSettingsService._internal();
  factory LoginSettingsService() => _instance;
  LoginSettingsService._internal();

  final _supabase = Supabase.instance.client;
  Map<String, bool> _loginSettings = {};
  DateTime? _lastFetchTime;

  // 설정 캐싱 시간 (5분)
  static const _cacheDuration = Duration(minutes: 5);

  bool get isCacheValid =>
      _lastFetchTime != null &&
      DateTime.now().difference(_lastFetchTime!) < _cacheDuration;

  /// 로그인 방식 설정 가져오기
  Future<Map<String, bool>> getLoginSettings() async {
    // 캐시가 유효하면 캐시된 설정 반환
    if (_loginSettings.isNotEmpty && isCacheValid) {
      return _loginSettings;
    }

    try {
      // Supabase에서 최신 설정 가져오기
      final response =
          await _supabase.from('login_settings').select('login, value');

      if (response.isNotEmpty) {
        // 응답 결과를 Map으로 변환
        _loginSettings = {};
        for (final item in response) {
          _loginSettings[item['login']] = item['value'];
        }
        _lastFetchTime = DateTime.now();
        LoggerService.info('로그인 설정 가져옴: $_loginSettings');
        return _loginSettings;
      }

      // 결과가 없으면 기본값 반환 (모든 로그인 방법 활성화)
      LoggerService.warning('로그인 설정 없음, 기본값 사용');
      return _getDefaultSettings();
    } catch (e, stackTrace) {
      // 오류 발생 시 로그 기록 후 기본값 반환
      LoggerService.error('로그인 설정 가져오기 실패', e, stackTrace);
      return _getDefaultSettings();
    }
  }

  /// 설정 캐시 지우기
  void clearCache() {
    _loginSettings = {};
    _lastFetchTime = null;
  }

  /// 기본 로그인 설정 (모두 활성화)
  Map<String, bool> _getDefaultSettings() {
    return {'email': true, 'kakao': true, 'google': true, 'apple': true};
  }

  /// 특정 로그인 방식이 활성화되어 있는지 확인
  Future<bool> isLoginMethodEnabled(String method) async {
    final settings = await getLoginSettings();
    return settings[method] ?? false;
  }
}
