import 'package:flutter/material.dart';

import '../features/content/content_page.dart';
import '../features/flashcard/flashcard_page.dart';
import '../features/settings/settings_page.dart';
import '../shared/pill_button.dart';
import 'design/design.dart';
import 'theme/fold_decoration.dart';
import 'theme/mode_theme.dart';

/// 主界面：底部三 Tab（内容 / 闪卡 / 设置）。
///
/// 全屏内容 + 浮层控制：三页内容全屏铺底，上下边缘由渐隐遮罩（[AppOverlay]）
/// 覆盖；顶部标题浮层（每 Tab 小标题 + 页名）与底部导航浮层直接压在渐变之上。
/// 内容滚动到浮层下方时柔和淡出。
///
/// 内容页的「添加」不再放右上角：作为通栏按钮悬浮在内容页底部（与闪卡页
/// 学习 / 复习按钮同款）；收藏并入闪卡页顶部通栏，不占 Tab。
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
    SettingsPage(),
  ];

  /// 每 Tab 的顶部浮层标题：小标题 + 页名。
  static const List<(String, String)> _titles = [
    ('GOSLOW', '内容'),
    ('FLASHCARD', '闪卡'),
    ('SETTINGS', '设置'),
  ];

  /// 底部导航项。
  static const _navItems = [
    (icon: Icons.menu_book_outlined, label: '内容'),
    (icon: Icons.style_outlined, label: '闪卡'),
    (icon: Icons.settings_outlined, label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Stack(
        children: [
          // 全屏内容：三 Tab 常驻，滚动时被上下渐隐遮罩覆盖。
          Positioned.fill(
            child: IndexedStack(index: _index, children: _pages),
          ),
          // 顶部渐隐遮罩：闪卡页自带同款遮罩（且其按钮需压在遮罩之上），
          // 因此仅在内容 / 设置页挂载，避免遮罩盖住闪卡页「学习 / 复习」按钮。
          if (_index != 1)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: AppOverlay.topFadeHeight,
              child: IgnorePointer(
                child: DecoratedBox(decoration: AppOverlay.topFade()),
              ),
            ),
          // 底部渐隐遮罩：同上。
          if (_index != 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: AppOverlay.bottomFadeHeight,
              child: IgnorePointer(
                child: DecoratedBox(decoration: AppOverlay.bottomFade()),
              ),
            ),
          // 顶部浮层：小标题 + 页名。
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
                  ],
                ),
              ),
            ),
          ),
          // 内容页底部通栏「添加」按钮（压在底部渐隐之上，同闪卡学习/复习）。
          if (_index == 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: AppOverlay.bottomInset(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: _AddContentButton(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ContentImportPage(),
                      ),
                    );
                  },
                ),
              ),
            ),
          // 底部导航浮层：三个独立悬浮按钮，复用全局 PillButton。
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < _navItems.length; i++)
                      PillButton(
                        icon: _navItems[i].icon,
                        label: _navItems[i].label,
                        highlight: i == _index,
                        onTap: () => setState(() => _index = i),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 内容页底部通栏「添加」按钮：主色实底胶囊，整屏宽度。
class _AddContentButton extends StatelessWidget {
  const _AddContentButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const theme = ModeThemes.love;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      shape: FoldShape(
        borderRadius: theme.chipRadius,
        fold: theme.cornerFold,
        side: BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 18, color: scheme.onPrimary),
              const SizedBox(width: AppSpacing.pillGap),
              Text(
                '添加内容',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
