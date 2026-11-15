// Database location per platform (issue #129): Linux keeps the database in
// the hidden per-user app-data folder, every other platform keeps drift's
// default (the documents folder) so existing users' data stays put.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  test('Linux uses the app-data (support) folder', () {
    expect(
      databaseDirectoryFor(TargetPlatform.linux),
      same(getApplicationSupportDirectory),
    );
  });

  test('other platforms keep the default location', () {
    for (final platform in TargetPlatform.values) {
      if (platform == TargetPlatform.linux) continue;
      expect(databaseDirectoryFor(platform), isNull, reason: '$platform');
    }
  });
}
