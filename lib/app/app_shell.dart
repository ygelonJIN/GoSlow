import 'package:flutter/material.dart';

import '../features/content/content_page.dart';
import '../features/content/dict_lookup_page.dart';
import '../features/settings/settings_panel.dart';
import '../shared/pill_button.dart';
import 'design/design.dart';
import 'theme/fold_decoration.dart';
import 'theme/mode_theme.dart';

/// 主界面：全屏内容 + 左上角「设置」胶囊 → 向左滑出的 75% 设置侧栏。
///
/// 全屏内容铺底，上下边缘由渐隐遮罩覆盖；顶部浮层只有左上角「设置」胶囊，
/// 底部浮层分两行：上面是「添加」主色胶囊，下面是 SoWhat 输入条同构的
/// 搜索框（查单词 · 搜内容）。设置侧栏从左侧滑入，占屏宽 75%（SoWhat 3/4
/// 面板），主页面右移只保留右侧约 1/4 可见；遮罩覆盖可见区域，点击遮罩
/// 收起；面板自带上下渐变遮罩与「设置」标题。动画 340ms easeOutCubic，
/// 展开 / 收起即时响应（boolean 驱动，无二次动画延迟）。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// 设置侧栏是否展开（boolean 驱动，点击即翻转，与 IGotYou 一致）。
  bool _settingsOpen = false;

  /// 底部输入框实时关键词（过滤「最近阅读」）。
  String _query = '';

  void _openSettings() {
    if (_settingsOpen) return;
    FocusScope.of(context).unfocus();
    setState(() => _settingsOpen = true);
  }

  void _closeSettings() {
    if (!_settingsOpen) return;
    FocusScope.of(context).unfocus();
    setState(() => _settingsOpen = false);
  }

  void _openLookup(String query) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DictLookupPage(
          initialQuery: query.trim().isEmpty ? null : query.trim(),
        ),
      ),
    );
  }

  void _openAddContent() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ContentImportPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_settingsOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSettings();
      },
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final panelWidth = constraints.maxWidth * 0.75;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                AnimatedPositioned(
                  duration: AppMotion.durationSidebar,
                  curve: Curves.easeOutCubic,
                  left: _settingsOpen ? panelWidth : 0,
                  top: 0,
                  bottom: 0,
                  width: constraints.maxWidth,
                  child: _buildMainSurface(context),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_settingsOpen,
                    child: AnimatedOpacity(
                      opacity: _settingsOpen ? 1 : 0,
                      duration: AppMotion.durationSidebar,
                      curve: Curves.easeOutCubic,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _closeSettings,
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.26),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: AppMotion.durationSidebar,
                  curve: Curves.easeOutCubic,
                  left: _settingsOpen ? 0 : -panelWidth,
                  top: 0,
                  bottom: 0,
                  width: panelWidth,
                  child: const SettingsPanelFrame(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 主内容表面：全屏 ContentPage + 渐变遮罩 + 顶部「设置」+ 底部搜索输入行。
  Widget _buildMainSurface(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: ContentPage(searchQuery: _query)),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: AppOverlay.topFadeHeight,
          child: IgnorePointer(
            child: DecoratedBox(decoration: AppOverlay.topFade()),
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: AppOverlay.bottomScrimHeight(context),
          child: IgnorePointer(
            child: DecoratedBox(decoration: AppOverlay.bottomFade()),
          ),
        ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pageEdge,
                AppSizes.topChromeInset,
                AppSizes.pageEdge,
                0,
              ),
              child: Row(
                children: [
                  PillButton(
                    icon: Icons.menu_rounded,
                    label: '设置',
                    highlight: true,
                    onTap: _openSettings,
                  ),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pageEdge,
                0,
                AppSizes.pageEdge,
                12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      PillButton(
                        icon: Icons.add_rounded,
                        label: '添加',
                        highlight: true,
                        onTap: _openAddContent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SearchInputField(
                    onChanged: (q) => setState(() => _query = q),
                    onSubmit: _openLookup,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 底部搜索输入框（SoWhat 输入条同款胶囊：chip 底 + 70% 描边 + 全圆角）。
///
/// 职责只有两个：输入时实时过滤「最近阅读」（搜内容），回车把词带到
/// 查词页（查单词）。内部不放附加 / 发送按钮。
class _SearchInputField extends StatefulWidget {
  const _SearchInputField({required this.onChanged, required this.onSubmit});

  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;

  @override
  State<_SearchInputField> createState() => _SearchInputFieldState();
}

class _SearchInputFieldState extends State<_SearchInputField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const mode = ModeThemes.theme1;
    return Material(
      color: mode.chipBackground,
      shape: FoldShape(
        borderRadius: mode.inputRadius,
        side: BorderSide(
          color: mode.chipBorder.withValues(alpha: 0.7),
          width: 1,
        ),
        fold: mode.cornerFold,
      ),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      clipBehavior: Clip.antiAlias,
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: mode.text, fontSize: 15),
        cursorColor: mode.primary,
        onChanged: widget.onChanged,
        onSubmitted: (v) {
          final q = v.trim();
          if (q.isEmpty) return;
          _controller.clear();
          widget.onChanged('');
          widget.onSubmit(q);
        },
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(
          hintText: '查单词 · 搜内容',
          hintStyle: TextStyle(color: mode.textMuted, fontSize: 13),
          filled: false,
          prefixIcon: Icon(Icons.search, size: 20, color: mode.textMuted),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: '清空',
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: mode.textMuted,
                ),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                },
              );
            },
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
      ),
    );
  }
}