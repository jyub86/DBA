import 'package:flutter/material.dart';
import '../providers/user_data_provider.dart';
import '../providers/theme_provider.dart';
import 'package:provider/provider.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onIndexChanged;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 테마 제공자를 통해 현재 테마 상태 가져오기
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return ListenableBuilder(
      listenable: UserDataProvider.instance,
      builder: (context, _) {
        final userData = UserDataProvider.instance.userData;
        if (userData == null) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            // 다크모드에 따라 배경색 변경
            color: isDarkMode
                ? Theme.of(context).colorScheme.surface.withAlpha(230)
                : Colors.white.withAlpha(179),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withAlpha(50)
                    : Colors.black.withAlpha(26),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: onIndexChanged,
            backgroundColor: Colors.transparent,
            indicatorColor: Theme.of(context).colorScheme.primary.withAlpha(26),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: '홈',
              ),
              NavigationDestination(
                icon: Icon(Icons.article_outlined),
                selectedIcon: Icon(Icons.article),
                label: '게시판',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_box_outlined),
                selectedIcon: Icon(Icons.add_box),
                label: '글쓰기',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications),
                label: '알림',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu),
                selectedIcon: Icon(Icons.menu),
                label: '더보기',
              ),
            ],
          ),
        );
      },
    );
  }
}
