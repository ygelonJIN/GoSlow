/// 词条模型：对应 dict.db 中 words 表的一行。
class WordEntry {
  WordEntry({
    required this.id,
    required this.word,
    this.phonetic = '',
    this.translation = '',
    this.definition = '',
    this.pos = '',
    this.collins = 0,
    this.oxford = 0,
    this.bnc = 0,
    this.frq = 0,
    this.exchange = '',
    this.example = '',
    this.tenses = '',
    this.synonyms = '',
    this.etymology = '',
    this.tags = const [],
  });

  final int id;
  final String word;
  final String phonetic;
  final String translation;
  final String definition;
  final String pos;
  final int collins;
  final int oxford;
  final int bnc;
  final int frq;
  final String exchange;

  /// 例句（build_dict.py 从 detail.json 提取；旧词库可能缺失）。
  final String example;

  /// 时态变形 JSON（exchange 字段的解析版，build_dict.py 生成）。
  final String tenses;

  /// 近义词辨析 JSON（resemble.txt，可选）。
  final String synonyms;

  /// 词根词缀 JSON（wordroot.txt，可选）。
  final String etymology;

  /// 所属考纲标签；由查询层填充（非 const 构造场景），可变以便级联赋值。
  List<String> tags;

  /// 是否属于某个考纲。
  bool hasTag(String tag) => tags.contains(tag);

  /// 中英释义都为空时视为无释义（如纯网络释义词条）。
  bool get hasMeaning => translation.isNotEmpty || definition.isNotEmpty;

  /// 是否有可展示的例句（去除空白后的非空文本）。
  bool get hasExample => example.trim().isNotEmpty;

  factory WordEntry.fromRow(Map<String, Object?> row) {
    return WordEntry(
      id: (row['id'] as int?) ?? 0,
      word: (row['word'] as String?) ?? '',
      phonetic: (row['phonetic'] as String?) ?? '',
      translation: _decodeDbText(row['translation']),
      definition: _decodeDbText(row['definition']),
      pos: (row['pos'] as String?) ?? '',
      collins: (row['collins'] as int?) ?? 0,
      oxford: (row['oxford'] as int?) ?? 0,
      bnc: (row['bnc'] as int?) ?? 0,
      frq: (row['frq'] as int?) ?? 0,
      exchange: (row['exchange'] as String?) ?? '',
      example: (row['example'] as String?) ?? '',
      tenses: (row['tenses'] as String?) ?? '',
      synonyms: (row['synonyms'] as String?) ?? '',
      etymology: (row['etymology'] as String?) ?? '',
    );
  }
}

/// 词典文本里存的行分隔是字面的 `\n`（反斜杠 + n），读取时统一转为真实换行，
/// 供展示层直接按行处理（见 build_dict.py 原样写入 ECDICT 的 translation/definition）。
String _decodeDbText(Object? raw) => (raw as String? ?? '')
    .replaceAll(r'\r\n', '\n')
    .replaceAll(r'\n', '\n')
    .replaceAll('\r\n', '\n');

/// 当前考纲的可选值，与 dict.db 的 word_tags 表一致。
/// 展示顺序即设置页里考纲切换的展示顺序。
const List<String> kExamTags = [
  'zk', // 中考
  'gk', // 高考
  'cet4', // 四级
  'cet6', // 六级
  'ky', // 考研
  'ielts', // 雅思
  'toefl', // 托福
  'gre', // GRE
];

const String kAllTag = 'all';

/// 「全部考纲」的展示名（数据层唯一出处，UI 禁止重复硬编码）。
const String kAllTagLabel = '全部考纲';

/// 考纲代码 → 中文名。
const Map<String, String> kExamTagNames = {
  'zk': '中考',
  'gk': '高考',
  'cet4': '四级',
  'cet6': '六级',
  'ky': '考研',
  'ielts': '雅思',
  'toefl': '托福',
  'gre': 'GRE',
};

/// 单个考纲代码的展示名；未收录时回退代码本身。
String examTagName(String tag) => kExamTagNames[tag] ?? tag;

/// 一组已选考纲的展示文案：含「全部」（或空集）时显示 [kAllTagLabel]，
/// 否则用「 / 」连接各考纲中文名。
String formatExamTagSelection(Set<String> tags) {
  if (tags.isEmpty || tags.contains(kAllTag)) return kAllTagLabel;
  return tags.map(examTagName).join(' / ');
}
