# GoSlow

> 一个“效率很低”的单词学习 App。不为了背而背，把单词学习嫁接进真实的阅读、观影、听歌场景。

- 平台：Android + iOS（Flutter 3.47.0 / Dart 3.13.0）
- 词库：ECDICT 考纲词，离线内置（`assets/dict.db`，约 14MB），无 AI、无账号、无云同步
- 设计文档：[docs/开发文档.md](docs/开发文档.md)

## 当前状态

GoSlow 目前已经完成核心学习闭环，重点能力包括：

- 离线词典查询、词形还原、高亮引擎
- 内容导入与阅读：粘贴文本、`.txt`、`.epub`、`.srt`、`.lrc`
- 阅读器内点词：查词、收藏、三档自评、自动收集内容词
- 识别式闪卡：内容词 / 考纲词、认识 / 模糊 / 不认识、自评驱动复习调度
- FSRS v4 复习引擎：间隔调度、事件溯源、撤销、统计聚合
- 统计与庆祝：学习总览、趋势、月度 / 年度总结、里程碑庆祝
- 设置与主题：考纲切换、复习轮数、自动朗读、高亮颜色配置

当前未完成的产品项主要是：

- M6-A 备份 / 恢复
- M6-B 分享

## 环境（已对齐 SoWhat 方案）

| 项 | 位置 |
|---|---|
| SDK | 本机 `/Users/jinfeiqing/fvm/versions/3.47.0`（不复制进项目） |
| 软链 | `.fvm/versions/stable → 本机 SDK` |
| 版本锁定 | `.fvmrc = {"flutter":"stable"}` |
| 统一入口 | `tool/flutter`（build/run/pub）、`tool/analyze`（静态检查） |
| 隔离缓存 | `.fvm/pub-cache`、`.fvm/analyze-home` |

> 沙箱限制：编辑器内嵌终端写不了用户主目录，因此 `tool/flutter` 的写操作命令
>（`pub get` / `build` / `run` / `clean`）建议在 **Terminal / iTerm** 跑；
> `tool/analyze` 在 Cursor 内可直接跑（`HOME` 已钉到工作区）。

## 首次初始化（在 Terminal 执行一次）

```bash
# 生成 Android/iOS 原生壳（沙箱内无法执行 flutter 命令，必须在 Terminal）
./tool/flutter create . --project-name goslow --org com.goslow --platforms android,ios

# 拉取依赖
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

# 词库重建（ECDICT CSV → assets/dict.db）
python3 tool/build_dict.py

# Cursor 内嵌终端里跑 flutter 命令（沙箱受限时用）
./tool/flutter-sandbox test
./tool/flutter-sandbox analyze
```

## 目录结构

```text
lib/
├─ main.dart
├─ app/                  # 路由、主题、全局配置（当前考纲、高亮样式）
├─ data/
│  ├─ dict/              # 词典访问层（查询、词形还原、高亮引擎、内存索引）
│  ├─ models/            # 词条、复习与内容模型
│  ├─ db/                # 用户数据库
│  ├─ parsers/           # txt / epub / srt / lrc 解析器
│  └─ repositories/      # 各领域仓储
├─ features/
│  ├─ content/           # 内容列表 + 阅读器 + 查词页
│  ├─ favorite/          # 收藏夹
│  ├─ stats/             # 统计
│  ├─ celebration/       # 里程碑庆祝
│  └─ settings/          # 设置
└─ shared/               # 通用组件
```

## 功能概览

### 1. 离线词库

- ECDICT 考纲词内置在应用中
- 支持词形还原和短语匹配
- 支持按考纲标签筛选高亮

### 2. 内容学习

- 导入粘贴文本、`.txt`、`.epub`、`.srt`、`.lrc`
- 阅读器内高亮考纲词与生词
- 点词后可直接查看释义、收藏、加入复习
- 内容词会自动进入学习统计

### 3. 复习系统

- 识别式闪卡入口
- 认识 / 模糊 / 不认识三档自评
- FSRS v4 调度
- 支持撤销最近一次自评
- 复习数据全部落库，统计从事件表聚合

### 4. 统计与庆祝

- 总览数据
- 认识率趋势
- 月度 / 年度总结
- 熟词转化率、失忆率等高阶指标
- 认识词数里程碑庆祝

### 5. 设置

- 切换当前考纲
- 配置复习每轮张数
- 开关自动朗读
- 配置各考纲高亮颜色

## 里程碑进度

| 阶段 | 状态 |
|---|---|
| M1 地基：词库转换 + 查询 / 词形还原 + 高亮引擎 + 基础导航 / 查词 UI | 已完成 |
| M2 内容高亮：粘贴文本 + `.txt` + 阅读器 + 点词面板 + 考纲 / 多色联动 | 已完成 |
| M3 识别式闪卡：双入口 + 三档自评 + 掌握度状态机 + 结算页 + 闪卡设置 | 已完成 |
| M3.5 记忆引擎升级：FSRS v4 + `review_events` 事件溯源 + 撤销 + 统计页 + 词库增强字段 | 已完成 |
| M4 收获感：统计 + 庆祝 | 已完成 |
| M5 内容扩展：`.epub` / `.srt` / `.lrc` + 结构化阅读器 + 点词三档自评 + 内容词自动收集 + 收藏缩略图 | 已完成 |
| M6 打磨：备份 / 恢复 + 分享 | 待开发 |

## 数据存储

### 用户数据库 `app.db`

当前核心表包括：

- `contents`
- `word_states`
- `word_queue`
- `review_events`
- `milestones`

### 只读词库 `dict.db`

- 词条与词形数据
- 考纲标签
- 词典释义与高亮所需索引

## 开发建议

- 先完成 M6：备份 / 恢复
- 再补分享
- 最后做发布前收尾检查

如果只是临时排查问题，优先跑：

```bash
./tool/analyze
./tool/analyze lib
```
