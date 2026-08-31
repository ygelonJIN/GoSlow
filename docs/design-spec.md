# GoSlow 设计规范 v2.1 — Paper Editorial

> 方向：A · 纸感文学（Paper Editorial · 2026-08-31 定版）
> 目标：为「慢内容」服务。所有视觉决策都围绕**可长时间阅读**——不刺眼、不焦虑、不游戏化。
> 原则：Token 驱动，禁止页面内硬编码颜色 / 间距 / 圆角 / 字阶 / 动效。
> 预览：`docs/ui-previews/preview-a-paper-editorial.html`（4 屏真机对照）· 总览 `docs/ui-previews/index.html`

> **v2.4 → v2.5 变更摘要**
> - 主界面改「**全屏内容 + 浮层控制**」：四页内容全屏铺底，上下边缘被渐隐遮罩覆盖；顶部标题浮层（每 Tab 小标题 + 页名，内容页带「+」）与底部导航浮层直接压在渐变之上（对齐 §16）。
> - 四 Tab 各自不再有 `AppBar` / `Scaffold`：顶部标题统一由 `AppShell` 浮层渲染，页面用 `AppOverlay.topInset / bottomInset` 做内容避让。
> - 底部 `NavigationBar` 改透明背景，悬浮在底部渐隐遮罩之上；移除原先的 `line` 顶部描边，由渐变承担内容分离。
> - 新增 Token `AppOverlay`（顶部/底部渐隐高度 + 内容避让），`CircleAction` 提为共享组件。

> **v2.3 → v2.4 变更摘要**
> - 新增 §15 点词学习组件（词性释义行 / 三档自评 / 收藏缩略卡），M5 交互改版已按此落代码。
> - `MeaningCard` 释义改为**按词性一行**（中英文同构）：每行 `n.` / `vt.` 前缀 + 释义文本，替代整块文本与蓝框。
> - 点词面板动作区改为「朗读 + 收藏 + 认识/模糊/不认识」三档自评，直接落 FSRS；移除「加入学习 / 标记已认识 / 原句」。

> **v2.2 → v2.3 变更摘要**
> - 新增 §14 结构化内容阅读组件（章节标题 / 时间轴行 / 时间标签），M5 阅读器已按此落代码。

> **v2.1 → v2.2 变更摘要**
> - 新增 §13 庆祝组件规范（里程碑庆祝页 / 里程碑徽章 / 分享卡），M4 庆祝页已按此落代码。
> - `AppColors.accent` 作为庆祝主色（暖金），大标题 + 数据行 + 徽章均为同一 accent 家族。

> **v2.0 → v2.1 变更摘要**
> - 新增 §11 统计组件规范（迷你统计行 / 占比条 / 趋势竖条 / 高阶数据行 / 掌握分布行 / **月度年度汇总行**），统计页与闪卡结算页已按此落代码。
> - `MeaningCard` 新增释义例句行（§9 表格补充一行）：`format_quote` 14 accent + 斜体 inkMuted。
> - 闪卡 Result 结算页新增「本回合评级」占比条与「记忆变化（FSRS）」统计行（平均 S/R 变化），沿用 §11 组件。

> **v1.0 → v2.0 变更摘要**
> - 定版 A 方向：暖纸底色 + 油墨文字 + 单一蓝高亮 + 纯白卡片 0 阴影 + 细线分隔，呈现“文学期刊”质感。
> - 调色板收敛：`paper #FAF8F5 / card #FFFFFF / ink #1A1C1E / muted #8B8680 / line #EDE9E3 / seed #3B6EA5 / seedSoft #E8EEF6 / accent #C9A96E`，单色高亮笔触 `seed 13%/35%`。
> - 卡片增加 1px 线框（`line`），圆角与内边距对齐预览；搜索框、底部面板、导航全面对齐预览 A。
> - 新增手机外壳 `radius phone 28` 与阅读高亮装饰 Token，规范与代码 `lib/app/design/*` + `lib/app/theme.dart` 已同步落位。

---

## 1. 设计哲学

