import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/set_json_codec.dart';

import 'test_helpers.dart';

Map<dynamic, dynamic> validSetJson() => {
  'format': 'foxstreak-set',
  'version': 1,
  'title': 'Demo',
  'description': 'desc',
  'createdBy': 'teacher',
  'items': <dynamic>[
    {
      'type': 'choice',
      'prompt': 'Hund',
      'answer': 'dog',
      'direction': 'deEn',
      'choices': ['cat', 'mouse', 'bird'],
      'hint': '',
    },
    {'type': 'phone', 'prompt': 'Mama', 'answer': '01711234567'},
    {'type': 'date', 'prompt': 'Mamas Geburtstag', 'answer': '1985-05-14'},
  ],
};

void main() {
  group('decodeSetFromJson — happy path', () {
    test('decodes the spec example', () {
      final set = decodeSetFromJson(validSetJson(), today: kTestToday);
      expect(set.title, 'Demo');
      expect(set.createdBy, 'teacher');
      expect(set.items, hasLength(3));
      expect(set.items[0].direction, 'deEn');
      expect(set.items[0].choices, ['cat', 'mouse', 'bird']);
      expect(set.items[1].answer, '01711234567');
    });

    test('trims whitespace and normalises phone answers', () {
      final json = validSetJson();
      (json['items'] as List)[1] = {
        'type': 'phone',
        'prompt': '  Mama ',
        'answer': '0171 123-4567',
      };
      final set = decodeSetFromJson(json, today: kTestToday);
      expect(set.items[1].prompt, 'Mama');
      expect(set.items[1].answer, '01711234567');
    });

    test('accepts missing description/hint/choices', () {
      final set = decodeSetFromJson({
        'format': 'foxstreak-set',
        'version': 1,
        'title': 'T',
        'createdBy': 'parent',
        'items': [
          {
            'type': 'choice',
            'prompt': 'Hund',
            'answer': 'dog',
            'direction': 'enDe',
          },
        ],
      }, today: kTestToday);
      expect(set.description, '');
      expect(set.items.single.hint, '');
      expect(set.items.single.choices, isNull);
    });
  });

  group('decodeSetFromJson — rejection cases', () {
    Future<void> expectRejects(
      Map<dynamic, dynamic> json, [
      String? needle,
    ]) async {
      try {
        decodeSetFromJson(json, today: kTestToday);
        fail('expected SetImportException');
      } on SetImportException catch (e) {
        if (needle != null) {
          expect(e.message, contains(needle));
        }
      }
    }

    test('bad format / version', () async {
      final badFormat = validSetJson()..['format'] = 'other';
      await expectRejects(badFormat, 'format');
      final badVersion = validSetJson()..['version'] = 2;
      await expectRejects(badVersion, 'version');
      final missingVersion = validSetJson()..remove('version');
      await expectRejects(missingVersion, 'version');
    });

    test('bad title / createdBy / items shape', () async {
      await expectRejects({...validSetJson(), 'title': '  '}, 'title');
      await expectRejects({...validSetJson(), 'createdBy': '   '}, 'createdBy');
      await expectRejects({
        ...validSetJson(),
        'createdBy': 'x' * 51,
      }, 'createdBy');
      await expectRejects({...validSetJson(), 'items': 'nope'}, 'items');
      await expectRejects({
        ...validSetJson(),
        'description': 42,
      }, 'description');
    });

    test('accepts free-text creator names', () {
      for (final name in ['Mama', 'Ms. Smith', 'admin', 'teacher']) {
        final set = decodeSetFromJson({
          ...validSetJson(),
          'createdBy': name,
        }, today: kTestToday);
        expect(set.createdBy, name);
      }
    });

    test('unknown item type', () async {
      final json = validSetJson();
      (json['items'] as List)[0] = {
        'type': 'grammar',
        'prompt': 'x',
        'answer': 'y',
      };
      await expectRejects(json, 'unknown type');
    });

    test('empty prompt / answer', () async {
      final noPrompt = validSetJson();
      (noPrompt['items'] as List)[0] = {
        'type': 'choice',
        'prompt': ' ',
        'answer': 'dog',
        'direction': 'deEn',
      };
      await expectRejects(noPrompt, 'prompt');

      final noAnswer = validSetJson();
      (noAnswer['items'] as List)[1] = {
        'type': 'phone',
        'prompt': 'Mama',
        'answer': '',
      };
      await expectRejects(noAnswer, 'answer');
    });

    test('choice without direction; phone with direction', () async {
      final missingDir = validSetJson();
      ((missingDir['items'] as List)[0] as Map).remove('direction');
      await expectRejects(missingDir, 'direction');

      final phoneDir = validSetJson();
      (phoneDir['items'] as List)[1] = {
        'type': 'phone',
        'prompt': 'Mama',
        'answer': '01711234567',
        'direction': 'deEn',
      };
      await expectRejects(phoneDir, 'not allowed');
    });

    test('freeText accepts direction present or absent', () {
      final withDirection = validSetJson();
      (withDirection['items'] as List)[0] = {
        'type': 'freeText',
        'prompt': 'Hund',
        'answer': 'dog',
        'direction': 'deEn',
      };
      final set1 = decodeSetFromJson(withDirection, today: kTestToday);
      expect(set1.items[0].direction, 'deEn');

      final withoutDirection = validSetJson();
      (withoutDirection['items'] as List)[0] = {
        'type': 'freeText',
        'prompt': 'Capital of France',
        'answer': 'Paris',
      };
      final set2 = decodeSetFromJson(withoutDirection, today: kTestToday);
      expect(set2.items[0].direction, isNull);
    });

    test('freeText with choices is rejected', () async {
      final json = validSetJson();
      (json['items'] as List)[0] = {
        'type': 'freeText',
        'prompt': 'Hund',
        'answer': 'dog',
        'choices': ['cat'],
      };
      await expectRejects(json, 'choice-only');
    });

    test('bad phone answers', () async {
      for (final bad in ['12', '0' * 16, 'abc', '0171-abc']) {
        final json = validSetJson();
        (json['items'] as List)[1] = {
          'type': 'phone',
          'prompt': 'Mama',
          'answer': bad,
        };
        await expectRejects(json, 'phone');
      }
      // Empty answers are rejected at the non-empty check.
      final empty = validSetJson();
      (empty['items'] as List)[1] = {
        'type': 'phone',
        'prompt': 'Mama',
        'answer': '',
      };
      await expectRejects(empty, 'answer');
    });

    test('bad date answers (malformed / out of range / future)', () async {
      for (final bad in [
        '14.05.1985',
        '1899-12-31',
        '2026-10-12',
        '2021-02-30',
        '1985-5-14',
      ]) {
        final json = validSetJson();
        (json['items'] as List)[2] = {
          'type': 'date',
          'prompt': 'D',
          'answer': bad,
        };
        await expectRejects(json, 'date');
      }
    });

    test('non-object item and non-string hint', () async {
      final json = validSetJson();
      (json['items'] as List)[0] = 'nope';
      await expectRejects(json, 'must be an object');

      final badHint = validSetJson();
      (badHint['items'] as List)[0] = {
        'type': 'choice',
        'prompt': 'Hund',
        'answer': 'dog',
        'direction': 'deEn',
        'hint': 42,
      };
      await expectRejects(badHint, 'hint');
    });

    test('non-list choices and choices on phone', () async {
      final json = validSetJson();
      (json['items'] as List)[0] = {
        'type': 'choice',
        'prompt': 'Hund',
        'answer': 'dog',
        'direction': 'deEn',
        'choices': 'cat',
      };
      await expectRejects(json, 'choices');

      final phoneChoices = validSetJson();
      (phoneChoices['items'] as List)[1] = {
        'type': 'phone',
        'prompt': 'Mama',
        'answer': '01711234567',
        'choices': ['x'],
      };
      await expectRejects(phoneChoices, 'choice-only');
    });
  });

  group('encode / round-trip', () {
    test('encodeSetToJson validates then encodes', () {
      final map = encodeSetToJson(
        title: 'T',
        createdBy: 'learner',
        items: const [
          ShareItem(
            type: 'choice',
            prompt: 'Hund',
            answer: 'dog',
            direction: 'deEn',
          ),
        ],
        today: kTestToday,
      );
      expect(map['format'], 'foxstreak-set');
      expect(map['version'], 1);
      expect(
        () => encodeSetToJson(
          title: ' ',
          createdBy: 'learner',
          items: const [],
          today: kTestToday,
        ),
        throwsA(isA<SetImportException>()),
      );
    });

    test('decode(encode(x)) round-trips incl. json string', () {
      const original = ShareSet(
        title: 'Round',
        description: 'd',
        createdBy: 'teacher',
        items: [
          ShareItem(
            type: 'choice',
            prompt: 'Hund',
            answer: 'dog',
            direction: 'deEn',
            choices: ['cat', 'mouse'],
            hint: 'h',
          ),
          ShareItem(type: 'phone', prompt: 'M', answer: '01711234567'),
          ShareItem(type: 'date', prompt: 'B', answer: '1985-05-14'),
        ],
      );
      final viaString = decodeSetFromJson(
        jsonDecode(original.encode()) as Map<String, dynamic>,
        today: kTestToday,
      );
      expect(viaString.toJson(), original.toJson());
    });
  });
}
