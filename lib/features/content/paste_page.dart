import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design/design.dart';
import '../../data/providers/app_providers.dart';

/// 粘贴文本导入页：标题 + 正文，保存后回到内容列表/直接打开阅读器由调用方决定。
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请粘贴英文内容')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存，去阅读吧')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('粘贴文本'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
              ),
              child: _saving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('保存'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: AppInsets.pageVertical,
        children: [
          Padding(
            padding: AppInsets.search.copyWith(bottom: AppSpacing.sm),
            child: TextField(
              controller: _titleCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: '标题（可选，留空自动从正文取首行）'),
            ),
          ),
          Padding(
            padding: AppInsets.search,
            child: TextField(
              controller: _bodyCtrl,
              maxLines: 14,
              minLines: 8,
              decoration: const InputDecoration(
                hintText: '粘贴英文段落 / 文章…\n\n保存后自动高亮当前考纲词，点词看释义',
                alignLabelWithHint: true,
              ),
            ),
          ),
          Padding(
            padding: AppInsets.pageHorizontal,
            child: Text(
              '提示：整本书也可粘贴；超过 2 万字建议用“导入 .txt”',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
