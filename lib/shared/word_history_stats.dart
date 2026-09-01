import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/design/design.dart';
import '../data/providers/app_providers.dart';

/// 单词历史自评统计行：出现过 N 次 · 认识 X% · 模糊 Y% · 不认识 Z%。
///
/// 闪卡学习页正面、内容里点高亮词的面板共用；数据来自 review_events
/// 事件表（都是之前自评留下的记录）。没有记录时显示「还没有自评记录」。
class WordHistoryStats extends ConsumerWidget {
  const WordHistoryStats({super.key, required this.word});

  final String word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(wordReviewStatsProvider(word.toLowerCase()));
    final base = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.inkMuted,
          height: 1.4,
        );
    return statsAsync.when(
      loading: () => Text('—', style: base),
      error: (_, _) => Text('—', style: base),
      data: (s) {
        if (s.isEmpty) {
          return Text('还没有自评记录', style: base);
        }
        return Text(
          '出现过 ${s.total} 次 · 认识 ${s.knownPct}% · 模糊 ${s.familiarPct}% · 不认识 ${s.unknownPct}%',
          textAlign: TextAlign.center,
          style: base?.copyWith(fontSize: 11),
        );
      },
    );
  }
}
