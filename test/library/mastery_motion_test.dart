// Library set-card mastery motion rules (issue #134).

import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/set_mastery.dart';
import 'package:fox_streak_app/src/library/mastery_motion.dart';

SetMastery crowns(int mastered, int total) =>
    SetMastery(itemCount: total, masteredCount: mastered, practiced: true);

SetMastery fresh(int total) =>
    SetMastery(itemCount: total, masteredCount: 0, practiced: false);

MasteryMotion? plan(SetMastery? shown, SetMastery current) =>
    planMasteryMotion(shown: shown, current: current, reduceMotion: false);

void main() {
  test('a first visit shows the value without motion', () {
    expect(plan(null, crowns(3, 5)), isNull);
  });

  test('a rise fills from the old to the new value, popping each crown '
      'that becomes full', () {
    final motion = plan(crowns(1, 10), crowns(5, 10))!;
    expect(motion.fromCrowns, 0.5);
    expect(motion.toCrowns, 2.5);
    expect(motion.fills, isTrue);
    expect(motion.morphFromNew, isFalse);
    expect(motion.shimmer, isFalse);
    expect(motion.poppingCrowns, [0, 1]);
  });

  test('a crown already full is not popped again; landing exactly on a '
      'whole crown pops it', () {
    expect(plan(crowns(2, 5), crowns(4, 5))!.poppingCrowns, [2, 3]);
    expect(plan(crowns(1, 10), crowns(2, 10))!.poppingCrowns, [0]);
    expect(plan(crowns(2, 10), crowns(3, 10))!.poppingCrowns, isEmpty);
  });

  test('reaching 100% from below shimmers', () {
    final motion = plan(crowns(4, 5), crowns(5, 5))!;
    expect(motion.shimmer, isTrue);
    expect(motion.poppingCrowns, [4]);
  });

  test('a set already at 100% viewed again plays nothing', () {
    expect(plan(crowns(5, 5), crowns(5, 5)), isNull);
  });

  test('a drop or no change shows the value without motion', () {
    expect(plan(crowns(4, 5), crowns(2, 5)), isNull);
    // An added item lowers the share.
    expect(plan(crowns(5, 5), crowns(5, 6)), isNull);
    expect(plan(crowns(2, 5), crowns(2, 5)), isNull);
  });

  test('leaving New morphs, then fills from empty', () {
    final motion = plan(fresh(4), crowns(1, 4))!;
    expect(motion.morphFromNew, isTrue);
    expect(motion.fromCrowns, 0);
    expect(motion.toCrowns, 1.25);
    expect(motion.poppingCrowns, [0]);
  });

  test('leaving New with nothing mastered still morphs, without a fill', () {
    final motion = plan(fresh(4), crowns(0, 4))!;
    expect(motion.morphFromNew, isTrue);
    expect(motion.fills, isFalse);
    expect(motion.poppingCrowns, isEmpty);
  });

  test('New and empty sets never animate', () {
    expect(plan(crowns(1, 3), fresh(3)), isNull);
    expect(plan(crowns(1, 3), SetMastery.empty), isNull);
    expect(plan(SetMastery.empty, crowns(0, 1)), isNull);
  });

  test('reduced motion never animates', () {
    expect(
      planMasteryMotion(
        shown: fresh(5),
        current: crowns(5, 5),
        reduceMotion: true,
      ),
      isNull,
    );
  });
}
