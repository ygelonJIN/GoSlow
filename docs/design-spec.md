# GoSlow 设计规范 v3.0 — 全局视觉体系

> 方向：暖纸底 + 草木绿主色 + 全圆角 + 霞鹜文楷（源自 SoWhat「主题一」模式，代码级迁移）· 2026-09-01 定版
> 目标：为「慢内容」服务。所有视觉决策都围绕**可长时间阅读**——不刺眼、不焦虑、不游戏化。
> 原则：Token 驱动，禁止页面内硬编码颜色 / 间距 / 圆角 / 字阶 / 动效。

> **跨项目对齐（2026-09-02）**：本项目的布局几何（页面模板 / 遮罩 / 侧栏 / 动画）与
> IGotYou 完全同构，数值源头统一在 `lib/app/design/app_sizes.dart`（几何令牌）与
> `docs/design-spec.md` §5。三主题的独立完整规范文档（含共享几何表，无代码映射）
> 不随项目维护——见本机桌面《三主题设计规范》文件夹。
> 改布局先改几何令牌表，几何数值一律不得私自调整。

> **v3.0 变更摘要（Paper Editorial → 全局主题）**
> - 主题统一：暖纸底 `#FAF3E6` + 草木绿主色 `#4F7B49` + 全圆角 + 单字体 `LXGW WenKai`。
> - 移除旧的三选一方向（Paper / Swiss / Wabi 等），全局只保留一套主题。
> - 引入 `ModeTheme` 令牌体系（`lib/app/theme/mode_theme.dart`）与 `FoldShape / CutBox` 形状系统（`fold_decoration.dart`）。
> - 引入 `PillButton`（胶囊按钮）与 `FeedbackDialog`（主题化提示弹窗），SnackBar 全部下线。
> - 新增 `OverlayPage` 全屏页骨架：全屏内容 + 上下渐变遮罩 + 顶部返回胶囊 + 底部悬浮条。
> - 底部导航改为独立悬浮胶囊按钮（复用 `PillButton`，与「添加/收藏」同款）。
> - 空态改用圆形图标瓷片（seedSoft 底 + 圆 64）。

---

## 1. 设计哲学

| 原则 | 含义 | 落地 |
|---|---|---|
| **暖纸 First** | 暖纸底色 + 草木绿主色，像一本温润的植物手帐 | 背景 `paper` 暖白，卡片浅草绿，文字深褐绿 |
| **克制 Restraint** | 一个主色完成 90% 表达 | 主色 `primary` 仅用于高亮/焦点/主按钮，余下靠排版与留白区分层级 |
| **呼吸 Breathing** | 慢，大留白 | 4pt 基准间距，区块间至少 `xl(20)`，卡片内至少 `lg(16)` |
| **识别优先 Recognition** | 词是主角，释义卡是配角 | 词头最大字阶，释义次之，标签最弱；阅读高亮用“淡底 + 细下划线”而非彩色字 |

---

## 2. 色彩 Color

### 2.1 调色板

页面禁止直接使用 `Color(0x...)`，统一引用 `AppColors` 或 `ModeThemes.love`。

| Token | 值 | 用途 |
|---|---|---|
| `primary` | `0xFF4F7B49` | 草木绿：主色 / 高亮 / 主按钮 / 选中态 |
| `background` | `0xFFFAF3E6` | 暖纸底：整页背景 |
| `cardBackground` | `0xFFF1F7EC` | 浅草绿：卡片 / 底部面板 / 弹窗 |
| `text` | `0xFF2F3A2A` | 深褐绿：标题 / 正文 |
| `textMuted` | `0xFF6F7D68` | 弱化文字 / 区块标题 |
| `cardMuted` | `0xFF5F7057` | 卡片内说明文字 |
| `cardBorder` | `0x5E4F7B49` | 半透明绿描边（37% alpha） |
| `line` | `0xFFDCE6D3` | 细线 / 轨道 / 分割线 |
| `seedSoft` | `0xFFE7F0E0` | 图标瓷片底 / 标签底 |
| `accent` | `0xFFC9A96E` | 暖金点缀（庆祝 / 里程碑，小面积） |

> 多色高亮调色板（`HighlightPalette.multi`，仅设置 → 多色模式启用）保留原 muted 色系。

### 2.2 语义

