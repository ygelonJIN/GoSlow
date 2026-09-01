import 'package:flutter/material.dart';

import '../app/design/design.dart';
import '../app/theme/fold_decoration.dart';
import '../app/theme/mode_theme.dart';
import '../data/models/word_entry.dart';

/// 当前考纲选择底部面板（闪卡页「考纲词」下方使用）。
///
/// 返回选中的 tag（[kAllTag] 或某个考纲 tag）；取消返回 null。
Future<String?> showExamTagPicker(
  BuildContext context,
  String current,
) async {
  const mode = ModeThemes.love;
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => CutBox(
      fold: mode.cornerFold,
      color: mode.cardBackground,
      borderRadius: BorderRadius.vertical(top: mode.cardRadius.topLeft),
      border: Border.all(color: mode.cardBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 24,
          offset: const Offset(0, -6),
        ),
      ],
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: AppInsets.sectionHeader.copyWith(
                bottom: AppSpacing.sm,
              ),
              child: Text(
                '选择当前考纲',
                style: Theme.of(ctx).textTheme.titleMedium
                    ?.copyWith(color: AppColors.ink),
              ),
            ),
            ListTile(
              title: const Text(
                '全部考纲',
                style: TextStyle(color: AppColors.ink),
              ),
              trailing: current == kAllTag
                  ? Icon(
                      Icons.check,
                      color: Theme.of(ctx).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.pop(ctx, kAllTag),
            ),
            for (final tag in kExamTags)
              ListTile(
                title: Text(
                  kExamTagNames[tag] ?? tag,
                  style: const TextStyle(color: AppColors.ink),
                ),
                trailing: current == tag
                    ? Icon(
                        Icons.check,
                        color: Theme.of(ctx).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.pop(ctx, tag),
              ),
          ],
        ),
      ),
    ),
  );
}
