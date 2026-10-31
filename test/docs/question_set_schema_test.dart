// Drift check for issue #093: docs/question-set.schema.json must describe
// the real v1 share format closely enough to accept every shipped seed
// file. Doesn't re-validate set_json_codec.dart's own rules (that's
// test/data/set_json_codec_test.dart); this only guards against the schema
// silently drifting away from reality.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';

const String kSeedAssetDir = 'assets/seed';
const String kSchemaPath = 'docs/question-set.schema.json';

void main() {
  late JsonSchema schema;

  setUpAll(() {
    schema = JsonSchema.create(File(kSchemaPath).readAsStringSync());
  });

  test('docs/question-set.schema.json is valid JSON Schema', () {
    expect(schema, isNotNull);
  });

  final seedFiles = Directory(kSeedAssetDir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.foxstreak.json'))
      .toList();

  test('there are seed files to check', () {
    expect(seedFiles, isNotEmpty);
  });

  for (final file in seedFiles) {
    test('${file.uri.pathSegments.last} matches the schema', () {
      final instance = jsonDecode(file.readAsStringSync());
      final result = schema.validate(instance);
      expect(
        result.isValid,
        isTrue,
        reason: result.errors.map((e) => e.message).join('\n'),
      );
    });
  }
}
