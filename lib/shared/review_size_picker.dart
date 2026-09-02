import 'package:flutter/material.dart';

import '../app/design/design.dart';
import 'overlay_page.dart';
import 'pill_button.dart';

/// 复习每轮张数的候选项。
const List<int> kReviewSessionSizes = [10, 20, 30, 50, 80, 100];

/// 打开「复习每轮张数」选择页（全屏，与考纲选择页同款式），
/// 返回选中的张数；取消/返回 null。
Future<int?> showReviewSizePicker(BuildContext context, int current) {
  return Navigator.of(context).push(
    MaterialPageRoute<int>(
      builder: (_) => ReviewSizePickerPage(current: current),
    ),
  );
}

/// 复习每轮张数选择页：单选一个数字，全屏铺底 + 顶部/底部 50px 渐隐遮罩。
class ReviewSizePickerPage extends StatefulWidget {
  const ReviewSizePickerPage({super.key, required this.current});

  final int current;

  @override
  State<ReviewSizePickerPage> createState() => _ReviewSizePickerPageState();
}

class _ReviewSizePickerPageState extends State<ReviewSizePickerPage> {
  late int _selected = widget.current;

  void _confirm() {
    Navigator.of(context).pop(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OverlayPage(
      title: '复习每轮张数',
      kicker: 'REVIEW SIZE',
      topFadeHeight: 50,
      bottomFadeHeight: 50,
      bottomBar: PillButton(
        icon: Icons.check,
        label: '完成',
        highlight: true,
        onTap: _confirm,
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppOverlay.topInset(context),
          AppSpacing.lg,
          AppOverlay.bottomInset(context) + AppSpacing.xl3,
        ),
        children: [
          Text(
            '每轮抽几张内容词卡',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final size in kReviewSessionSizes) ...[
            Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                onTap: () => setState(() => _selected = size),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$size 张',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      Icon(
                        _selected == size
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 22,
                        color: _selected == size
                            ? scheme.primary
                            : AppColors.line,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}