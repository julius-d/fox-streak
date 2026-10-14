// Riverpod wiring for profile stats reads (issue #012).
//
// Thin wrappers over `StatsRepository` (#002) — Home watches these; no
// direct DB use in widgets.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/providers.dart';

/// Live profile row (defaults until the first write), for Home's greeting,
/// streak badge, level-progress bar, and goal ring.
final profileProvider = StreamProvider<ProfileStat>((ref) {
  return ref.watch(statsRepositoryProvider).watchProfile();
});

/// The most recently practiced set's id, or `null` if none exists yet
/// (#012's Home "Continue" button). Not a stream (no cheap single-row
/// watch over a derived `attempts` ⋈ `items` query); callers invalidate
/// this provider after navigating back from a lesson/library trip.
final lastPracticedSetIdProvider = FutureProvider.autoDispose<int?>((ref) {
  return ref.watch(statsRepositoryProvider).getLastPracticedSetId();
});
