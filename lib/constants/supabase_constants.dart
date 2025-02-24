class SupabaseConstants {
  static const String projectUrl = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // 모바일 앱용 딥링크 설정
  static const String scheme = 'com.bupyungdongbuchurch.dba';
  static const String host = 'login-callback';
  static const String redirectUrl = '$scheme://$host';

  // 백그라운드 이미지
  static const String backgroundImage =
      'https://nfivyduwknskpfhuyzeg.supabase.co/storage/v1/object/public/utils//background.jpg';
}
