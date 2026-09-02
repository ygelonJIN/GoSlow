import 'package:flutter/material.dart';

import '../../app/design/design.dart';
import '../../app/theme/mode_theme.dart';
import 'settings_page.dart';

/// 设置侧栏面板（占屏宽 75% / 3/4、全高、从左侧滑入）。
///
/// 结构与 IGotYou 设置面板一致：
/// - 底色 `surface`，右缘细描边 + 右缘投影；
/// - 不整体套 SafeArea：遮罩 / 阴影从屏幕顶端整条延伸，内容避开安全区
///   由 [SettingsContent] 自行让出（顶 = 状态栏 + 80，底 = 安全区 + 150）；
/// - 上下渐变遮罩与面板同色（surface 1 → 0.92 → 0），高 150 / 200；
/// - 顶部仅「设置」标题浮层（SafeArea 16 / 8 / 16 / 8，无关闭按钮，
///   收起靠遮罩点击 / 系统返回键）；
/// - 宽度由宿主传入（屏宽 75%），配合滑入动画整体平移。
class SettingsPanelFrame extends StatelessWidget {
  const SettingsPanelFrame({super.key});

  @override
  Widget build(BuildContext context) {
    const mode = ModeThemes.theme1;
    return Container(
      decoration: BoxDecoration(
        color: mode.surface,
        border: Border(
          right: BorderSide(
            color: mode.textMuted.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(8, 0),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 设置内容（全高滚动）。
          const Positioned.fill(child: SettingsContent()),

          // 顶部渐隐遮罩：与面板同色，内容滚动到「设置」标题下方时淡出。
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: AppSizes.settingsTopScrim,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: AppOverlay.surfaceTopFade(mode.surface),
              ),
            ),
          ),

          // 底部渐隐遮罩：与面板同色，滚动内容到底部时淡出。
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: AppSizes.settingsBottomScrim,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: AppOverlay.surfaceBottomFade(mode.surface),
              ),
            ),
          ),

          // 顶部浮层：仅「设置」标题（与主页「设置」胶囊同一水平线）。
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
                  AppSpacing.sm,
                ),
                child: Text(
                  '设置',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: mode.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}