| 原则 | 含义 | 落地 |
|---|---|---|
| **纸感 Paper First** | 暖纸底色 + 油墨文字，像一本书 | 背景 `paper` 暖白，卡片纯白，文字用 ink |
| **克制 Restraint** | 一个主色完成 90% 表达 | 主色 `seed` 仅用于高亮/焦点/主按钮，余下靠排版与留白区分层级 |
| **呼吸 Breathing** | 慢，大留白 | 4pt 基准间距，区块间至少 `xl(20)`，卡片内至少 `lg(16)` |
| **识别优先 Recognition** | 词是主角，释义卡是配角 | 词头最大字阶，释义次之，标签最弱；阅读高亮用“淡底 + 细下划线”而非彩色字 |

A 方向的关键词：**文学期刊、安静、可久读**。拒绝强网格、拒绝大色块、拒绝游戏化动效。

---

## 2. 色彩 Color

### 2.1 调色板

基于单一种子色生成 Material 3 色系，再叠加语义别名。**页面禁止直接使用 `Color(0x...)`。**

| Token | 值 | 用途 |
|---|---|---|
| `AppColors.seed` | `0xFF3B6EA5` | 种子色，生成 `ColorScheme`，唯一主色 |
| `AppColors.paper` | `0xFFFAF8F5` | 页面背景，AppBar / NavigationBar 同色 |
| `AppColors.card` | `0xFFFFFFFF` | 卡片 / 搜索框 / 底部面板 |
| `AppColors.ink` | `0xFF1A1C1E` | 正文主色（比 `onSurface` 更暖的墨） |
| `AppColors.inkMuted` | `0xFF8B8680` | 次要说明 |
| `AppColors.inkFaint` | `ColorScheme.outlineVariant` | 禁用 / 占位图标 |
| `AppColors.line` | `0xFFEDE9E3` | 1px 细线、卡片描边、分割线 |
| `AppColors.seedSoft` | `0xFFE8EEF6` | 淡蓝底（标签、入口图标底） |
| `AppColors.highlight` | `seed` | 单色高亮笔触 |
| `AppColors.highlightBg` | `seed @ 0.13` | 阅读高亮淡底 |
| `AppColors.highlightBorder` | `seed @ 0.35` | 阅读高亮下划线 |
| `AppColors.accent` | `0xFFC9A96E` | 暖金点缀（庆祝、强调，小面积） |

多色高亮调色板（`HighlightPalette.multi`，仅设置 → 多色模式启用）：

```
zk    0xFF8FA7C8   muted slate-blue
gk    0xFF9DB5A0   muted sage
cet4  0xFFD9B56A   muted amber
cet6  0xFFD18B6A   muted terracotta
ky    0xFF8E9BB5   muted periwinkle
ielts 0xFF7FB8A8   muted teal
toefl 0xFFB89AC5   muted mauve
gre   0xFFC49A8A   muted clay
```
> 全部控制在 `s < 35, l 55–70` 区间，避免在纸底上过饱和。文字仍用 ink 叠半透明底，不用彩色字。

### 2.2 语义

```
paper  → scaffold / appBar / navigationBar 背景
card   → 卡片 / 搜索框 / 面板 背景
ink    → 标题 / 正文
inkMuted → 说明 / 占位 / 区块标题
line   → 描边 / 分割线
seed   → 高亮 / 主按钮 / 选中态
seedSoft → 标签底 / 图标底
```

### 2.3 禁止项

- 禁止 `Colors.blue / Colors.grey` 直接裸用
- 禁止 `withOpacity` 魔法数，统一用 `withValues(alpha:)` 且仅允许 `0.08 / 0.10 / 0.12 / 0.13 / 0.35 / 0.50` 六档（定义于 `AppColors.alpha*`）

---

## 3. 字型 Typography

系统字体（SF Pro / Roboto），不引入额外字库以保持包体积。预览中衬线标题（Cormorant Garamond / Noto Serif SC）仅为气质参考，Flutter 侧用字重与字距表达同等层级。

