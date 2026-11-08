// Session-wide state of the Home "pack update" banner (issue #125).
//
// Lives in a non-auto-dispose provider, so the check runs once per cold app
// start (never on resume) and a running update keeps going — with its
// progress or result still there — when the learner leaves Home.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import 'marketplace_providers.dart';
import 'pack_update_service.dart';

enum PackUpdatePhase { idle, available, running, success, failed }

class PackUpdateState {
  final PackUpdatePhase phase;

  /// Packs to update ([available]/[running]) or still to retry ([failed]).
  final List<PackUpdate> updates;

  /// Sets fetched so far / in total while [running].
  final int done;
  final int total;

  /// [failed] only: other packs were updated successfully before.
  final bool partial;

  /// Banner hidden by the learner for this session ([available]/[failed]).
  final bool dismissed;

  const PackUpdateState({
    this.phase = PackUpdatePhase.idle,
    this.updates = const [],
    this.done = 0,
    this.total = 0,
    this.partial = false,
    this.dismissed = false,
  });

  PackUpdateState copyWith({
    PackUpdatePhase? phase,
    List<PackUpdate>? updates,
    int? done,
    int? total,
    bool? partial,
    bool? dismissed,
  }) => PackUpdateState(
    phase: phase ?? this.phase,
    updates: updates ?? this.updates,
    done: done ?? this.done,
    total: total ?? this.total,
    partial: partial ?? this.partial,
    dismissed: dismissed ?? this.dismissed,
  );

  /// Whether Home should render the pack banner.
  bool get visible =>
      phase != PackUpdatePhase.idle &&
      !(dismissed &&
          (phase == PackUpdatePhase.available ||
              phase == PackUpdatePhase.failed));
}

/// Asked once before an update starts: the titles of locally edited sets the
/// update would overwrite. Resolves to true to overwrite, false to skip them.
typedef ConfirmOverwrite = Future<bool> Function(List<String> setTitles);

final packUpdateLocksProvider = Provider<PackUpdateLocks>(
  (ref) => PackUpdateLocks(),
);

final packUpdateServiceProvider = Provider<PackUpdateService>(
  (ref) => PackUpdateService(
    ref.watch(marketplaceClientProvider),
    ref.watch(marketplaceRepositoryProvider),
    ref.watch(packsRepositoryProvider),
  ),
);

final packUpdateControllerProvider =
    NotifierProvider<PackUpdateController, PackUpdateState>(
      PackUpdateController.new,
    );

class PackUpdateController extends Notifier<PackUpdateState> {
  bool _updating = false;

  @override
  PackUpdateState build() {
    // Background check; Home never waits for it.
    Future<void>.microtask(_check);
    return const PackUpdateState();
  }

  Future<void> _check() async {
    final List<PackUpdate> updates;
    try {
      updates = await ref.read(packUpdateServiceProvider).findUpdates();
    } catch (_) {
      return; // a failed check shows nothing
    }
    if (!ref.mounted || updates.isEmpty) return;
    if (state.phase != PackUpdatePhase.idle) return;
    state = PackUpdateState(phase: PackUpdatePhase.available, updates: updates);
  }

  /// A pack was downloaded/updated elsewhere (Marketplace screen): it no
  /// longer needs the banner's update.
  void packChanged(String sourceUrl, String packId) {
    if (state.phase != PackUpdatePhase.available &&
        state.phase != PackUpdatePhase.failed) {
      return;
    }
    final remaining = [
      for (final u in state.updates)
        if (u.sourceUrl != sourceUrl || u.sourcePackId != packId) u,
    ];
    state = remaining.isEmpty
        ? const PackUpdateState()
        : state.copyWith(updates: remaining);
  }

  /// Hides the banner for this app session.
  void dismiss() {
    if (state.phase == PackUpdatePhase.available ||
        state.phase == PackUpdatePhase.failed) {
      state = state.copyWith(dismissed: true);
    }
  }

  /// A shown success confirmation goes away.
  void acknowledgeSuccess() {
    if (state.phase == PackUpdatePhase.success) {
      state = const PackUpdateState();
    }
  }

  /// Updates all affected packs ([PackUpdatePhase.available]) or retries the
  /// failed ones ([PackUpdatePhase.failed]).
  Future<void> update(ConfirmOverwrite confirmOverwrite) async {
    final phase = state.phase;
    if (_updating ||
        (phase != PackUpdatePhase.available &&
            phase != PackUpdatePhase.failed)) {
      return;
    }
    _updating = true;
    try {
      await _run(confirmOverwrite);
    } finally {
      _updating = false;
    }
  }

  Future<void> _run(ConfirmOverwrite confirmOverwrite) async {
    final service = ref.read(packUpdateServiceProvider);
    final locks = ref.read(packUpdateLocksProvider);
    final hadSucceeded = state.phase == PackUpdatePhase.failed && state.partial;

    // Packs deleted since the check, or being updated elsewhere, are left out.
    final targets = <PackUpdate>[];
    for (final update in state.updates) {
      if (locks.isHeld(update.sourceUrl, update.sourcePackId)) continue;
      if (await service.stillDownloaded(update)) targets.add(update);
    }

    final edited = <PackUpdate, List<({String setId, String title})>>{};
    for (final update in targets) {
      final sets = await service.editedSets(update);
      if (sets.isNotEmpty) {
        edited[update] = [
          for (final e in sets) (setId: e.setId, title: e.set.title),
        ];
      }
    }
    final skip = <PackUpdate, Set<String>>{};
    if (edited.isNotEmpty) {
      final overwrite = await confirmOverwrite([
        for (final sets in edited.values)
          for (final e in sets) e.title,
      ]);
      if (!overwrite) {
        for (final entry in edited.entries) {
          skip[entry.key] = {for (final e in entry.value) e.setId};
        }
      }
    }

    final total = [
      for (final update in targets)
        update.outdatedSetIds.length - (skip[update]?.length ?? 0),
    ].fold<int>(0, (a, b) => a + b);
    if (total <= 0) {
      // Nothing to do: the learner skipped everything, or the packs are
      // gone. Skipped updates stay pending (banner stays as it was).
      state = targets.isEmpty
          ? const PackUpdateState()
          : state.copyWith(updates: targets);
      return;
    }

    state = PackUpdateState(
      phase: PackUpdatePhase.running,
      updates: targets,
      total: total,
    );
    var done = 0;
    final failed = <PackUpdate>[];
    var anySucceeded = hadSucceeded;
    for (final update in targets) {
      if (!locks.tryAcquire(update.sourceUrl, update.sourcePackId)) {
        failed.add(update); // taken elsewhere meanwhile: retry covers it
        continue;
      }
      try {
        await service.apply(
          update,
          skipSetIds: skip[update] ?? const {},
          onSetFetched: () {
            done++;
            if (ref.mounted) state = state.copyWith(done: done);
          },
        );
        anySucceeded = true;
      } catch (_) {
        // A pack deleted mid-update is skipped silently, not a failure.
        if (await service.stillDownloaded(update)) failed.add(update);
      } finally {
        locks.release(update.sourceUrl, update.sourcePackId);
      }
    }
    if (!ref.mounted) return;
    state = failed.isEmpty
        ? const PackUpdateState(phase: PackUpdatePhase.success)
        : PackUpdateState(
            phase: PackUpdatePhase.failed,
            updates: failed,
            partial: anySucceeded,
          );
  }
}
