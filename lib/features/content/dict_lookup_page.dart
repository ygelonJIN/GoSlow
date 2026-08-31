import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design/design.dart';
import '../../data/dict/dict_database.dart';
import '../../data/dict/dict_providers.dart';
import '../../data/models/word_entry.dart';
import '../../shared/empty_state.dart';
import '../../shared/meaning_card.dart';

/// 离线查词页 v2.0 — Paper Editorial。
/// 纸底 + 14px 圆角 1px 描边搜索框 + 细线分隔建议列表。
class DictLookupPage extends ConsumerStatefulWidget {
  const DictLookupPage({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<DictLookupPage> createState() => _DictLookupPageState();
}

class _DictLookupPageState extends ConsumerState<DictLookupPage> {
  final _controller = TextEditingController();
  List<WordEntry> _suggestions = const [];
  LookupResult? _result;
  bool _notFound = false;
  bool _suggesting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery case final q?) {
      _controller.text = q;
      _submit(q);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onChanged(String text) async {
    final q = text.trim();
    if (q.isEmpty) {
      setState(() {
        _suggestions = const [];
        _suggesting = false;
        _result = null;
        _notFound = false;
      });
      return;
    }
    final lookup = ref.read(lookupProvider);
    final list = await lookup.prefix(q, limit: 15);
    if (!mounted || _controller.text.trim() != q) return;
    setState(() {
      _suggestions = list;
      _suggesting = true;
      _result = null;
      _notFound = false;
    });
  }

  Future<void> _submit(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    final lookup = ref.read(lookupProvider);
    final result = await lookup.lookup(q);
    if (!mounted) return;
    setState(() {
      _suggestions = const [];
      _suggesting = false;
      _result = result;
      _notFound = result == null;
    });
  }

  void _pick(WordEntry entry) {
    _controller.text = entry.word;
    _controller.selection = TextSelection.collapsed(offset: entry.word.length);
    _submit(entry.word);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('查单词')),
      body: Column(
        children: [
          Padding(
            padding: AppInsets.search,
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              onSubmitted: _submit,
              autofocus: widget.initialQuery == null,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '输入英文单词，支持变形词（如 got）',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
              ),
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_suggesting && _suggestions.isNotEmpty) {
      return _SuggestionList(
        entries: _suggestions,
        query: _controller.text.trim(),
        onPick: _pick,
        onSearchAll: () => _submit(_controller.text),
      );
    }
    if (_result case final r?) {
      return ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        children: [
          MeaningCard(
            entry: r.entry,
            leadingWord: r.matched != r.entry.word ? r.matched : null,
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            child: Text(
              'M2 起：此处将展示上下文原句、发音、收藏与加入学习队列',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
          ),
        ],
      );
    }
    if (_notFound) {
      return const EmptyState(
        icon: Icons.search_off,
        title: '词库里没有这个词',
        subtitle: '试试别的拼写，或检查是否属于所选考纲',
      );
    }
    return const SizedBox.shrink();
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    required this.entries,
    required this.query,
    required this.onPick,
    required this.onSearchAll,
  });

  final List<WordEntry> entries;
  final String query;
  final ValueChanged<WordEntry> onPick;
  final VoidCallback onSearchAll;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: AppInsets.pageVertical,
      itemCount: entries.length + 1,
      separatorBuilder: (_, _) => const Divider(indent: AppSpacing.xl),
      itemBuilder: (context, i) {
        if (i == entries.length) {
          return ListTile(
            dense: true,
            leading: const Icon(Icons.search, size: AppSpacing.xl, color: AppColors.inkMuted),
            title: Text(
              '搜索“$query”的完整结果',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                  ),
            ),
            onTap: onSearchAll,
          );
        }
        final e = entries[i];
        return ListTile(
          dense: true,
          title: Text(e.word, style: const TextStyle(color: AppColors.ink)),
          subtitle: e.translation.isNotEmpty
              ? Text(
                  e.translation.replaceAll(RegExp(r'\\n|\n'), ' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                )
              : null,
          onTap: () => onPick(e),
        );
      },
    );
  }
}
