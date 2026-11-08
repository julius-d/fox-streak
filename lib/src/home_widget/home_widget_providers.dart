// Riverpod wiring that keeps the Android home-screen widget in sync with the
// profile (issue #115).
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../data/providers.dart';
import '../pet/pet_providers.dart';
import '../stats/stats_providers.dart';
import 'home_widget_bridge.dart';
import 'home_widget_payload.dart';

/// Override in tests with a recording fake.
final homeWidgetBridgeProvider = Provider<HomeWidgetBridge>(
  (ref) => platformHomeWidgetBridge(),
);

/// The locale the widget text is rendered in (the device locale, as for the
/// app itself); override in tests.
final homeWidgetLocaleProvider = Provider<Locale>(
  (ref) => PlatformDispatcher.instance.locale,
);

AppLocalizations _l10nFor(Locale locale) {
  final bool supported = AppLocalizations.supportedLocales.any(
    (Locale l) => l.languageCode == locale.languageCode,
  );
  return lookupAppLocalizations(supported ? locale : const Locale('en'));
}

/// Pushes a fresh [HomeWidgetPayload] whenever the profile (XP, streak,
/// daily goal) or the equipped pet changes. Watch it once near the app root.
final homeWidgetSyncProvider = Provider<void>((ref) {
  final AsyncValue<ProfileStat> profile = ref.watch(profileProvider);
  final pet = ref.watch(equippedPetProvider);
  final ProfileStat? stat = profile.asData?.value;
  if (stat == null) return;

  final payload = buildHomeWidgetPayload(
    profile: stat,
    pet: pet,
    now: ref.watch(systemClockProvider).now(),
    l10n: _l10nFor(ref.watch(homeWidgetLocaleProvider)),
  );
  ref.read(homeWidgetBridgeProvider).update(payload);
});
