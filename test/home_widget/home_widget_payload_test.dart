// Unit tests for the Android home-screen widget's pure state rules
// (issue #115): at-risk, ring clamping, today/midnight handling, a11y text.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/home_widget/home_widget_payload.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';

ProfileStat _profile({
  int streak = 0,
  String? lastActiveDay,
  int todayXp = 0,
  int goal = 50,
}) => ProfileStat(
  id: 1,
  xpTotal: 0,
  streakCount: streak,
  lastActiveDay: lastActiveDay,
  dailyGoalXp: goal,
  todayXp: todayXp,
  hasOnboarded: true,
  equippedPetId: kDefaultPetId,
  lessonsCompletedToday: 0,
  coinsTotal: 0,
  streakFreezesAvailable: 0,
);

final DateTime _now = DateTime(2026, 11, 8, 14);
const String _today = '2026-11-08';
const String _yesterday = '2026-11-07';

HomeWidgetPayload _build(ProfileStat profile, {String locale = 'en'}) =>
    buildHomeWidgetPayload(
      profile: profile,
      pet: PetCatalog.defaultEntry,
      now: _now,
      l10n: lookupAppLocalizations(Locale(locale)),
    );

void main() {
  group('widgetRingFill', () {
    test('is the plain ratio below the goal', () {
      expect(widgetRingFill(40, 50), 0.8);
      expect(widgetRingFill(0, 50), 0);
    });

    test('is clamped at full when the goal is exceeded', () {
      expect(widgetRingFill(50, 50), 1);
      expect(widgetRingFill(175, 50), 1);
    });

    test('counts a non-positive goal as reached', () {
      expect(widgetRingFill(0, 0), 1);
    });
  });

  group('buildHomeWidgetPayload', () {
    test('empty profile: streak 0, XP 0, empty ring, not at risk', () {
      final p = _build(_profile());
      expect(p.day, _today);
      expect(p.current.streakCount, 0);
      expect(p.current.todayXp, 0);
      expect(p.current.ringFill, 0);
      expect(p.current.atRisk, isFalse);
      expect(p.nextDay.atRisk, isFalse);
    });

    test('active today: shows today XP, not at risk', () {
      final p = _build(_profile(streak: 5, lastActiveDay: _today, todayXp: 40));
      expect(p.current.todayXp, 40);
      expect(p.current.ringFill, 0.8);
      expect(p.current.atRisk, isFalse);
      expect(p.current.description, '5 day streak, 40 of 50 XP today');
    });

    test('exceeded goal clamps the ring at full', () {
      final p = _build(
        _profile(streak: 2, lastActiveDay: _today, todayXp: 120),
      );
      expect(p.current.todayXp, 120);
      expect(p.current.ringFill, 1);
    });

    test('streak > 0 and no activity today is at risk with 0 XP', () {
      // `todayXp` still holds yesterday's value: it must be gated by the day.
      final p = _build(
        _profile(streak: 5, lastActiveDay: _yesterday, todayXp: 40),
      );
      expect(p.current.atRisk, isTrue);
      expect(p.current.todayXp, 0);
      expect(p.current.ringFill, 0);
      expect(p.current.streakCount, 5);
    });

    test('next-day state resets XP/ring but keeps the streak, at risk', () {
      final p = _build(_profile(streak: 5, lastActiveDay: _today, todayXp: 50));
      expect(p.current.atRisk, isFalse);
      expect(p.nextDay.streakCount, 5);
      expect(p.nextDay.todayXp, 0);
      expect(p.nextDay.ringFill, 0);
      expect(p.nextDay.atRisk, isTrue);
      expect(p.nextDay.description, '5 day streak, 0 of 50 XP today');
    });

    test('carries the equipped pet emoji and the at-risk text', () {
      final p = buildHomeWidgetPayload(
        profile: _profile(streak: 1),
        pet: PetCatalog.entries[1],
        now: _now,
        l10n: lookupAppLocalizations(const Locale('en')),
      );
      expect(p.petEmoji, PetCatalog.entries[1].emoji);
      expect(p.atRiskText, 'Practice today to keep your streak!');
    });

    test('localizes the description (DE) incl. singular', () {
      final p = _build(
        _profile(streak: 1, lastActiveDay: _today, todayXp: 10),
        locale: 'de',
      );
      expect(p.current.description, '1 Tag Streak, 10 von 50 XP heute');
      expect(p.atRiskText, 'Übe heute, um deine Streak zu halten!');
    });

    test('serialises to a channel-friendly map', () {
      final map = _build(
        _profile(streak: 3, lastActiveDay: _today, todayXp: 25),
      ).toMap();
      expect(map['day'], _today);
      expect(map['petEmoji'], '🦊');
      final current = map['current']! as Map<String, Object?>;
      expect(current['streakCount'], 3);
      expect(current['ringFill'], 0.5);
      expect(current['atRisk'], false);
      expect(map['nextDay'], isA<Map<String, Object?>>());
    });
  });
}