```
background → scaffold 背景
cardBackground → 卡片 / 面板 / 弹窗 背景
primary → 高亮 / 主按钮 / 选中态 / 阅读高亮
text → 标题 / 正文
textMuted → 说明 / 占位 / 区块标题
cardBorder → 卡片描边
line → 分割线 / 进度条轨道
seedSoft → 图标底 / 标签底
accent → 庆祝点缀
```

### 2.3 禁止项

- 禁止 `Colors.blue / Colors.grey` 直接裸用
- 禁止 `withOpacity`，统一用 `withValues(alpha:)`
- 透明度档位仅限：`0.08 / 0.10 / 0.12 / 0.13 / 0.35 / 0.55 / 0.75`

---

## 3. 字型 Typography

全局唯一字体：**LXGW WenKai（霞鹜文楷）**，由 `ModeThemes.love.themeData.fontFamily` 驱动。

| Token | 样式 | 用途 |
|---|---|---|
| `display` | `headlineMedium 28/32 w700` | 词头（MeaningCard / 闪卡大词） |
| `title` | `titleMedium 16/22 w600` | 卡片标题、AppBar |
| `appBarSmall` | `labelSmall 10/12 w600 tracking .12em` | 顶部浮层小字（GOSLOW / FLASHCARD） |
| `body` | `bodyMedium 14/21 w400` | 中文释义、正文 |
| `bodySmall` | `bodySmall 12/18 w400` | 次要说明、提示 |
| `label` | `labelLarge 13/16 w600 tracking .08em` | 区块标题 |
| `caption` | `labelSmall 11/14 w500` | 标签 Chip |
| `phonetic` | `bodySmall 12/16 w400` | 音标，色 `primary` |

---

## 4. 间距 / 圆角 / 阴影 / 动效

沿用 4pt 基准（`AppSpacing` / `AppInsets`）与 `AppRadius`，关键差异：

| Token | 值 | 场景 |
|---|---|---|
| `cardRadius` | 26 | 卡片 / 底部面板（全圆角，来自 love） |
| `chipRadius` | 999 | 胶囊按钮 / 搜索框 / 主按钮 |
| `inputRadius` | 999 | 输入条全圆角 |
| 卡片阴影 | `black @ 0.10` blur 18 | SoWhat 卡片语言（替代旧 0 阴影） |
| 按钮阴影 | `black @ 0.16` | PillButton / 底部导航按钮 |
| 阅读正文 | `readingFontSize 15` / `readingLineHeight 26` | 阅读器段落 / 高亮文本 |

按钮尺寸只保留两档，页面层一律引用 `AppSpacing` 令牌，禁止再写裸数值：

| 档位 | Token | 值 | 场景 |
|---|---|---|---|
| **标准胶囊** | `pillVertical / pillHorizontal / pillIcon / pillGap / pillFontSize` | 10 / 16 / 图标 16 / 6 / 13.5 | 收藏、添加内容、底部导航、SegmentedPills、当前考纲选择、考纲 chips |
| **强调主按钮** | `primaryButtonVertical / primaryButtonHorizontal / primaryButtonIcon / primaryButtonFontSize` | 14 / 20 / 图标 18 / 15 | 学习 / 复习、保存、下一张、再来一轮（与 FilledButton 主题同参数） |

动效沿用 `AppMotion`（150 / 250 / 340 / 350ms，easeInOutCubic / easeOutCubic）。

---

## 5. 布局 Layout

### 5.1 主界面（AppShell）

- 全屏内容 + 浮层控制：ContentPage 全屏铺底，上下渐变遮罩覆盖。
- 顶部浮层：左上角「设置」胶囊（主色填充高亮态），SafeArea 下 16 / 8 / 16 / 0。
- 内容首条距顶 **140**（固定，自屏幕顶端，`AppSizes.contentTopInset`）。
- 顶部遮罩 170 / 底部遮罩 160 + 底部安全区；渐变 4 档
  （底 1 → 0.90 @34% → 0.48 @72% → 0），见 `AppOverlay.topFade / bottomFade`。
- 设置侧栏（3/4 面板）：从左侧滑入、占屏宽 75%，主页面右移只保留右侧约 1/4 可见，
  遮罩（黑 26%）覆盖可见区域、点击收起；动画 340ms `easeOutCubic`；
  面板内自带上下 surface 同色渐变遮罩（1 → 0.92 → 0，高 150 / 200）+ 顶部「设置」标题
  （SafeArea 16 / 8 / 16 / 8，20 / w600）。
- 侧栏开合由 boolean 状态即时驱动（点击即 setState → 动画立即开始，无二次动画延迟），
  禁止用 AnimationController 驱动可见性布尔（会导致收起延迟一整段动画）。