| Token | 样式 | 用途 |
|---|---|---|
| `display` | `headlineMedium 28/32 w700` | 词头（MeaningCard / 闪卡大词） |
| `title` | `titleMedium 16/22 w600` | 卡片标题、AppBar |
| `appBarSmall` | `labelSmall 10/12 w600 tracking .12em` | AppBar 上方小标题（GOSLOW / FLASHCARD） |
| `body` | `bodyMedium 14/21 w400` | 中文释义、正文 |
| `bodySmall` | `bodySmall 12/18 w400` | 次要说明、提示 |
| `label` | `labelLarge 13/16 w600 tracking .08em` | 区块标题 |
| `caption` | `labelSmall 11/14 w500` | 标签 Chip |
| `phonetic` | `bodySmall 12/16 w400` | 音标，色 `primary` |

> 行高统一通过 `height` 指定；禁止在页面 `TextStyle(fontSize: 11)` 硬编码，全部走 `Theme.textTheme`。

---

## 4. 间距 Spacing

4pt 基准，**页面禁止出现裸数字 `Padding(20,16...)`**，全部引用 `AppSpacing`。

| Token | 值 | 场景 |
|---|---|---|
| `xxs` | 4 | 图标与文字微距 |
| `xs` | 6 | Chip 间距 |
| `sm` | 8 | 同组元素内距、卡片垂直间距 |
| `md` | 12 | 卡片内段落间距 |
| `lg` | 16 | 卡片外边距、页面水平 padding |
| `xl` | 20 | 卡片内大 padding、区块标题 |
| `xl2` | 24 | 页面垂直大距 |
| `xl3` | 32 | 空状态垂直节奏 |
| `xl4` | 48 | 大空状态图标 |

常用组合已封装为 `EdgeInsets` 常量：`AppInsets.card`、`AppInsets.page`、`AppInsets.section`、`AppInsets.search`。

---

## 5. 圆角 Radius

| Token | 值 | 场景 |
|---|---|---|
| `xs` | 8 | Chip、次级容器 |
| `sm` | 12 | 按钮前置图标底 | 
| `sm2` | 14 | 搜索框（预览 A：14） |
| `md` | 16 | 卡片 |
| `lg` | 20 | 底部释义面板 |
| `phone` | 28 | 手机外壳预览（仅预览用，App 内不用） |
| `pill` | 999 | 胶囊、进度条 |

禁止 `BorderRadius.circular(10)` / `14` 等随意值（`sm2` 除外，已收口）。

---

## 6. 阴影 Elevation

GoSlow 几乎无阴影，靠**纸张分层 + 1px 线框**区分：

| Level | 值 | 用途 |
|---|---|---|
| `0` | 0 | 卡片常态（纯白 + 1px `line` 描边） |
| `1` | 1 | 按压态 |
| `2` | 3 | 底部释义面板、Sheet（叠加 `line` 描边 + 柔和阴影） |

禁止 `elevation: 2` 随手写，引用 `AppElevation.level0`。

---

## 7. 动效 Motion

| Token | 值 | 用途 |
|---|---|---|
| `durationShort` | 150ms | 图标切换、Chip |
| `durationMedium` | 250ms | 卡片展开、页面切换 |
| `durationLong` | 350ms | 底部面板、Sheet |
| `curveStandard` | `easeInOutCubic` | 通用 |
| `curveEmphasized` | `easeOutCubic` | 进入 |

---

## 8. 布局 Layout

- 页面最大内容宽度不限（手机竖屏），水平安全区 `AppSpacing.lg(16)`。
- 列表统一 `ListView(padding: AppInsets.pageVertical)`，卡片间垂直间距 `AppSpacing.sm(8)` 由 `CardTheme.margin` 统一下发。
- 空状态居中，图标 `56` + 标题 `titleMedium` + 说明 `bodySmall`，垂直节奏 `xs(6)` / `xl(20)`。
- 阅读页：段落 `body 13.5/26`，标题 `display 22/26`，高亮为 `highlightBg + highlightBorder` 组合。

---

## 9. 组件 Component

所有组件样式由 `AppTheme.light()` 统一收口，页面只描述结构。

