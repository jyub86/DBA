import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class UserDataProvider extends ChangeNotifier {
  static final UserDataProvider instance = UserDataProvider._internal();
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

  /// 사용자 데이터 초기화 (로그인 시 호출)
  Future<UserData> initialize(String authId) async {
    final response = await _supabase
        .from('custom_users')
        .select('*, roles (*)')
        .eq('auth_id', authId)
        .single();

    _userData = UserData.fromJson(response);
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

  /// 사용자 정보 업데이트
  Future<UserData> updateUserInfo(Map<String, dynamic> updates) async {
    if (_userData == null) {
      throw Exception('로그인이 필요합니다.');
    }

    // 업데이트 가능한 필드만 필터링
    final validUpdates = updates.map((key, value) => MapEntry(key, value))
      ..removeWhere((key, value) => !UserData.isUpdatableField(key));

    if (validUpdates.isEmpty) {
      throw Exception('업데이트할 수 있는 필드가 없습니다.');
    }

    final response = await _supabase
        .from('custom_users')
        .update(validUpdates)
        .eq('auth_id', _userData!.authId)
        .select('*, roles (*)')
        .single();

    _userData = UserData.fromJson(response);
    _lastUpdateTime = DateTime.now();
    notifyListeners();
    return _userData!;
  }

  /// 로그아웃 시 데이터 초기화
  void clear() {
    _userData = null;
    _lastUpdateTime = null;
    notifyListeners();
  }
}
