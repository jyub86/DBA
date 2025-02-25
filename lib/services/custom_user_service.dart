import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../providers/user_data_provider.dart';
import 'package:dba/services/logger_service.dart';

class CustomUserService {
  static final CustomUserService instance = CustomUserService._internal();
  CustomUserService._internal();

  final supabase = Supabase.instance.client;
  final _userDataProvider = UserDataProvider.instance;
  UserData? _cachedCurrentUser;
  DateTime? _lastCacheTime;
  static const _cacheValidityDuration = Duration(minutes: 30);

  // 사용자 정보 변경 알림을 받을 리스너들
  final _userDataListeners = <Function(UserData)>{};

  bool get _isCacheValid {
    if (_cachedCurrentUser == null || _lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < _cacheValidityDuration;
  }

  /// 로그인 시 사용자 정보를 캐시에 저장
  Future<UserData> initializeUserData(String authId) async {
    final response = await supabase
        .from('custom_users')
        .select('*, roles (*)')
        .eq('auth_id', authId)
        .single();

    _cachedCurrentUser = UserData.fromJson(response);
    _lastCacheTime = DateTime.now();
    _notifyListeners();
    return _cachedCurrentUser!;
  }

  /// 현재 사용자 정보 가져오기
  Future<UserData> getCurrentUser({bool forceRefresh = false}) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    if (!forceRefresh && _isCacheValid) {
      return _cachedCurrentUser!;
    }

    return initializeUserData(currentUser.id);
  }

  /// 사용자 정보 업데이트
  Future<UserData> updateUserInfo(Map<String, dynamic> updates,
      {String? authId}) async {
    // 업데이트 가능한 필드만 필터링
    final validUpdates = updates.map((key, value) => MapEntry(key, value))
      ..removeWhere((key, value) => !UserData.isUpdatableField(key));

    if (validUpdates.isEmpty) {
      throw Exception('업데이트할 수 있는 필드가 없습니다.');
    }

    final currentUser = await getCurrentUser();
    final targetAuthId = authId ?? currentUser.authId;

    final response = await supabase
        .from('custom_users')
        .update(validUpdates)
        .eq('auth_id', targetAuthId)
        .select('*, roles (*)')
        .single();

    // 캐시 업데이트 (자신의 정보를 업데이트한 경우에만)
    if (authId == null) {
      _cachedCurrentUser = UserData.fromJson(response);
      _lastCacheTime = DateTime.now();
      _notifyListeners();
    }

    return UserData.fromJson(response);
  }

  /// 캐시 초기화
  void clearCache() {
    _cachedCurrentUser = null;
    _lastCacheTime = null;
    _notifyListeners();
  }

  /// 사용자 정보 변경 리스너 등록
  void addListener(Function(UserData) listener) {
    _userDataListeners.add(listener);
  }

  /// 사용자 정보 변경 리스너 제거
  void removeListener(Function(UserData) listener) {
    _userDataListeners.remove(listener);
  }

  /// 리스너들에게 사용자 정보 변경 알림
  void _notifyListeners() {
    if (_cachedCurrentUser != null) {
      for (final listener in _userDataListeners) {
        listener(_cachedCurrentUser!);
      }
    }
  }

  Future<List<UserData>> getCustomUsers({String? searchQuery}) async {
    try {
      // 현재 사용자 데이터 가져오기
      final currentUserData = await _userDataProvider.getCurrentUser();

      // 기본 쿼리 설정
      var query = supabase.from('custom_users').select('*, roles (*)');

      // 관리자가 아닌 경우에만 필터 적용
      if (!currentUserData.canManage) {
        // member=true이고 정보 공개를 허용한 사용자만 조회
        query = query.eq('member', true).eq('is_info_public', true);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query
            .ilike('name', '%$searchQuery%')
            .or('office.ilike.%$searchQuery%');
      }

      final response = await query.order('name');

      final users = response
          .map((data) => UserData.fromJson(data))
          .toList()
          .cast<UserData>();

      return users;
    } catch (e, stackTrace) {
      LoggerService.error('교인 연락처 데이터 조회 중 에러 발생', e, stackTrace);
      rethrow;
    }
  }

  Future<List<UserData>> searchUsers(String? searchQuery) async {
    try {
      // 현재 사용자 데이터 가져오기
      final currentUserData = await _userDataProvider.getCurrentUser();

      var query = supabase.from('custom_users').select('''
        *,
        roles:role (
          code,
          name,
          level
        )
      ''');

      // 관리자가 아닌 경우에만 필터 적용
      if (!currentUserData.canManage) {
        query = query.eq('is_info_public', true);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'name.ilike.%$searchQuery%,phone.ilike.%$searchQuery%,address.ilike.%$searchQuery%',
        );
      }

      final response = await query;

      final users = response.map((data) {
        return UserData.fromJson(Map<String, dynamic>.from(data));
      }).toList();

      return users;
    } catch (e, stackTrace) {
      LoggerService.error('교인 연락처 데이터 조회 중 에러 발생', e, stackTrace);
      rethrow;
    }
  }
}