| 组件 | 规范（对齐预览 A） |
|---|---|
| **AppBar** | 透明纸底 `paper`，无阴影，标题 `titleLarge w600`，小标题 `appBarSmall` 10px muted |
| **NavigationBar** | 纸底，指示器 `primary 0.12`，高度 64，描边 `line` 顶部 1px |
| **Card** | 白底 `card`，`radius md(16)`，`elevation 0`，**1px `line` 描边**，`margin lg(16) / sm(8)` |
| **SearchField** | 填充 `card`，`radius sm2(14)`，**1px `line` 描边**，无阴影，前缀 search，后缀 clear，hint 用 `inkMuted` |
| **Chip** | `radius xs(8)`，`primary 0.08` 底，文字 `caption`，前景 `primary` |
| **SectionHeader** | `padding xl(20) / md(12)-xs(8)`，文字 `label` + `inkMuted`，大写间距 `.08em` |
| **EmptyState** | 图标 `outlineVariant 56`，标题 `titleMedium`，说明 `bodySmall + outline`，主按钮用 `FilledButton` |
| **ListTile 分隔线** | `Divider` 色 `line`，缩进 `xl(20)` |
| **阅读高亮** | 容器 `highlightBg 0.13` + `Border(bottom: 2px highlightBorder 0.35)` + `radius 3`，文字 `ink` 加粗 |
| **底部释义面板** | 白底，`radius lg(20)` 顶部，`line` 顶部描边，拖拽条 `line 36×4`，阴影 `level2` |
| **进度条** | 轨道 `line` 4px，填充 `seed`，`radius pill` |
| **释义例句行** | `format_quote_outlined` 14 `accent` 前缀 + 斜体 `bodySmall` `inkMuted`，行距 1.5（M3.5 新增） |

---

## 10. 图标 Iconography

- 统一 `outlined / filled` 成对使用（未选 outlined，已选 filled）
- 尺寸：导航 24，卡片前置 `CircleAvatar 20-22`，空状态 56，搜索 20
- 颜色：主操作 `primary`，禁用 `outlineVariant`，次要 `outline` / `inkMuted`
- 入口卡片前置底：`seedSoft`，前景 `seed`

---

## 11. 统计组件（M3.5 新增 · 统计页 `features/stats`）

> 统计页遵循全页纸感：无游戏化动效、无强网格。图表不引入第三方依赖，
> 用**等宽竖条**表达趋势（高度 = 数值占比），颜色只用 `primary / accent / inkMuted / line` 四档。

| 组件 | 规范 |
|---|---|
| **迷你统计行** | 与设置页 `_MiniStat` 同构：值 `titleMedium ink`，标签 `bodySmall 11px inkMuted`，列间 1px `line` 分隔（32 高） |
| **占比条** | 轨道 `line` 6px `radius pill`，填充对应色（`primary`/`accent`/`inkMuted`），左侧标签 64 宽 `bodyMedium ink`，右侧百分比 52 宽右对齐 `bodySmall inkMuted` |
| **趋势竖条** | 高 120 容器，每根竖条 8–84px，`primary` 填充，透明度随数值分档（≥0.8 → `alphaHighlightBorder`，否则 `alphaHighlightBg`），顶部数值 9px `inkMuted`，最多 14 根 |
| **月度/年度汇总行** | 周期名 64 宽（`bodyMedium ink`，`26年8月`/`2026年` 格式）+ 认识率条（同占比条）+ 右侧 `N次 · M%` 96 宽右对齐 `bodySmall inkMuted` |
| **高阶数据行** | 标题 + 值同行（`bodyMedium` / `titleMedium ink`），下方说明 `bodySmall inkMuted`，行间 `Divider` 色 `line` |
| **掌握分布行** | 8px 圆点色标（`primary`/`accent`/`inkMuted`/`line`）+ 标签 `bodyMedium` + 计数 `titleMedium` |

---

## 12. 使用约束

1. 新页面必须先查本规范，未覆盖的场景**先补规范再写 UI**。
2. 任何 `Color(0x...)`、`EdgeInsets.fromLTRB(20,16...)`、`BorderRadius.circular(14)`（除 `sm2` 外）、`TextStyle(fontSize: 11)` 出现在页面层均为违规，CI 阶段由 `tool/analyze` 拦截。
3. 暗色模式暂不启用，Token 已预留 `AppColors.paperDark` 扩展位；预览 F（Midnight Library）可作为后续夜读模式参考，不纳入 v2.0。

