import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design/design.dart';
import '../../app/theme/fold_decoration.dart';
import '../../app/theme/mode_theme.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/feedback_dialog.dart';
import '../../shared/overlay_page.dart';

/// 粘贴文本导入页：标题 + 正文，保存后回到内容列表/直接打开阅读器由调用方决定。
/// 全屏内容 + 浮层控制：底部通栏主色「保存」按钮悬浮在渐变之上。
class PastePage extends ConsumerStatefulWidget {
  const PastePage({super.key});

  @override
  ConsumerState<PastePage> createState() => _PastePageState();
}

class _PastePageState extends ConsumerState<PastePage> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) {
      FeedbackDialog.show(context, message: '请粘贴英文内容');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(contentRepoProvider);
      final id = await repo.insert(
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text,
        sourceType: 'paste',
      );
      ref.read(contentVersionProvider.notifier).state++;
      if (!mounted) return;
      Navigator.of(context).pop<int>(id);
      FeedbackDialog.show(context, message: '已保存，去阅读吧', icon: Icons.check_circle_rounded, title: '已保存');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const mode = ModeThemes.love;
    return OverlayPage(
      title: '粘贴文本',
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: _SaveButton(mode: mode, saving: _saving, onTap: _save),
      ),
      child: ListView(
        padding: EdgeInsets.only(
          top: AppOverlay.topInset(context),
          bottom: AppOverlay.bottomInset(context) + 60 + AppSpacing.xl,
        ),
        children: [
          Padding(
            padding: AppInsets.pageHorizontal.copyWith(bottom: AppSpacing.sm),
            child: _InputField(
              mode: mode,
              controller: _titleCtrl,
              hint: '标题（可选，留空自动从正文取首行）',
              textInputAction: TextInputAction.next,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
          Padding(
            padding: AppInsets.pageHorizontal.copyWith(bottom: AppSpacing.sm),
            child: _InputField(
              mode: mode,
              controller: _bodyCtrl,
              hint: '粘贴英文段落 / 文章…\n\n保存后自动高亮当前考纲词，点词看释义',
              maxLines: 14,
              minLines: 8,
              alignLabelWithHint: true,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部通栏主色保存按钮（主色胶囊）。
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.mode,
    required this.saving,
    required this.onTap,
  });

  final ModeTheme mode;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = mode.actionChipForeground;
    return Material(
      color: saving ? mode.primary.withValues(alpha: 0.7) : mode.primary,
      shape: FoldShape(borderRadius: mode.chipRadius, fold: mode.cornerFold),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: mode.cornerFold ? null : mode.chipRadius,
        customBorder: mode.cornerFold
            ? const FoldShape(
                borderRadius: BorderRadius.zero,
                side: BorderSide.none,
                fold: true,
              )
            : null,
        onTap: saving ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (saving)
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              else
                Icon(Icons.check_rounded, size: 18, color: foreground),
              const SizedBox(width: 7),
              Text(
                saving ? '保存中…' : '保存',
                style: TextStyle(
                  color: foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 胶囊输入框（与 SoWhat 输入条同语言：chipBackground 底 + 全圆角）。
class _InputField extends StatelessWidget {
  const _InputField({
    required this.mode,
    required this.controller,
    required this.hint,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines = 1,
    this.alignLabelWithHint = false,
    this.borderRadius,
  });

  final ModeTheme mode;
  final TextEditingController controller;
  final String hint;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int minLines;
  final bool alignLabelWithHint;

  /// 覆盖默认全圆胶囊圆角（多行正文用卡片圆角）。
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: mode.chipBackground,
      shape: FoldShape(
        borderRadius: borderRadius ?? mode.inputRadius,
        side: BorderSide(
          color: mode.chipBorder.withValues(alpha: 0.55),
          width: 1,
        ),
        fold: mode.cornerFold,
      ),
      clipBehavior: Clip.antiAlias,
      child: TextField(
        controller: controller,
        textInputAction: textInputAction,
        maxLines: maxLines,
        minLines: minLines,
        style: TextStyle(color: mode.text, fontSize: 14),
        cursorColor: mode.primary,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: mode.textMuted, fontSize: 12.5),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          alignLabelWithHint: alignLabelWithHint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
