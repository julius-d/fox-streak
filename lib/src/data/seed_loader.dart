// First-launch seed import (issue #002).
//
// On a cold start with an empty DB, the bundled fictional demo sets in
// `assets/seed/demo_*.foxstreak.json` are imported once. Real learning
// content ships in #013; these seeds exist so a fresh install is not empty.
//
// Strategy: "empty DB => import". No extra flag/SharedPreferences needed for
// v1; if the user deletes every set, seeds come back on next launch (simple,
// documented, and easy to replace with a flag later without API churn).
// Corrupt seed entries are skipped, never crash launch.

import 'dart:convert';

import 'package:flutter/services.dart';

import 'set_json_codec.dart';
import 'sets_repository.dart';

/// Bundled seed assets imported on first launch (fictional data only).
const List<String> kSeedAssetPaths = [
  'assets/seed/demo_animals.foxstreak.json',
  'assets/seed/demo_family.foxstreak.json',
  'assets/seed/demo_bundeslaender.foxstreak.json',
  'assets/seed/demo_times_tables.foxstreak.json',
];

typedef AssetStringLoader = Future<String> Function(String assetPath);

Future<String> _defaultAssetLoader(String path) => rootBundle.loadString(path);

class SeedLoader {
  final SetsRepository _sets;
  final AssetStringLoader _loadString;
  final List<String> _assetPaths;

  SeedLoader(
    this._sets, {
    AssetStringLoader? loadString,
    List<String>? assetPaths,
  }) : _loadString = loadString ?? _defaultAssetLoader,
       _assetPaths = assetPaths ?? kSeedAssetPaths;

  /// Imports bundled seeds when the DB holds no sets.
  ///
  /// Returns the number of sets imported (0 when already seeded or when all
  /// seeds failed). Never throws for bad seed content — skips it.
  Future<int> ensureSeeded({DateTime? today}) async {
    final existing = await _sets.getAllSets();
    if (existing.isNotEmpty) return 0;
    var imported = 0;
    for (final path in _assetPaths) {
      try {
        final raw = await _loadString(path);
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        await _sets.importSetFromJson(
          Map<dynamic, dynamic>.from(decoded),
          today: today,
        );
        imported++;
      } on SetImportException {
        continue;
      } on FormatException {
        continue;
      } on PlatformException {
        // Missing asset (e.g. test bundle) — skip.
        continue;
      }
    }
    return imported;
  }
}
