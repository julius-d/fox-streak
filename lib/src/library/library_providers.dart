// Riverpod streams for the set library (issue #003).
//
// Thin wrappers over `SetsRepository` (#002). Screens watch these; all data
// access goes through `setsRepositoryProvider` — no direct DB use in widgets.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/providers.dart';

/// All sets, ordered by id (repository order).
final allSetsProvider = StreamProvider<List<QuestionSet>>((ref) {
  return ref.watch(setsRepositoryProvider).watchAllSets();
});

/// Items of one set, ordered by position.
final itemsForSetProvider = StreamProvider.family<List<Item>, int>((
  ref,
  setId,
) {
  return ref.watch(setsRepositoryProvider).watchItemsForSet(setId);
});