---

## 13. 庆祝组件（M4 新增 · 庆祝页 `features/celebration`）

> 庆祝是"收获感"的高光时刻，但仍守纸感：**无撒花动效、无强对比色**。
> 主色只用 `accent` 暖金 + `ink / inkMuted / line`，大面积留白，靠"大标题 + 数据 + 一句总结"完成仪式感。

| 组件 | 规范 |
|---|---|
| **里程碑徽章** | `CircleAvatar` 48（`radius lg` 级容器内）或图标 56，`accent` 前景 + `accent @ 0.13` 底（`alphaHighlightBg`），用 `emoji_events` / `auto_awesome` 系图标 |
| **庆祝大标题** | `display` 字阶（28/32 w700），`ink`，居中；上缀 `appBarSmall` 小标题「MILESTONE」`accent` 大字距 |
| **达成数据行** | 复用 §11 迷你统计行：值 `titleMedium ink`，标签 `bodySmall 11px inkMuted`，列间 1px `line` 分隔 |
| **收获总结卡** | 白卡 `line` 描边，`format_quote_outlined` 14 `accent` 前缀 + `bodyMedium` `ink` 斜体引语，居中留白 `xl(20)` |
| **分享卡** | 白卡 1px `line` 描边 + `radius md(16)`，内为大标题 + 达成数据 + 日期，右侧/下方「分享」按钮 `accent` 主色 |
| **触发入口** | 闪卡结算后检测新里程碑 → 整页庆祝（可返回）；设置页「里程碑」入口看历史 |

---

## 14. 结构化内容阅读组件（M5 新增 · 阅读器 `reader_page`）

> 内容分两类渲染：纯文本段落（粘贴/txt/md）走 §4 段落规格；结构化内容（epub 章节 / srt/lrc 时间轴）按本节。

| 组件 | 规范 |
|---|---|
| **信息条** | 白卡上置 1px `line` 描边信息条：`seedSoft 0.08` 底 + `primary` 14 图标（章节 `menu_book` / 字幕 `closed_caption` / 歌词 `music_note`）+ `bodySmall inkMuted` 计数文案 + 右侧模式标签（`labelSmall 10px primary`） |
| **章节标题** | `titleMedium 17px w600 ink`，章节正文跟随；章节间间距 `lg(16)` |
| **时间轴行** | 左侧时间标签（`seedSoft 0.08` 底 + `primary 10px` 文本 + `line` 描边 + `radius xs`）+ 右侧高亮文本，顶部对齐 |
| **分节高亮** | 每节独立高亮（局部偏移），点词面板复用 §13 底部释义面板 |

---

## 15. 点词学习组件（M5 交互改版 · 释义卡 + 点词面板 + 收藏页）

> 点词 = 学习：点高亮词 → 释义卡（词性一行）→ 直接三档自评落 FSRS。
> 收藏页改缩略卡，点击从下往上弹完整卡。

### 15.1 词性释义行（`MeaningCard` 中英文同构）

| 行 | 规范 |
|---|---|
| 词头 | 单词 `headlineMedium ink`（沿用） |
| 音标 | `bodySmall primary`（沿用） |
| **中文释义行** | 每行一个词性：词性前缀 `labelSmall w600 primary`（如 `n.` `vt.` `a.`），后接释义 `bodyMedium ink height 1.6`；行距 `xs(6)`；无词性前缀的行（如 `[医]` 特殊行）整行 `bodyMedium ink` |
| **英文释义行** | 同中文结构（词性前缀 + 英文释义），与中文释义之间用 `Divider` 分隔 |
| 无释义 | 词库无中英释义时显示 `bodySmall inkMuted`「词库未收录释义」 |

### 15.2 三档自评（点词面板动作区 / 闪卡底部）

| 档位 | 规范 |
|---|---|
| 认识 ✅ | `primary` 实底按钮（`fg card`） |
| 模糊 😐 | `accent` 淡底按钮（`bg accent 0.13` / `border accent 0.35` / `fg ink`） |
| 不认识 ❌ | `card` 底按钮（`border line` / `fg inkMuted`） |