- 内容页是唯一学习入口：顶卡含「内容词总览 + 复习 / 收藏 + 当前考纲 + 内容词复习设置」；收藏、复习、已学完总结全部收敛在内容页。
- 底部一行浮层（SoWhat 输入条同构）：左侧搜索输入框（只做查单词 · 搜内容——输入实时过滤「最近阅读」，回车直达查词页）+ 右侧「添加」主色胶囊（打开添加内容页：粘贴文本 / 导入文件）。
- 内容为空时主页只留引导卡（加入口说明）。

### 5.2 全屏子页（OverlayPage）

新增页面一律复用 `lib/shared/overlay_page.dart`：

- 顶部：返回胶囊（PillButton）+ kicker 小字 + 标题 + 可选右侧动作。
- 上下：渐变遮罩（`AppOverlay.topFade / bottomFade`，4 档）；底部遮罩高度含底部安全区（与主页一致）。
- 底部：可选悬浮条（如粘贴页「保存」通栏主色胶囊）。
- 内容避让：`AppOverlay.topInset`（= 140 固定）/ `AppOverlay.bottomInset`。

---

## 6. 组件 Component

| 组件 | 规范 |
|---|---|
| **PillButton** | 胶囊：`chipBackground` 底 / `chipBorder` 55% 描边 / 主色填充高亮态，`lib/shared/pill_button.dart` |
| **RatingButton** | 三档自评（认识 / 模糊 / 不认识）唯一实现，支持 `dense` 紧凑态，`lib/shared/rating_button.dart` |
| **ActionPill** | 行内紧凑动作胶囊（朗读 / 收藏）：seedSoft 底 + line 描边，filled 态切主色淡底，`lib/shared/action_pill.dart` |
| **FeedbackDialog** | 主题化提示弹窗：卡片底 + 主色图标瓷片 + 「知道了」，`lib/shared/feedback_dialog.dart` |
| **CutBox / FoldShape** | 卡片 / 面板 / 弹窗的形状与描边系统，`lib/app/theme/fold_decoration.dart` |
| **Card** | 浅草绿底 `cardBackground` + `cardBorder` 1px 描边 + 柔和投影（elevation 2 / black 0.10） |
| **设置侧栏（SettingsPanelFrame）** | SoWhat 同款 3/4 面板：从左侧滑入占屏宽 75%，`surface` 底色 + 右缘细描边 + 投影，内部自带上下渐变遮罩 + 「设置」标题浮层（无关闭按钮，收起靠遮罩 / 系统返回），内容为紧凑版 SettingsContent（love 卡片语言），`lib/features/settings/settings_panel.dart` |
| **底部搜索输入框（_SearchInputField）** | SoWhat 输入条同款胶囊：`chipBackground` 底 + `chipBorder` 70% 描边 + 全圆角 + 柔和阴影；只做查单词 / 搜内容（输入实时过滤「最近阅读」，回车直达查词页），不放附加 / 发送按钮，`lib/app/app_shell.dart` |
| **SectionHeader** | `labelLarge` + `inkMuted` + `.08em` 字距 |
| **EmptyState** | 圆形图标瓷片（64，seedSoft 底）+ `titleMedium` + `bodySmall` 说明 |
| **阅读高亮** | `primary` 0.13 淡底 + 下划线 `primary` 0.35，文字加粗 |
| **底部释义面板** | CutBox：`cardBackground` 底 + `cardBorder` 描边 + 顶部 26 圆角 + 柔和投影 |
| **三档自评** | 认识=primary 实底 / 模糊=accent 13% 淡底 / 不认识=card 底 + line 描边 |

---

## 7. 使用约束

1. 新页面必须先查本规范，未覆盖的场景**先补规范再写 UI**。
2. 页面层禁止 `Color(0x...)` / 裸数值 / `BorderRadius.circular(10)` 等随意值。
3. 所有弹窗统一 FeedbackDialog / confirmDialog，禁止 SnackBar。
4. 新增全屏页复用 `OverlayPage`；新增按钮用 `PillButton` 或主题按钮。
5. 布局几何（边距 / 遮罩 / 侧栏 / 动画）一律引用 `AppSizes` / `AppOverlay` 令牌；
   需要新数值时**先写进桌面《三主题设计规范》总览的共享几何表**再改代码，两处同时提交。
6. 三主题的完整独立规范见桌面《三主题设计规范》（本项目 = 主题一）。
