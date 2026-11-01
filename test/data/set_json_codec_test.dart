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
      'promptLang': 'de',
      'answerLang': 'en',
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
      expect(set.items[0].promptLang, 'de');
      expect(set.items[0].answerLang, 'en');
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
            'promptLang': 'en',
            'answerLang': 'de',
          },
        ],
      }, today: kTestToday);
      expect(set.description, '');
      expect(set.items.single.hint, '');
      expect(set.items.single.choices, isNull);
    });
  });

  group('category (#045)', () {
    test('missing category defaults to vocab', () {
      final json = validSetJson()..remove('category');
      final set = decodeSetFromJson(json, today: kTestToday);
      expect(set.category, 'vocab');
    });

    test('an explicit category round-trips', () {
      final json = {...validSetJson(), 'category': 'math'};
      final set = decodeSetFromJson(json, today: kTestToday);
      expect(set.category, 'math');
      expect(set.toJson()['category'], 'math');
    });

    test('an unknown category is rejected', () {
      final json = {...validSetJson(), 'category': 'grammar'};
      expect(
        () => decodeSetFromJson(json, today: kTestToday),
        throwsA(isA<SetImportException>()),
      );
    });

    test('a non-string category is rejected', () {
      final json = {...validSetJson(), 'category': 42};
      expect(
        () => decodeSetFromJson(json, today: kTestToday),
        throwsA(isA<SetImportException>()),
      );
    });
  });

  group('identity (id, #101)', () {
    test('a missing set/item id decodes as null (backward compatible with '
        'hand-created/legacy sets)', () {
      final set = decodeSetFromJson(validSetJson(), today: kTestToday);
      expect(set.id, isNull);
      expect(set.items, everyElement(predicate<dynamic>((i) => i.id == null)));
    });

    test('a valid UUID set id and per-item id round-trip', () {
      final json = validSetJson();
      json['id'] = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';
      (json['items'] as List)[0] = {
        ...(json['items'] as List)[0] as Map,
        'id': 'a1b2c3d4-0000-4000-8000-000000000001',
      };
      final set = decodeSetFromJson(json, today: kTestToday);
      expect(set.id, '3f2504e0-4f89-41d3-9a0c-0305e82c3301');
      expect(set.items[0].id, 'a1b2c3d4-0000-4000-8000-000000000001');
      expect(set.items[1].id, isNull);
      final reEncoded = set.toJson();
      expect(reEncoded['id'], '3f2504e0-4f89-41d3-9a0c-0305e82c3301');
      expect(
        (reEncoded['items'] as List)[0]['id'],
        'a1b2c3d4-0000-4000-8000-000000000001',
      );
      expect((reEncoded['items'] as List)[1].containsKey('id'), isFalse);
    });

    test('a malformed set id is rejected', () {
      final json = {...validSetJson(), 'id': 'not-a-uuid'};
      expect(
        () => decodeSetFromJson(json, today: kTestToday),
        throwsA(isA<SetImportException>()),
      );
    });

    test('a malformed item id is rejected', () {
      final json = validSetJson();
      (json['items'] as List)[0] = {
        ...(json['items'] as List)[0] as Map,
        'id': 'not-a-uuid',
      };
      expect(
        () => decodeSetFromJson(json, today: kTestToday),
        throwsA(isA<SetImportException>()),
      );
    });
  });

  group('image fields (#014)', () {
    test('missing imageType/imageContent decode as null/null (backward '
        'compatible with pre-#014 exports/seeds)', () {
      final set = decodeSetFromJson(validSetJson(), today: kTestToday);
      expect(set.items[0].imageType, isNull);
      expect(set.items[0].imageContent, isNull);
    });

    test('a valid emoji pair decodes', () {
      final json = validSetJson();
      (json['items'] as List)[0] = {
        ...(json['items'] as List)[0] as Map,
        'imageType': 'emoji',
        'imageContent': '🐶',
      };
      final set = decodeSetFromJson(json, today: kTestToday);
      expect(set.items[0].imageType, 'emoji');
      expect(set.items[0].imageContent, '🐶');
    });

    test('a valid base64 pair decodes', () {
      final json = validSetJson();
      final base64Content = base64Encode([1, 2, 3]);
      (json['items'] as List)[0] = {
        ...(json['items'] as List)[0] as Map,
        'imageType': 'base64',
        'imageContent': base64Content,
      };
      final set = decodeSetFromJson(json, today: kTestToday);
      expect(set.items[0].imageType, 'base64');
      expect(set.items[0].imageContent, base64Content);
    });

    test('a multi-line base64 pair decodes with whitespace stripped '
        '(#base64 CLI output wraps at ~76 chars)', () {
      final json = validSetJson();
      (json['items'] as List)[0] = {
        ...(json['items'] as List)[0] as Map,
        'imageType': 'base64',
        'imageContent': 'AB\nCD',
      };
      final set = decodeSetFromJson(json, today: kTestToday);
      expect(set.items[0].imageContent, 'ABCD');
    });

    test('a valid url pair decodes (user-added items only; seeds never use '
        'url, see assets/seed/README.md)', () {
      final json = validSetJson();
      (json['items'] as List)[0] = {
        ...(json['items'] as List)[0] as Map,
        'imageType': 'url',
        'imageContent': 'https://example.com/fox.png',
      };
      final set = decodeSetFromJson(json, today: kTestToday);
      expect(set.items[0].imageType, 'url');
      expect(set.items[0].imageContent, 'https://example.com/fox.png');
    });

    test('imageType without imageContent (or vice versa) is rejected', () {
      final json = validSetJson();
      (json['items'] as List)[0] = {
        ...(json['items'] as List)[0] as Map,
        'imageType': 'emoji',
      };
      expect(
        () => decodeSetFromJson(json, today: kTestToday),
        throwsA(isA<SetImportException>()),
      );
    });

    test('an unknown imageType is rejected', () {
      final json = validSetJson();
      (json['items'] as List)[0] = {
        ...(json['items'] as List)[0] as Map,
        'imageType': 'lottie',
        'imageContent': 'anything',
      };
      expect(
        () => decodeSetFromJson(json, today: kTestToday),
        throwsA(isA<SetImportException>()),
      );
    });

    test('invalid type-specific content is rejected', () {
      final json = validSetJson();
      (json['items'] as List)[0] = {
        ...(json['items'] as List)[0] as Map,
        'imageType': 'url',
        'imageContent': 'not a url',
      };
      expect(
        () => decodeSetFromJson(json, today: kTestToday),
        throwsA(isA<SetImportException>()),
      );
    });
  });

  group('imageCopyright (#094)', () {
    test('missing imageCopyright decodes as null (backward compatible with '
        'pre-#094 exports/seeds)', () {
      final json = validSetJson();
      (json['items'] as List)[0] = {
        ...(json['items'] as List)[0] as Map,
        'imageType': 'base64',
        'imageContent': base64Encode([1, 2, 3]),
      };
      final set = decodeSetFromJson(json, today: kTestToday);
      expect(set.items[0].imageCopyright, isNull);
    });

    test('a valid copyright paired with base64/url decodes, trimmed', () {
      final json = validSetJson();
      (json['items'] as List)[0] = {
        ...(json['items'] as List)[0] as Map,
        'imageType': 'url',
        'imageContent': 'https://example.com/fox.png',
        'imageCopyright': '  © Jane Doe  ',
      };
      final set = decodeSetFromJson(json, today: kTestToday);
      expect(set.items[0].imageCopyright, '© Jane Doe');
    });

    test('a copyright on an emoji item is rejected — a system glyph has no '
        'meaningful copyright', () {
      final json = validSetJson();
      (json['items'] as List)[0] = {
        ...(json['items'] as List)[0] as Map,
        'imageType': 'emoji',
        'imageContent': '🐶',
        'imageCopyright': '© Jane Doe',
      };
      expect(
        () => decodeSetFromJson(json, today: kTestToday),
        throwsA(isA<SetImportException>()),
      );
    });

    test('a copyright without any image is rejected (one-sided: image can '
        'exist without a copyright, not vice versa)', () {
      final json = validSetJson();
      (json['items'] as List)[0] = {
        ...(json['items'] as List)[0] as Map,
        'imageCopyright': '© Jane Doe',
      };
      expect(
        () => decodeSetFromJson(json, today: kTestToday),
        throwsA(isA<SetImportException>()),
      );
    });

    test('a multi-line or over-120-char copyright is rejected', () {
      final json = validSetJson();
      (json['items'] as List)[0] = {
        ...(json['items'] as List)[0] as Map,
        'imageType': 'base64',
        'imageContent': base64Encode([1, 2, 3]),
        'imageCopyright': 'line one\nline two',
      };
      expect(
        () => decodeSetFromJson(json, today: kTestToday),
        throwsA(isA<SetImportException>()),
      );
    });

    test('a non-string imageCopyright is rejected', () {
      final json = validSetJson();
      (json['items'] as List)[0] = {
        ...(json['items'] as List)[0] as Map,
        'imageType': 'base64',
        'imageContent': base64Encode([1, 2, 3]),
        'imageCopyright': 42,
      };
      expect(
        () => decodeSetFromJson(json, today: kTestToday),
        throwsA(isA<SetImportException>()),
      );
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
        'promptLang': 'de',
        'answerLang': 'en',
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

    test('choice tolerates a missing pair (#022); rejects only-one-set and '
        'phone with a pair', () async {
      final missingPair = validSetJson();
      ((missingPair['items'] as List)[0] as Map).remove('promptLang');
      ((missingPair['items'] as List)[0] as Map).remove('answerLang');
      final set = decodeSetFromJson(missingPair, today: kTestToday);
      expect(set.items[0].promptLang, isNull);
      expect(set.items[0].answerLang, isNull);

      final onlyOne = validSetJson();
      ((onlyOne['items'] as List)[0] as Map).remove('answerLang');
      await expectRejects(onlyOne, 'together');

      final phonePair = validSetJson();
      (phonePair['items'] as List)[1] = {
        'type': 'phone',
        'prompt': 'Mama',
        'answer': '01711234567',
        'promptLang': 'de',
        'answerLang': 'en',
      };
      await expectRejects(phonePair, 'not allowed');
    });

    test('freeText accepts a language pair present or absent', () {
      final withPair = validSetJson();
      (withPair['items'] as List)[0] = {
        'type': 'freeText',
        'prompt': 'Hund',
        'answer': 'dog',
        'promptLang': 'de',
        'answerLang': 'en',
      };
      final set1 = decodeSetFromJson(withPair, today: kTestToday);
      expect(set1.items[0].promptLang, 'de');
      expect(set1.items[0].answerLang, 'en');

      final withoutPair = validSetJson();
      (withoutPair['items'] as List)[0] = {
        'type': 'freeText',
        'prompt': 'Capital of France',
        'answer': 'Paris',
      };
      final set2 = decodeSetFromJson(withoutPair, today: kTestToday);
      expect(set2.items[0].promptLang, isNull);
      expect(set2.items[0].answerLang, isNull);
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
        'promptLang': 'de',
        'answerLang': 'en',
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
        'promptLang': 'de',
        'answerLang': 'en',
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
            promptLang: 'de',
            answerLang: 'en',
          ),
        ],
        today: kTestToday,
      );
      expect(map['format'], 'foxstreak-set');
      expect(map['version'], 1);
      // category defaults to vocab when not passed (#045).
      expect(map['category'], 'vocab');
      expect(
        () => encodeSetToJson(
          title: ' ',
          createdBy: 'learner',
          items: const [],
          today: kTestToday,
        ),
        throwsA(isA<SetImportException>()),
      );
      expect(
        () => encodeSetToJson(
          title: 'T',
          createdBy: 'learner',
          category: 'grammar',
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
            promptLang: 'de',
            answerLang: 'en',
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

    test('decode(encode(x)) round-trips imageType/imageContent (#014)', () {
      const original = ShareSet(
        title: 'Round',
        description: '',
        createdBy: 'teacher',
        items: [
          ShareItem(
            type: 'choice',
            prompt: 'Hund',
            answer: 'dog',
            imageType: 'emoji',
            imageContent: '🐶',
          ),
          ShareItem(type: 'phone', prompt: 'M', answer: '01711234567'),
        ],
      );
      final viaString = decodeSetFromJson(
        jsonDecode(original.encode()) as Map<String, dynamic>,
        today: kTestToday,
      );
      expect(viaString.items[0].imageType, 'emoji');
      expect(viaString.items[0].imageContent, '🐶');
      expect(viaString.items[1].imageType, isNull);
      expect(viaString.items[1].imageContent, isNull);
      expect(viaString.toJson(), original.toJson());
    });

    test('decode(encode(x)) round-trips imageCopyright (#094)', () {
      const original = ShareSet(
        title: 'Round',
        description: '',
        createdBy: 'teacher',
        items: [
          ShareItem(
            type: 'choice',
            prompt: 'Hund',
            answer: 'dog',
            imageType: 'url',
            imageContent: 'https://example.com/fox.png',
            imageCopyright: '© Jane Doe',
          ),
          ShareItem(type: 'phone', prompt: 'M', answer: '01711234567'),
        ],
      );
      final viaString = decodeSetFromJson(
        jsonDecode(original.encode()) as Map<String, dynamic>,
        today: kTestToday,
      );
      expect(viaString.items[0].imageCopyright, '© Jane Doe');
      expect(viaString.items[1].imageCopyright, isNull);
      expect(viaString.toJson(), original.toJson());
    });
  });
}
