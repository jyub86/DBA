import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/banner_model.dart';
import '../models/category_model.dart';
import '../services/category_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'settings_screen.dart';
import '../widgets/bottom_navigation_bar.dart';
import 'board_screen.dart';
import 'create_post_screen.dart';
import 'notification_screen.dart';
import '../providers/user_data_provider.dart';
import '../constants/supabase_constants.dart';
import '../services/logger_service.dart';
import 'webview_screen.dart';
import '../providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  final int? initialCategoryId;

  // 일반 생성자 사용
  const MainScreen({
    super.key,
    this.initialIndex = 0,
    this.initialCategoryId,
  });

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<BoardScreenState> _boardKey = GlobalKey();
  final _userDataProvider = UserDataProvider.instance;
  int _currentIndex = 0;
  bool isLoading = true;
  List<CategoryModel> categories = [];
  List<BannerModel> banners = [];
  Timer? _bannerTimer;
  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;
  DateTime? _lastBackPressTime;

  // 로딩 애니메이션을 위한 컨트롤러 추가
  late AnimationController _loadingAnimController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // 배경 이미지 로딩 상태 추적
  // 데이터가 이미 로드되었는지 추적하는 전역 변수
  static bool _globalDataLoaded = false;
  static List<CategoryModel> _globalCategories = [];
  static List<BannerModel> _globalBanners = [];
  static bool _globalBackgroundLoaded = false;
  static bool _globalDarkBackgroundLoaded = false;

  // 인덱스 업데이트 메서드 (public으로 변경)
  void updateIndex(int index, int? categoryId) {
    if (mounted) {
      setState(() {
        _currentIndex = index;
      });

      // 게시판 탭으로 이동하고 카테고리가 지정된 경우
      if (index == 1 && categoryId != null && _boardKey.currentState != null) {
        _boardKey.currentState?.updateCategory(categoryId);
      }
    }
  }

  // 추가: 라이트/다크 모드 배경 이미지 모두 캐시
  void _cacheBackgroundImages() {
    // 라이트 모드 이미지 캐시
    precacheImage(
      const CachedNetworkImageProvider(SupabaseConstants.backgroundImage),
      context,
    ).then((_) {
      if (mounted) {
        setState(() {
          _globalBackgroundLoaded = true;
        });
      }

      // 다크 모드 이미지 캐시 (라이트 모드 이미지 로딩 완료 후 순차적으로)
      precacheImage(
        const CachedNetworkImageProvider(SupabaseConstants.backgroundImageDark),
        context,
      ).then((_) {
        if (mounted) {
          setState(() {
            _globalDarkBackgroundLoaded = true;
          });
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    // 로딩 애니메이션 컨트롤러 초기화
    _loadingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingAnimController,
        curve: Curves.easeIn,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingAnimController,
        curve: Curves.easeOutBack,
      ),
    );

    // 애니메이션 반복 시작
    _loadingAnimController.repeat(reverse: true);

    // 초기 상태에서는 로딩 상태를 true로 설정
    isLoading = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 테마 제공자를 통해 현재 테마 상태 가져오기
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final isDarkMode = themeProvider.isDarkMode;

      // 배경 이미지가 이미 로드된 경우 상태 업데이트
      if (isDarkMode ? _globalDarkBackgroundLoaded : _globalBackgroundLoaded) {
        // 이미 로드된 상태라면 아무것도 하지 않음
      } else {
        // 배경 이미지를 모두 캐시 (라이트/다크)
        _cacheBackgroundImages();
      }

      // 데이터가 이미 로드된 경우 전역 데이터 사용
      if (_globalDataLoaded) {
        if (mounted) {
          setState(() {
            categories = _globalCategories;
            banners = _globalBanners;
            isLoading = false;

            // 배너가 있는 경우 중앙에서 시작하도록 설정
            if (banners.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_bannerController.hasClients) {
                  _bannerController.jumpToPage(1000 * banners.length);
                }
              });
            }
          });
        }
      } else {
        // 로그인 화면에서 메인 화면으로 전환될 때 지연시간을 더 길게 설정
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !_globalDataLoaded) {
            _loadData();
          }
        });
      }
    });

    _startBannerTimer();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _loadingAnimController.dispose(); // 애니메이션 컨트롤러 해제
    super.dispose();
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (banners.isEmpty || !mounted || !_bannerController.hasClients) return;

      // 다음 페이지로 자연스럽게 이동 (무한 스크롤)
      _bannerController.nextPage(
        duration: const Duration(milliseconds: 2000),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadData() async {
    if (_globalDataLoaded && !isLoading) return;

    // 로딩 상태를 true로 유지
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    // 로딩 시작 시간 기록
    final startTime = DateTime.now();

    try {
      if (!mounted) return;

      final supabase = Supabase.instance.client;

      // 배너와 카테고리 데이터를 동시에 로드
      final bannersData = await supabase
          .from('banners')
          .select()
          .eq('active', true)
          .order('created_at')
          .limit(5);

      final categoriesData = await CategoryService.instance.getCategories();

      if (!mounted) return;

      // 전역 변수에 데이터 저장
      _globalCategories = categoriesData;
      _globalBanners = bannersData
          .map((data) => BannerModel(
                id: data['id'],
                imageUrl: data['image_url'],
                link: data['link'],
                title: data['title'],
              ))
          .toList();

      // 최소 로딩 시간(1.5초) 보장
      final elapsedTime = DateTime.now().difference(startTime).inMilliseconds;
      final remainingTime = 1500 - elapsedTime;

      if (remainingTime > 0) {
        await Future.delayed(Duration(milliseconds: remainingTime));
      }

      if (mounted) {
        setState(() {
          banners = _globalBanners;
          categories = _globalCategories;
          isLoading = false;
          _globalDataLoaded = true; // 데이터 로드 완료 표시

          // 배너가 있는 경우 중앙에서 시작하도록 설정
          if (banners.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_bannerController.hasClients) {
                _bannerController.jumpToPage(1000 * banners.length);
              }
            });
          }
        });
      }

      if (banners.isNotEmpty) {
        _startBannerTimer();
      }
    } catch (e) {
      LoggerService.error('데이터 로드 중 에러 발생', e, null);

      // 오류가 발생해도 최소 로딩 시간 보장
      final elapsedTime = DateTime.now().difference(startTime).inMilliseconds;
      final remainingTime = 1500 - elapsedTime;

      if (remainingTime > 0) {
        await Future.delayed(Duration(milliseconds: remainingTime));
      }

      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _buildMenuButton({
    required String label,
    required VoidCallback onTap,
    String? iconUrl,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(179),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(70),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(3, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (iconUrl != null) ...[
              CachedNetworkImage(
                imageUrl: iconUrl,
                height: 45,
                width: 45,
                fit: BoxFit.contain,
                placeholder: (context, url) => const SizedBox(
                  height: 45,
                  width: 45,
                ),
                errorWidget: (context, url, error) => const SizedBox(
                  height: 45,
                  width: 45,
                ),
              ),
              const SizedBox(width: 15),
            ],
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuTap(String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewScreen(
          url: url,
          title: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _userDataProvider,
      builder: (context, _) {
        final userData = _userDataProvider.userData;

        // 사용자 데이터가 로드되지 않은 경우, 완전히 투명한 빈 화면 표시
        if (userData == null) {
          return const SizedBox.shrink();
        }

        // 로그인 유도 화면을 구축하는 함수
        Widget buildLoginRequiredScreen(String feature) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login_rounded,
                    size: 60,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '$feature 기능을 사용하려면\n로그인이 필요합니다',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '로그인하시면 더 많은 기능을\n사용하실 수 있습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // 로그아웃 처리
                      _userDataProvider.clear();
                      // 로그인 화면으로 이동
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('로그인하기'),
                  ),
                ],
              ),
            ),
          );
        }

        final List<Widget> screens = [
          _buildHomeScreen(),
          BoardScreen(
            key: _boardKey,
            initialCategoryId: widget.initialCategoryId,
          ),
          // 글쓰기 화면: 게스트 모드 또는 조건 미충족 시 제한
          Builder(
            builder: (context) {
              // 게스트 모드인 경우 로그인 유도 화면 표시
              if (_userDataProvider.isGuestMode) {
                return buildLoginRequiredScreen('글쓰기');
              }

              // 실제 로그인 사용자인 경우 기존 조건 확인
              if (userData.isInfoPublic && (userData.member ?? false)) {
                return const CreatePostScreen();
              }

              // 조건 미충족 시 기존 제한 화면 표시
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        !(userData.member ?? false)
                            ? '교인 인증이 필요한 기능입니다.'
                            : '정보 비공개 상태에서는\n글쓰기 기능을 사용할 수 없습니다.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        !(userData.member ?? false)
                            ? '관리자에게 문의하여\n교인 인증을 받으시기 바랍니다.'
                            : '설정에서 정보 공개로 변경하시면\n글쓰기 기능을 사용하실 수 있습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // 알림 화면: 게스트 모드 시 제한
          Builder(
            builder: (context) {
              // 게스트 모드인 경우 로그인 유도 화면 표시
              if (_userDataProvider.isGuestMode) {
                return buildLoginRequiredScreen('알림');
              }
              // 로그인한 사용자는 알림 화면 접근 가능
              return const NotificationScreen();
            },
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ];

        final themeProvider = Provider.of<ThemeProvider>(context);
        final isDarkMode = themeProvider.isDarkMode;

        // 모드에 따라 적절한 배경 이미지 로드 여부 결정
        final isAppropriateBackgroundLoaded =
            isDarkMode ? _globalDarkBackgroundLoaded : _globalBackgroundLoaded;

        // 배경 이미지와 콘텐츠를 함께 로드하여 깜빡임 방지
        final Widget content = Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                image: isAppropriateBackgroundLoaded
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(
                          isDarkMode
                              ? SupabaseConstants.backgroundImageDark
                              : SupabaseConstants.backgroundImage,
                        ),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: isAppropriateBackgroundLoaded
                    ? null
                    : isDarkMode
                        ? Theme.of(context).colorScheme.surface
                        : Colors.white,
              ),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: SafeArea(
                  bottom: false,
                  child: IndexedStack(
                    key: const ValueKey('main_content'),
                    index: _currentIndex,
                    children: screens,
                  ),
                ),
                endDrawer: const SettingsScreen(),
                bottomNavigationBar: CustomBottomNavigationBar(
                  currentIndex: _currentIndex,
                  onIndexChanged: _handleNavigationTap,
                ),
              ),
            ),
          ],
        );

        // 뒤로가기 처리를 위한 WillPopScope 사용
        return WillPopScope(
          onWillPop: () async {
            // 현재 게시판(인덱스 1) 또는 다른 화면에 있는 경우, 메인 화면으로 이동
            if (_currentIndex != 0) {
              setState(() {
                _currentIndex = 0;
              });
              return false;
            }

            // 메인 화면에서의 뒤로가기 처리
            // 두 번 뒤로 가기가 일정 시간 내에 발생하면 앱 종료
            final now = DateTime.now();
            if (_lastBackPressTime == null ||
                now.difference(_lastBackPressTime!) >
                    const Duration(seconds: 2)) {
              _lastBackPressTime = now;

              // 안전한 영역 고려한 Snackbar 위치 조정
              final snackBar = SnackBar(
                content: const Text('뒤로가기를 한번 더 누르면 앱이 종료됩니다.'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  left: 16,
                  right: 16,
                ),
              );

              ScaffoldMessenger.of(context).showSnackBar(snackBar);
              return false;
            }
            // 앱 종료
            SystemNavigator.pop();
            return true;
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: isLoading
                ? Scaffold(
                    key: const ValueKey('loading_screen'),
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    body: Center(
                      child: AnimatedBuilder(
                        animation: _loadingAnimController,
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/church_logo.png',
                                    height: 50,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  )
                : content,
          ),
        );
      },
    );
  }

  Widget _buildHomeScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final padding = isLandscape ? 8.0 : 16.0;
        final bannerAspectRatio = isLandscape ? 21 / 9 : 16 / 9;
        final themeProvider = Provider.of<ThemeProvider>(context);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 교회 로고
              Padding(
                padding: EdgeInsets.all(padding),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/church_logo.png',
                      height: 30,
                      // 다크모드일 때 로고 밝기 조정
                      color: themeProvider.isDarkMode ? Colors.white : null,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              // 상단 배너 (이미지 슬라이더)
              if (banners.isEmpty)
                Padding(
                  padding: EdgeInsets.all(padding),
                  child: AspectRatio(
                    aspectRatio: bannerAspectRatio,
                    child: Container(
                      decoration: BoxDecoration(
                        color: themeProvider.isDarkMode
                            ? Colors.grey[800]
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '등록된 배너가 없습니다',
                          style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.all(padding),
                  child: AspectRatio(
                    aspectRatio: bannerAspectRatio,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(70),
                                spreadRadius: 1,
                                blurRadius: 5,
                                offset: const Offset(3, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: PageView.builder(
                              controller: _bannerController,
                              // 무한 스크롤을 위해 매우 큰 숫자로 설정
                              itemCount: banners.isEmpty ? 0 : null,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentBannerIndex = index % banners.length;
                                });
                              },
                              itemBuilder: (context, index) {
                                // 배너 배열 인덱스 계산 (무한 스크롤)
                                final bannerIndex = index % banners.length;
                                return GestureDetector(
                                  onTap: () {
                                    if (banners[bannerIndex].link != null) {
                                      launchUrl(Uri.parse(
                                          banners[bannerIndex].link!));
                                    }
                                  },
                                  child: CachedNetworkImage(
                                    imageUrl: banners[bannerIndex].imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        const SizedBox(),
                                    errorWidget: (context, url, error) =>
                                        const Center(
                                      child: Icon(Icons.error),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        if (banners.length > 1)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                banners.length,
                                (index) => Container(
                                  width: 8,
                                  height: 8,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentBannerIndex == index
                                        ? Colors.white
                                        : Colors.white.withAlpha(128),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // 메뉴 그리드
              Padding(
                padding: EdgeInsets.all(padding),
                child: GridView.count(
                  crossAxisCount: isLandscape ? 3 : 2,
                  padding: EdgeInsets.all(padding),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: padding,
                  crossAxisSpacing: padding,
                  childAspectRatio: isLandscape ? 3.0 : 2.0,
                  children: [
                    ...categories.map((category) {
                      return _buildMenuButton(
                        label: category.name,
                        iconUrl: category.iconUrl,
                        onTap: () {
                          setState(() => _currentIndex = 1);
                          _boardKey.currentState?.updateCategory(category.id);
                        },
                      );
                    }),
                    // 교인 연락처 메뉴
                    ListenableBuilder(
                      listenable: _userDataProvider,
                      builder: (context, _) {
                        final userData = _userDataProvider.userData;
                        final isMember = userData?.member ?? false;
                        final isInfoPublic = userData?.isInfoPublic ?? false;
                        final isGuest = _userDataProvider.isGuestMode;

                        return _buildMenuButton(
                          label: '연락처',
                          iconUrl:
                              'https://nfivyduwknskpfhuyzeg.supabase.co/storage/v1/object/public/icons//address.png',
                          onTap: () {
                            // 게스트 모드 체크를 가장 먼저 수행
                            if (isGuest) {
                              // 로그인이 필요하다는 다이얼로그 표시
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('로그인 필요'),
                                  content: const Text(
                                      '교인 연락처 기능을 사용하려면 로그인이 필요합니다.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('취소'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        // 로그아웃 처리
                                        _userDataProvider.clear();
                                        // 로그인 화면으로 이동
                                        Navigator.pushNamedAndRemoveUntil(
                                          context,
                                          '/login',
                                          (route) => false,
                                        );
                                      },
                                      child: const Text('로그인하기'),
                                    ),
                                  ],
                                ),
                              );
                            } else if (!isMember) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('교인 인증 후 사용 가능한 기능입니다.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else if (!isInfoPublic) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('정보 공개 설정 후 사용 가능한 기능입니다.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              Navigator.pushNamed(
                                context,
                                '/yearbook',
                              );
                            }
                          },
                        );
                      },
                    ),
                    // 교회 일정 메뉴
                    ListenableBuilder(
                      listenable: _userDataProvider,
                      builder: (context, _) {
                        return _buildMenuButton(
                            label: '교회 일정',
                            iconUrl:
                                'https://nfivyduwknskpfhuyzeg.supabase.co/storage/v1/object/public/icons/calendar.png',
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/church-calendar',
                              );
                            });
                      },
                    ),
                    // 홈페이지 메뉴
                    _buildMenuButton(
                      label: '홈페이지',
                      iconUrl:
                          'https://nfivyduwknskpfhuyzeg.supabase.co/storage/v1/object/public/icons//homepage.png',
                      onTap: () =>
                          _handleMenuTap('https://dbchurch.net', '홈페이지'),
                    ),
                    // 유튜브 메뉴
                    _buildMenuButton(
                      label: '유튜브',
                      iconUrl:
                          'https://nfivyduwknskpfhuyzeg.supabase.co/storage/v1/object/public/icons//youtube.png',
                      onTap: () => _handleMenuTap(
                          'https://www.youtube.com/@dbchurch', '유튜브'),
                    ),
                    // 빈 공간을 위한 투명한 버튼
                    const SizedBox(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _handleNavigationTap(int index) {
    if (index == 4) {
      // 더보기 탭을 눌렀을 때
      final context = _boardKey.currentContext ?? this.context;
      Scaffold.of(context).openEndDrawer();
      return;
    }
    if (mounted) {
      setState(() => _currentIndex = index);
    }
    if (index == 1) {
      _boardKey.currentState?.updateCategory(0);
    }
  }
}
