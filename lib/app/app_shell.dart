import 'package:flutter/material.dart';

import '../features/content/content_page.dart';
import '../features/content/paste_page.dart';
import '../features/favorite/favorite_page.dart';
import '../features/flashcard/flashcard_page.dart';
import '../features/settings/settings_page.dart';
import '../shared/circle_action.dart';
import 'design/design.dart';

/// 主界面：底部四 Tab（内容 / 闪卡 / 收藏 / 设置）。
///
/// 全屏内容 + 浮层控制：四页内容全屏铺底，上下边缘由渐隐遮罩（[AppOverlay]）
/// 覆盖；顶部标题浮层（每 Tab 小标题 + 页名，内容页带「+」）与底部导航浮层
/// 直接压在渐变之上。内容滚动到浮层下方时柔和淡出。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const List<Widget> _pages = [
    ContentPage(),
    FlashcardPage(),
    FavoritePage(),
    SettingsPage(),
  ];

  /// 每 Tab 的顶部浮层标题：小标题 + 页名。
  static const List<(String, String)> _titles = [
    ('GOSLOW', '内容'),
    ('FLASHCARD', '闪卡'),
    ('FAVORITE', '收藏'),
    ('SETTINGS', '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Stack(
        children: [
          // 全屏内容：四 Tab 常驻，滚动时被上下渐隐遮罩覆盖。
          Positioned.fill(
            child: IndexedStack(index: _index, children: _pages),
          ),
          // 顶部渐隐遮罩。
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: AppOverlay.topFadeHeight,
            child: IgnorePointer(
              child: DecoratedBox(decoration: AppOverlay.topFade()),
            ),
          ),
          // 底部渐隐遮罩。
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: AppOverlay.bottomFadeHeight,
            child: IgnorePointer(
              child: DecoratedBox(decoration: AppOverlay.bottomFade()),
            ),
          ),
          // 顶部浮层：小标题 + 页名（内容页右侧「+」）。
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _titles[_index].$1,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppColors.inkMuted,
                                  letterSpacing: 0.12 * 11,
                                ),
                          ),
                          Text(
                            _titles[_index].$2,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    if (_index == 0)
                      CircleAction(
                        icon: Icons.add,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PastePage(),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          // 底部导航浮层：直接压在渐隐遮罩之上。
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: '内容',
                ),
                NavigationDestination(
                  icon: Icon(Icons.style_outlined),
                  selectedIcon: Icon(Icons.style),
                  label: '闪卡',
                ),
                NavigationDestination(
                  icon: Icon(Icons.star_outline),
                  selectedIcon: Icon(Icons.star),
                  label: '收藏',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '设置',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
