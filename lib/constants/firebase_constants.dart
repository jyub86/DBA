import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;

class FirebaseConstants {
  static String get apiKey => Platform.isIOS
      ? const String.fromEnvironment('FIREBASE_IOS_API_KEY')
      : const String.fromEnvironment('FIREBASE_ANDROID_API_KEY');

  static String get appId => Platform.isIOS
      ? const String.fromEnvironment('FIREBASE_IOS_APP_ID')
      : const String.fromEnvironment('FIREBASE_ANDROID_APP_ID');

  static String get messagingSenderId =>
      const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');

  static String get projectId =>
      const String.fromEnvironment('FIREBASE_PROJECT_ID');

  static String get storageBucket =>
      const String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  static FirebaseOptions get firebaseOptions => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        storageBucket: storageBucket,
      );
}
