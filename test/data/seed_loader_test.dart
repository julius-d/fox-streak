import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/seed_loader.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';

import 'test_helpers.dart';

String seedDoc({
  String title = 'Seed',
  String createdBy = 'teacher',
  List<Map<String, dynamic>>? items,
}) => jsonEncode({
  'format': 'foxstreak-set',
  'version': 1,
  'title': title,
  'description': '',
  'createdBy': createdBy,
  'items':
      items ??
      [
        {'type': 'phone', 'prompt': 'P', 'answer': '0171'},
      ],
});

void main() {
  late AppDatabase db;
  late SetsRepository sets;
  late FakeClock clock;

  setUp(() {
    db = makeTestDb();
    clock = FakeClock(kTestToday);
    sets = SetsRepository(db, clock);
  });

  tearDown(() async {
    await db.close();
  });

  group('SeedLoader', () {
    test('imports all seeds into empty DB', () async {
      final assets = {
        'a.json': seedDoc(title: 'A'),
        'b.json': seedDoc(title: 'B'),
      };
      final loader = SeedLoader(
        sets,
        loadString: (p) async => assets[p]!,
        assetPaths: ['a.json', 'b.json'],
      );
      expect(await loader.ensureSeeded(today: kTestToday), 2);
      final titles = (await sets.getAllSets()).map((e) => e.title).toSet();
      expect(titles, {'A', 'B'});
    });

    test('does nothing when DB already has sets', () async {
      await sets.createSet(title: 'Existing', createdBy: 'teacher');
      var loads = 0;
      final loader = SeedLoader(
        sets,
        loadString: (p) async {
          loads++;
          return seedDoc();
        },
        assetPaths: ['a.json'],
      );
      expect(await loader.ensureSeeded(today: kTestToday), 0);
      expect(loads, 0);
      expect(await sets.getAllSets(), hasLength(1));
    });

    test('skips corrupt seeds, still imports the good ones', () async {
      final loader = SeedLoader(
        sets,
        loadString: (p) async {
          if (p == 'bad.json') return 'not-json{';
          if (p == 'invalid.json') {
            return seedDoc(
              items: [
                {'type': 'phone', 'prompt': 'P', 'answer': '1'},
              ],
            );
          }
          return seedDoc(title: 'Good');
        },
        assetPaths: ['bad.json', 'invalid.json', 'good.json'],
      );
      expect(await loader.ensureSeeded(today: kTestToday), 1);
      expect((await sets.getAllSets()).single.title, 'Good');
    });

    test('bundled demo assets decode as valid v1 sets', () async {
      for (final path in kSeedAssetPaths) {
        final raw = await File(path).readAsString();
        final decoded = jsonDecode(raw);
        expect(decoded, isA<Map<String, dynamic>>());
        final id = await sets.importSetFromJson(
          Map<dynamic, dynamic>.from(decoded as Map<String, dynamic>),
          today: kTestToday,
        );
        expect(id, isPositive);
      }
      expect(await sets.getAllSets(), hasLength(4));
    });

    test(
      'demo_bundeslaender seed is 16 non-vocab choice items (#022)',
      () async {
        final raw = await File('assets/seed/demo_bundeslaender.foxstreak.json')
            .readAsString();
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final id = await sets.importSetFromJson(
          Map<dynamic, dynamic>.from(decoded),
          today: kTestToday,
        );
        final items = await sets.getItemsForSet(id);
        expect(items, hasLength(16));
        for (final item in items) {
          expect(item.type, 'choice');
          expect(item.promptLang, isNull);
          expect(item.answerLang, isNull);
          expect(item.choices, isNull);
        }
      },
    );

    test('demo_times_tables seed is 78 unique math choice facts, category '
        '"math" (#045)', () async {
      final raw = await File('assets/seed/demo_times_tables.foxstreak.json')
          .readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['category'], 'math');
      final id = await sets.importSetFromJson(
        Map<dynamic, dynamic>.from(decoded),
        today: kTestToday,
      );
      expect((await sets.getSetById(id))?.category, 'math');
      final items = await sets.getItemsForSet(id);
      expect(items, hasLength(78));
      final facts = <String>{};
      for (final item in items) {
        expect(item.type, 'choice');
        expect(item.promptLang, isNull);
        expect(item.answerLang, isNull);
        expect(item.choices, isNull);
        facts.add(item.prompt);
      }
      // No duplicate/commutative facts (3 × 5 and 5 × 3 are the same fact).
      expect(facts, hasLength(78));
    });
  });
}
