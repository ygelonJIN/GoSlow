import 'package:goslow/shared/meaning_card.dart';
import 'package:test/test.dart';

void main() {
  group('parseMeaningLines（数据源按字面 \\n 分隔词性行）', () {
    test('中文释义：字面 \\n 被当作换行，拆成多个词性行', () {
      // 与 assets/dict.db 实际存储一致：行分隔是「反斜杠 + n」两个字符。
      final lines = parseMeaningLines(
        r'vt. 放弃, 抛弃, 遗弃, 使屈从, 沉溺, 放纵\nn. 放任, 无拘束, 狂热',
      );
      expect(lines, hasLength(2));
      expect(lines[0].pos, 'vt.');
      expect(lines[0].text, '放弃, 抛弃, 遗弃, 使屈从, 沉溺, 放纵');
      expect(lines[1].pos, 'n.');
      expect(lines[1].text, '放任, 无拘束, 狂热');
    });

    test('真实换行与 \\r\\n 同样被正确拆分', () {
      final crlf = parseMeaningLines('n. 光\r\nvt. 点燃');
      expect(crlf, hasLength(2));
      expect(crlf.map((l) => l.pos), ['n.', 'vt.']);

      final lf = parseMeaningLines('n. 苹果\nvi. 生长');
      expect(lf, hasLength(2));
    });

    test('无词性行（[医]/变形说明）整体作释义', () {
      final lines = parseMeaningLines(r'n. 苹果, 家伙\n[医] 苹果');
      expect(lines[0].pos, 'n.');
      expect(lines[0].text, '苹果, 家伙');
      expect(lines[1].pos, isEmpty);
      expect(lines[1].text, '[医] 苹果');

      final inflection = parseMeaningLines(r'run的过去式和过去分词\n[计] 运行');
      expect(inflection[0].pos, isEmpty);
      expect(inflection[0].text, 'run的过去式和过去分词');
      expect(inflection[1].text, '[计] 运行');
    });

    test('复合词性不截断（vt.vi. / vi.vt.）', () {
      final lines = parseMeaningLines(r'vt.vi. (使)自动化\n[计] 自动化');
      expect(lines[0].pos, 'vt.vi.');
      expect(lines[0].text, '(使)自动化');
      expect(lines[1].pos, isEmpty);
    });

    test('& 连接复合词性（pron. & a. / p. pr. & vb. n.）', () {
      final pron = parseMeaningLines(
        r'pron. & a. The form of the objective and the possessive',
      );
      expect(pron.single.pos, 'pron. & a.');
      expect(pron.single.text, 'The form of the objective and the possessive');

      final pp = parseMeaningLines(r'p. pr. & vb. n. of Discomfort');
      expect(pp.single.pos, 'v.');
      expect(pp.single.text, 'of Discomfort');
    });

    test('空行被忽略', () {
      final lines = parseMeaningLines(r'n. 光\n\n\nvt. 点燃\n');
      expect(lines, hasLength(2));
      expect(lines.map((l) => l.pos), ['n.', 'vt.']);
    });

    test('英文释义：多个同词性 v. 行各自保留', () {
      final lines = parseMeaningLines(
        r'n. the trait of lacking restraint\nv. forsake, leave behind\n'
        r'v. give up with the intent of never claiming again',
      );
      expect(lines.map((l) => l.pos), ['n.', 'v.', 'v.']);
      expect(lines[2].text, 'give up with the intent of never claiming again');
    });

    test('英文释义缩写映射为中文习惯词性（s./r./imp./p.）', () {
      final lines = parseMeaningLines(
        r's. forsaken by owner or inhabitants\nr. forward\np. of Discomfort',
      );
      expect(lines[0].pos, 'a.');
      expect(lines[1].pos, 'adv.');
      expect(lines[2].pos, 'v.');
    });

    test('纯空白输入返回空列表', () {
      expect(parseMeaningLines(''), isEmpty);
      expect(parseMeaningLines('   \n '), isEmpty);
    });
  });
}