三档等宽并排（`Row + Expanded`），点击直接写 FSRS（`recordFlashcardReview`），不翻面。

### 15.3 收藏缩略卡（`favorite_page`）

| 组件 | 规范 |
|---|---|
| **缩略卡** | 白卡 1px `line` 描边：单词 `bodyMedium w600 ink` + 音标 `bodySmall primary` + 首行中文释义 `bodySmall inkMuted` 单行省略；右侧收藏星 `seed` 20 |
| **展开浮窗** | 点击缩略卡 → `showModalBottomSheet`（同 §13 底部释义面板：`radius lg` 顶部 + `line` 描边），内含完整 `MeaningCard` + 三档自评 + 朗读 + 取消收藏 |

---

## 16. 全屏内容 + 浮层控制（M_ 新增 ·AppShell 主界面）

> 主界面布局从「标准 Scaffold + 底部导航条」改为**全屏内容 + 浮层控制**，
> 对齐 SoWhat 全屏页（BattleScreen / MemoryScreen）模式：内容全屏铺底、
> 上下边缘由渐隐遮罩覆盖，顶部标题浮层与底部导航浮层直接压在渐变之上，
> 内容滚动到浮层下方时柔和淡出。

### 16.1 层级（自底向上）

1. **全屏内容**：`IndexedStack` 承载四个 Tab（内容 / 闪卡 / 收藏 / 设置），常驻不销毁。
2. **顶部渐隐遮罩**：`paper → 透明`，高度 `AppOverlay.topFadeHeight(160)`，`IgnorePointer`。
3. **底部渐隐遮罩**：`paper → 透明`，高度 `AppOverlay.bottomFadeHeight(180)`，`IgnorePointer`。
4. **顶部标题浮层**：`SafeArea` + 每 Tab 小标题（`appBarSmall`）+ 页名（`titleLarge`）；
   内容页右侧带 `CircleAction`「+」（跳转 `PastePage`），其余 Tab 无动作。
5. **底部导航浮层**：`NavigationBar`（透明背景）直接压在底部渐隐之上。

### 16.2 内容避让（四 Tab 页面）

- 四 Tab 页面不再自带 `AppBar` / `Scaffold`，直接返回内容列表。
- 顶部避让：`AppOverlay.topInset(context)` = 状态栏 + `topContentInset(88)`。
- 底部避让：`AppOverlay.bottomInset(context)` = 底部安全区 + `bottomContentInset(80)`。
- `ListView` / `SingleChildScrollView` 用以上两个 inset 作上下 padding，水平仍遵循各自
  组件规范（搜索框 `AppInsets.search`、卡片 `CardTheme.margin` 等）。
- 空态：包一层上下 inset 的 `Padding`，在可视区间内居中。
- 闪卡运行 / 结算态：用 inset 代替原 `SafeArea`，让进度头落在标题下方、评级按钮落在导航上方。

### 16.3 渐变遮罩参数

| 层 | 高度 | 颜色（bottom→top / top→bottom） | 目的 |
|---|---|---|---|
| 顶部 | 160 | `paper 1 → 0.9 → 0` | 内容滚入标题浮层下方柔和淡出 |
| 底部 | 180 | `paper 1 → 0.85 → 0` | 内容滚入导航浮层下方柔和淡出 |

透明度档位属渐变专用值，收口在 `AppOverlay`（页面层不得见 0.9 / 0.85 等魔法数）。

### 16.4 共享组件

- **`CircleAction`**（`lib/shared/circle_action.dart`）：30×30 墨底圆（`ink`）+ 纸色图标 16，
  顶部浮层标题栏右侧动作按钮。从 `content_page` 提升为共享。
- 禁止页面重新内联等价按钮。

### 16.5 底部导航

- `NavigationBarThemeData.backgroundColor = Colors.transparent`（见 §9 覆盖），
  不再有 `line` 顶部描边；内容与导航的分离由底部渐隐承担。
- 指示器 / 文字样式沿用 §9（`primary 0.12` 指示器、`primary/inkMuted` 文字）。

