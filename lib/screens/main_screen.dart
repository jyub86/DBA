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
import 'yearbook_screen.dart';
import '../providers/user_data_provider.dart';
import '../constants/supabase_constants.dart';
import '../services/logger_service.dart';
import 'church_calendar_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  final int? initialCategoryId;

  const MainScreen({
    super.key,
    this.initialIndex = 0,
    this.initialCategoryId,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<BoardScreenState> _boardKey = GlobalKey();
  final _userDataProvider = UserDataProvider.instance;
  int _currentIndex = 0;
  bool isLoading = true;
  List<CategoryModel> categories = [];
  List<BannerModel> banners = [];
  Timer? _bannerTimer;
  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadData();
    _startBannerTimer();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (banners.isEmpty || !mounted || !_bannerController.hasClients) return;

      final nextPage = (_currentBannerIndex + 1) % banners.length;
      _bannerController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadData() async {
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

      setState(() {
        banners = bannersData
            .map((data) => BannerModel(
                  id: data['id'],
                  imageUrl: data['image_url'],
                  link: data['link'],
                  title: data['title'],
                ))
            .toList();

        categories = categoriesData;
        isLoading = false;
      });

      if (banners.isNotEmpty) {
        _startBannerTimer();
      }
    } catch (e) {
      LoggerService.error('데이터 로드 중 에러 발생', e, null);
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _userDataProvider,
      builder: (context, _) {
        final userData = _userDataProvider.userData;
        if (userData == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<Widget> screens = [
          _buildHomeScreen(),
          BoardScreen(
            key: _boardKey,
            initialCategoryId: widget.initialCategoryId,
          ),
          const CreatePostScreen(),
          const NotificationScreen(),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ];

        return Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: CachedNetworkImageProvider(
                SupabaseConstants.backgroundImage,
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : IndexedStack(
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
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          '등록된 배너가 없습니다',
                          style: TextStyle(
                            color: Colors.grey,
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
                              itemCount: banners.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentBannerIndex = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () {
                                    if (banners[index].link != null) {
                                      launchUrl(
                                          Uri.parse(banners[index].link!));
                                    }
                                  },
                                  child: CachedNetworkImage(
                                    imageUrl: banners[index].imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
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
                        return _buildMenuButton(
                          label: '연락처',
                          iconUrl:
                              'https://nfivyduwknskpfhuyzeg.supabase.co/storage/v1/object/public/icons//address.png',
                          onTap: (userData?.member ?? false)
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const YearbookScreen(),
                                    ),
                                  );
                                }
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('교인 인증 후 사용 가능한 기능입니다.'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ChurchCalendarScreen(),
                                ),
                              );
                            });
                      },
                    ),
                    // 홈페이지 메뉴
                    _buildMenuButton(
                      label: '홈페이지',
                      iconUrl:
                          'https://nfivyduwknskpfhuyzeg.supabase.co/storage/v1/object/public/icons//homepage.png',
                      onTap: () {
                        launchUrl(
                          Uri.parse('https://dbchurch.net'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                    // 유튜브 메뉴
                    _buildMenuButton(
                      label: '유튜브',
                      iconUrl:
                          'https://nfivyduwknskpfhuyzeg.supabase.co/storage/v1/object/public/icons//youtube.png',
                      onTap: () {
                        launchUrl(
                          Uri.parse('https://www.youtube.com/@dbchurch'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
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
    setState(() => _currentIndex = index);
    if (index == 1) {
      _boardKey.currentState?.updateCategory(0);
    }
  }
}
