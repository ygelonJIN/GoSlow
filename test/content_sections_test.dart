import 'package:goslow/data/db/app_database.dart';
import 'package:goslow/data/models/content_entry.dart';
import 'package:goslow/data/parsers/parsed_content.dart';
import 'package:goslow/data/repositories/content_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late AppDatabase appDb;
  late ContentRepository repo;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await AppDatabase.createSchema(db);
    appDb = AppDatabase.testInstance(() async => db);
    repo = ContentRepository(appDb);
  });

  tearDown(() => db.close());

  group('encode/decodeSections 往返', () {
    test('时间轴行保留 start/end', () {
      const sections = [
        ContentSection(text: 'Hello world', startMs: 1000, endMs: 4000),
        ContentSection(text: 'Second line', startMs: 5000),
      ];
      final decoded = decodeSections(encodeSections(sections));
      expect(decoded.length, 2);
      expect(decoded[0].text, 'Hello world');
      expect(decoded[0].startMs, 1000);
      expect(decoded[0].endMs, 4000);
      expect(decoded[1].startMs, 5000);
      expect(decoded[1].endMs, isNull);
      expect(decoded[1].isTimed, isTrue);
    });

    test('章节标题保留', () {
      const sections = [
        ContentSection(text: 'Chapter body', title: 'One'),
      ];
      final decoded = decodeSections(encodeSections(sections));
      expect(decoded.first.title, 'One');
      expect(decoded.first.isTimed, isFalse);
    });

    test('null / 空 / 非法 JSON 返回空', () {
      expect(decodeSections(null), isEmpty);
      expect(decodeSections(''), isEmpty);
      expect(decodeSections('not json'), isEmpty);
    });
  });

  group('ContentRepository 结构化入库', () {
    test('带 sections 入库后可读回', () async {
      const sections = [
        ContentSection(text: 'First line', startMs: 0, endMs: 2000),
        ContentSection(text: 'Second line', startMs: 2000, endMs: 4000),
      ];
      await repo.insert(
        title: 'My Movie',
        body: 'First line\nSecond line',
        sourceType: 'srt',
        sections: sections,
      );

      final all = await repo.listAll();
      expect(all.length, 1);
      final c = all.first;
      expect(c.sourceType, 'srt');
      expect(c.title, 'My Movie');
      expect(c.hasSections, isTrue);
      expect(c.sections.length, 2);
      expect(c.sections[0].startMs, 0);
      expect(c.sections[1].text, 'Second line');
      expect(c.displaySource, '字幕');
    });

    test('不带 sections 入库 → hasSections false', () async {
      await repo.insert(title: 'Note', body: 'plain', sourceType: 'paste');
      final all = await repo.listAll();
      expect(all.first.hasSections, isFalse);
      expect(all.first.wordCount, 1);
    });

    test('update 保留原 sections', () async {
      const sections = [ContentSection(text: 'only', startMs: 100)];
      final id = await repo.insert(
        title: 'T',
        body: 'only',
        sourceType: 'lrc',
        sections: sections,
      );
      await repo.update(id, title: 'T2', body: 'only');
      final c = await repo.byId(id);
      expect(c!.title, 'T2');
      expect(c.sections.length, 1);
    });

    test('最近阅读排序：touchOpened 后置顶', () async {
      final a = await repo.insert(title: 'A', body: 'a', sourceType: 'paste');
      final b = await repo.insert(title: 'B', body: 'b', sourceType: 'paste');
      final c = await repo.insert(title: 'C', body: 'c', sourceType: 'paste');

      // 初始按导入时间倒序：C, B, A。
      var all = await repo.listAll();
      expect([for (final x in all) x.id], [c, b, a]);
      expect(all.first.lastOpenedAt, isNull);

      // 打开 A → A 置顶；再打开 B → B 置顶。
      await repo.touchOpened(a);
      all = await repo.listAll();
      expect(all.first.id, a);
      expect(all.first.lastOpenedAt, isNotNull);

      await repo.touchOpened(b);
      all = await repo.listAll();
      expect(all.first.id, b);
      expect(all[1].id, a);
    });
  });
}
