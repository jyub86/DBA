import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/logger_service.dart';

class UserDataProvider extends ChangeNotifier {
  static final UserDataProvider _instance = UserDataProvider._internal();
  static UserDataProvider get instance => _instance;
  UserDataProvider._internal();

  final _supabase = Supabase.instance.client;
  UserData? _userData;
  DateTime? _lastUpdateTime;
  static const _cacheValidityDuration = Duration(minutes: 30);
  bool _isGuestMode = false;

  UserData? get userData => _userData;
  bool get isLoggedIn => _userData != null;
  bool get isGuestMode => _isGuestMode;
  bool get isRealUser => _userData != null && !_isGuestMode;

  bool get _isCacheValid {
    if (_userData == null || _lastUpdateTime == null) return false;
    return DateTime.now().difference(_lastUpdateTime!) < _cacheValidityDuration;
  }

  /// 게스트 모드 설정
  void setGuestMode() {
    _isGuestMode = true;
    _userData = UserData.empty(
      id: 'guest',
      authId: 'guest',
      email: 'guest@example.com',
    );
    _lastUpdateTime = DateTime.now();
    notifyListeners();
  }

  /// 첫 로그인 시 초기화 (소셜 로그인 이름 활용)
  Future<void> initializeFirstLogin(String authId, String email,
      {String? name}) async {
    try {
      _isGuestMode = false;
      await _fetchUserData(authId);
    } catch (e, stackTrace) {
      LoggerService.error('첫 로그인 초기화 중 오류 발생: ${e.toString()}', e, stackTrace);
      rethrow;
    }
  }

  /// 사용자 데이터 초기화 (로그인 시 호출)
  Future<UserData> initialize(String authId) async {
    try {
      _isGuestMode = false;
      return await _fetchUserData(authId);
    } catch (e, stackTrace) {
      LoggerService.error(
          '사용자 데이터 초기화 중 오류 발생: ${e.toString()}', e, stackTrace);
      if (e.toString().contains('JSON value is not a singleton array')) {
        throw Exception('사용자를 찾을 수 없습니다.');
      }
      rethrow;
    }
  }

  /// 사용자 데이터 조회 (내부 메서드)
  Future<UserData> _fetchUserData(String authId) async {
    final authUser = _supabase.auth.currentUser;
    final authUserName = authUser?.userMetadata?['name'] as String?;
    final authUserEmail = authUser?.email;

    final userResponse = await _supabase
        .from('custom_users')
        .select('*, roles!left(*)')
        .eq('auth_id', authId)
        .maybeSingle();

    final Map<String, dynamic> combinedResponse = {
      ...?userResponse,
      'auth_id': authId,
      'name': userResponse?['name'] ?? authUserName,
      'email': userResponse?['email'] ?? authUserEmail,
    };

    _userData = UserData.fromJson(combinedResponse);
    _lastUpdateTime = DateTime.now();
    notifyListeners();
    return _userData!;
  }

  /// 현재 사용자 데이터 가져오기
  Future<UserData> getCurrentUser({bool forceRefresh = false}) async {
    if (_isGuestMode) {
      return _userData!;
    }

    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    if (!forceRefresh && _isCacheValid) {
      return _userData!;
    }

    return initialize(currentUser.id);
  }

  /// 사용자 정보 등록/업데이트
  Future<UserData> updateUserInfo(Map<String, dynamic> updates) async {
    if (_isGuestMode) {
      throw Exception('게스트 모드에서는 정보를 업데이트할 수 없습니다.');
    }

    if (_userData == null) {
      throw Exception('로그인이 필요합니다.');
    }

    try {
      final validUpdates = updates.map((key, value) => MapEntry(key, value))
        ..removeWhere((key, value) => !UserData.isUpdatableField(key));

      if (validUpdates.isEmpty) {
        throw Exception('업데이트할 수 있는 필드가 없습니다.');
      }
      await _supabase
          .from('custom_users')
          .update(validUpdates)
          .eq('auth_id', _userData!.authId);
      return await _fetchUserData(_userData!.authId);
    } catch (e, stackTrace) {
      LoggerService.error(
          '사용자 정보 업데이트 중 오류 발생: ${e.toString()}', e, stackTrace);
      rethrow;
    }
  }

  /// 로그아웃 시 데이터 초기화
  void clear() {
    _userData = null;
    _lastUpdateTime = null;
    _isGuestMode = false;
    notifyListeners();
  }
}
