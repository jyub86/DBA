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

  UserData? get userData => _userData;
  bool get isLoggedIn => _userData != null;

  bool get _isCacheValid {
    if (_userData == null || _lastUpdateTime == null) return false;
    return DateTime.now().difference(_lastUpdateTime!) < _cacheValidityDuration;
  }

  /// 첫 로그인 시 초기화 (소셜 로그인 이름 활용)
  Future<void> initializeFirstLogin(String authId, String email,
      {String? name}) async {
    try {
      // 사용자 데이터 조회
      await _fetchUserData(authId);
    } catch (e, stackTrace) {
      LoggerService.error('첫 로그인 초기화 중 오류 발생: ${e.toString()}', e, stackTrace);
      rethrow;
    }
  }

  /// 사용자 데이터 초기화 (로그인 시 호출)
  Future<UserData> initialize(String authId) async {
    try {
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
    // 1. auth.users에서 메타데이터 가져오기
    final authUser = _supabase.auth.currentUser;
    final authUserName = authUser?.userMetadata?['name'] as String?;
    final authUserEmail = authUser?.email;

    // 2. 기본 사용자 정보와 역할 조회 (없을 수 있음)
    final userResponse = await _supabase
        .from('custom_users')
        .select('*, roles!left(*)')
        .eq('auth_id', authId)
        .maybeSingle();

    // 3. 응답 데이터 결합 (auth.users의 이름을 우선 사용)
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
    if (_userData == null) {
      throw Exception('로그인이 필요합니다.');
    }

    try {
      // 업데이트 가능한 필드만 필터링
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
    notifyListeners();
  }
}
