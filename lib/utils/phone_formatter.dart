class PhoneFormatter {
  /// 전화번호에서 하이픈을 제거합니다.
  static String removeHyphens(String phone) {
    return phone.replaceAll('-', '');
  }

  /// 전화번호를 포맷팅합니다 (010-1234-5678 형식)
  static String format(String phone) {
    // 하이픈 제거
    final digits = removeHyphens(phone);

    if (digits.length != 11) return phone; // 유효하지 않은 길이면 원본 반환

    // 010-1234-5678 형식으로 포맷팅
    return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
  }

  /// 전화번호가 유효한지 검사합니다.
  static bool isValid(String phone) {
    final digits = removeHyphens(phone);
    if (digits.length != 11) return false;
    if (!digits.startsWith('010')) return false;
    return RegExp(r'^[0-9]+$').hasMatch(digits);
  }
}
