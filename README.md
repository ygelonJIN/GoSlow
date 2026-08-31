# GoSlow

> 一个"效率很低"的单词学习 App。不为了背而背，把单词学习嫁接进真实的阅读、观影、听歌场景。

- 平台：Android + iOS（Flutter 3.47.0 / Dart 3.13.0）
- 词库：ECDICT 考纲词，离线内置（`assets/dict.db`，14MB），无 AI、无账号、无云同步
- 设计文档：[docs/开发文档.md](docs/开发文档.md)

## 环境（已对齐 SoWhat 方案）

| 项 | 位置 |
|---|---|
| SDK | 本机 `/Users/jinfeiqing/fvm/versions/3.47.0`（绝不复制进项目） |
| 软链 | `.fvm/versions/stable → 本机 SDK` |
| 版本锁定 | `.fvmrc = {"flutter":"stable"}` |
| 统一入口 | `tool/flutter`（build/run/pub）、`tool/analyze`（静态检查） |
| 隔离缓存 | `.fvm/pub-cache`、`.fvm/analyze-home` |

> 沙箱限制：编辑器内嵌终端写不了用户主目录，因此 `tool/flutter` 的写操作命令
> （pub get / build / run / clean）必须在 **Terminal / iTerm** 跑；
> `tool/analyze` 在 Cursor 内可直接跑（HOME 已钉到工作区）。

## 首次初始化（在 Terminal 执行一次）

```bash
# 生成 Android/iOS 原生壳（沙箱内无法执行 flutter 命令，必须在 Terminal）
./tool/flutter create . --project-name goslow --org com.goslow --platforms android,ios

# 拉取依赖（已用 SDK dart 拉过一次，Terminal 里再跑一遍确保完整）
./tool/flutter pub get
```

## 日常命令

```bash
# 一律在 Terminal
./tool/flutter pub get
./tool/flutter run --release -d <device-id>
./tool/flutter build ios
./tool/flutter clean

# 静态检查，Cursor 内可直接跑
./tool/analyze
./tool/analyze lib

# 高亮引擎验证（纯 Dart，Cursor 内可直接跑）
dart run tool/check_engine.dart

# 词库重建（ECDICT CSV → assets/dict.db，Python 直跑）
python3 tool/build_dict.py

# Cursor 内嵌终端里跑 flutter 命令（沙箱受限时用，假 FLUTTER_ROOT + 软链 SDK）
./tool/flutter-sandbox test
./tool/flutter-sandbox analyze
```

## 目录结构

```
lib/
├─ main.dart
├─ app/                  # 路由、主题、全局配置（当前考纲、高亮样式）
├─ data/
│  ├─ dict/              # 词典访问层（查询、词形还原、高亮引擎、内存索引）
│  ├─ models/            # 词条模型
│  ├─ db/                # 用户数据库（M2 起）
│  ├─ parsers/           # txt/epub/srt/lrc 解析器（M2/M5）
│  └─ repositories/      # 各领域仓储（M2 起）
├─ features/
│  ├─ content/           # 内容列表 + 阅读器 + 查词页（M1 已有查词）
│  ├─ flashcard/         # 识别式闪卡（M3）
│  ├─ favorite/          # 收藏夹（M5）
│  ├─ stats/             # 统计（M4）
│  ├─ celebration/       # 里程碑庆祝（M4）
│  └─ settings/          # 设置（M1 已有考纲切换）
└─ shared/               # 通用组件（释义卡片等）
```

## 里程碑进度

| 阶段 | 状态 |
|---|---|
| M1 地基：词库转换 + 查询/词形还原 + 高亮引擎 + 基础导航/查词 UI | 代码已完成（analyze 零问题、测试 25/25），Terminal 待跑 `flutter pub get` + 真机首跑 |
| M2 内容高亮（粘贴文本 + .txt + 阅读器 + 点词面板 + 考纲/多色联动） | 代码已完成（analyze 零问题、测试 25/25） |
| M3 识别式闪卡（双入口：内容词/考纲词 + 认识/模糊/不认识 + 掌握度状态机 + 结算页 + 闪卡设置） | 代码已完成（analyze 零问题、测试 52/52） |
| M3.5 记忆引擎升级（FSRS v4 间隔调度 + review_events 事件溯源 + 撤销 + 统计页 + 词库增强字段） | 代码已完成（analyze 零问题、测试 52/52 + Python 12/12） |
| M4 收获感（统计 + 庆祝） | 统计页 + 里程碑庆祝页（认识 100/500/1000/2000/3000/5000 词，闪卡结算后自动弹出 + 设置页历史回顾）已完成（analyze 零问题、测试 67/67） |
| M5 内容扩展（epub/srt/lrc + 周报） | epub/srt/lrc 解析器 + 结构化阅读器 + 点词三档自评 + 内容词自动收集 + 收藏缩略图已全部完成，周报/月报待开发 |
| M6 打磨（备份/恢复 + 分享） | 待开发 |
