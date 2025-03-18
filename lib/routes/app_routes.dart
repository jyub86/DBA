import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import 'package:dba/screens/login_screen.dart';
import 'package:dba/screens/main_screen.dart';
import 'package:dba/screens/signup_screen.dart';
import 'package:dba/screens/board_screen.dart';
import 'package:dba/screens/create_post_screen.dart';
import 'package:dba/screens/notification_screen.dart';
import 'package:dba/screens/yearbook_screen.dart';
import 'package:dba/screens/settings_screen.dart';
import 'package:dba/screens/youtube_player_screen.dart';
import 'package:dba/screens/my_commented_posts_screen.dart';
import 'package:dba/screens/my_liked_posts_screen.dart';
import 'package:dba/screens/group_management_screen.dart';
import 'package:dba/screens/group_member_screen.dart';
import 'package:dba/screens/inquiry_screen.dart';
import 'package:dba/screens/church_calendar_screen.dart';
import 'package:dba/screens/church_event_form_screen.dart';
import 'package:dba/screens/church_event_management_screen.dart';
import 'package:dba/screens/banner_settings_screen.dart';
import 'package:dba/screens/comments_screen.dart';
import 'package:dba/widgets/terms_webview.dart';
import 'package:dba/models/group_model.dart';
import 'package:dba/models/post_model.dart';
import 'package:dba/models/church_event.dart';

// MainScreen의 상태를 보존하기 위한 전역 키는 더 이상 필요하지 않음
// final GlobalKey<State<MainScreen>> mainScreenKey =
//     GlobalKey<State<MainScreen>>();

// NavigatorService 대신 GlobalKey 사용
GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AppRoutes {
  // 라우트 이름 상수 정의
  static const String login = '/login';
  static const String loginCallback = '/login-callback';
  static const String signup = '/signup';
  static const String main = '/main';
  static const String board = '/board';
  static const String createPost = '/create-post';
  static const String notification = '/notification';
  static const String yearbook = '/yearbook';
  static const String settingsRoute = '/settings';
  static const String youtubePlayer = '/youtube-player';
  static const String myCommentedPosts = '/my-commented-posts';
  static const String myLikedPosts = '/my-liked-posts';
  static const String groupManagement = '/group-management';
  static const String groupMember = '/group-member';
  static const String inquiry = '/inquiry';
  static const String churchCalendar = '/church-calendar';
  static const String churchEventForm = '/church-event-form';
  static const String churchEventManagement = '/church-event-management';
  static const String bannerSettings = '/banner-settings';
  static const String comments = '/comments';
  static const String termsWebview = '/terms-webview';

  // 전역 변수로 알림 화면으로 이동해야 하는지 여부를 저장
  static bool shouldNavigateToNotification = false;

  // MainScreen 인스턴스 캐싱
  static MainScreen? cachedMainScreen;

  // 커스텀 페이지 라우트 생성 함수
  static PageRoute _createPageRoute(Widget page, RouteSettings settings) {
    // iOS에서는 CupertinoPageRoute를 사용하여 네이티브 스와이프 기능 활성화
    if (Platform.isIOS) {
      return CupertinoPageRoute(
        settings: settings,
        builder: (context) => page,
      );
    }

    // 안드로이드 및 기타 플랫폼에서는 커스텀 애니메이션 사용
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  // 라우트 생성 함수
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return _createPageRoute(
          shouldNavigateToNotification
              ? const MainScreen(initialIndex: 3)
              : const LoginScreen(),
          settings,
        );

      case login:
        return _createPageRoute(
          const LoginScreen(),
          settings,
        );

      case loginCallback:
        return _createPageRoute(
          const LoginScreen(),
          settings,
        );

      case signup:
        final args = settings.arguments as Map<String, dynamic>;
        return _createPageRoute(
          SignUpScreen(
            email: args['email'],
            profileUrl: args['profileUrl'],
            name: args['name'],
          ),
          settings,
        );

      case main:
        final args = settings.arguments as Map<String, dynamic>?;
        // iOS에서는 CupertinoPageRoute 사용
        if (Platform.isIOS) {
          return CupertinoPageRoute(
            settings: settings,
            builder: (context) => MainScreen(
              initialIndex: args?['initialIndex'] ?? 0,
              initialCategoryId: args?['initialCategoryId'],
            ),
          );
        }

        // 안드로이드 및 기타 플랫폼에서는 기존 애니메이션 사용
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) {
            return MainScreen(
              initialIndex: args?['initialIndex'] ?? 0,
              initialCategoryId: args?['initialCategoryId'],
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 페이드 인 애니메이션 적용
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          // 전환 시간을 짧게 설정하여 빠르게 화면 전환
          transitionDuration: const Duration(milliseconds: 150),
        );

      case board:
        final args = settings.arguments as Map<String, dynamic>?;
        return _createPageRoute(
          BoardScreen(
            initialCategoryId: args?['initialCategoryId'],
          ),
          settings,
        );

      case createPost:
        final args = settings.arguments as Map<String, dynamic>?;
        return _createPageRoute(
          CreatePostScreen(
            editPost: args?['editPost'] as Post?,
          ),
          settings,
        );

      case notification:
        return _createPageRoute(
          const NotificationScreen(),
          settings,
        );

      case yearbook:
        return _createPageRoute(
          const YearbookScreen(),
          settings,
        );

      case settingsRoute:
        return _createPageRoute(
          const SettingsScreen(),
          settings,
        );

      case youtubePlayer:
        final args = settings.arguments as Map<String, dynamic>;
        return _createPageRoute(
          YoutubePlayerScreen(
            videoId: args['videoId'],
          ),
          settings,
        );

      case myCommentedPosts:
        return _createPageRoute(
          const MyCommentedPostsScreen(),
          settings,
        );

      case myLikedPosts:
        return _createPageRoute(
          const MyLikedPostsScreen(),
          settings,
        );

      case groupManagement:
        return _createPageRoute(
          const GroupManagementScreen(),
          settings,
        );

      case groupMember:
        final args = settings.arguments as Map<String, dynamic>;
        return _createPageRoute(
          GroupMemberScreen(
            group: args['group'] as Group,
          ),
          settings,
        );

      case inquiry:
        return _createPageRoute(
          const InquiryScreen(),
          settings,
        );

      case churchCalendar:
        return _createPageRoute(
          const ChurchCalendarScreen(),
          settings,
        );

      case churchEventForm:
        final args = settings.arguments as Map<String, dynamic>?;
        return _createPageRoute(
          ChurchEventFormScreen(
            event: args?['event'] as ChurchEvent?,
          ),
          settings,
        );

      case churchEventManagement:
        return _createPageRoute(
          const ChurchEventManagementScreen(),
          settings,
        );

      case bannerSettings:
        return _createPageRoute(
          const BannerSettingsScreen(),
          settings,
        );

      case comments:
        final args = settings.arguments as Map<String, dynamic>;
        return _createPageRoute(
          CommentsScreen(
            postId: args['postId'],
          ),
          settings,
        );

      case termsWebview:
        final args = settings.arguments as Map<String, dynamic>;
        return _createPageRoute(
          TermsWebView(
            assetPath: args['assetPath'],
            title: args['title'],
          ),
          settings,
        );

      default:
        // 정의되지 않은 라우트에 대한 처리
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('페이지를 찾을 수 없습니다')),
            body: Center(
              child: Text('요청한 경로 ${settings.name}를 찾을 수 없습니다'),
            ),
          ),
          settings: settings,
        );
    }
  }
}
