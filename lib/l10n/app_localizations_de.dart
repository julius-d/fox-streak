// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'FoxStreak';

  @override
  String get libraryTitle => 'Meine Sets';

  @override
  String get libraryEmptyTitle => 'Noch keine Sets';

  @override
  String get libraryEmptyMessage =>
      'Erstelle dein erstes Set oder probiere das Demo-Set.';

  @override
  String get libraryTryDemo => 'Demo-Set ausprobieren';

  @override
  String get libraryLoading => 'Sets werden geladen…';

  @override
  String get librarySeedError =>
      'Demo-Set konnte nicht geladen werden. Bitte erneut versuchen.';

  @override
  String get librarySeedLoading => 'Demo-Set wird geladen…';

  @override
  String setItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
      zero: 'Keine Einträge',
    );
    return '$_temp0';
  }

  @override
  String get newSet => 'Neues Set';

  @override
  String get createSet => 'Set erstellen';

  @override
  String get editSet => 'Set bearbeiten';

  @override
  String get editItem => 'Eintrag bearbeiten';

  @override
  String get setTitleLabel => 'Titel';

  @override
  String get setCreatorLabel => 'Dein Name';

  @override
  String get setDescriptionLabel => 'Beschreibung (optional)';

  @override
  String get setCategoryLabel => 'Kategorie';

  @override
  String get categoryVocab => 'Vokabeln';

  @override
  String get categoryMath => 'Mathe';

  @override
  String get categoryGeography => 'Geografie';

  @override
  String get categoryGeneral => 'Allgemein';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get create => 'Erstellen';

  @override
  String get rename => 'Umbenennen';

  @override
  String get duplicate => 'Duplizieren';

  @override
  String get delete => 'Löschen';

  @override
  String get deleteSetTitle => 'Set löschen?';

  @override
  String deleteSetMessage(String title) {
    return '\"$title\" mit allen Einträgen löschen? Das kann nicht rückgängig gemacht werden.';
  }

  @override
  String get deleteItemTitle => 'Eintrag löschen?';

  @override
  String get deleteItemMessage =>
      'Diesen Eintrag löschen? Das kann nicht rückgängig gemacht werden.';

  @override
  String get confirmDelete => 'Löschen';

  @override
  String get setDetailAddItem => 'Eintrag hinzufügen';

  @override
  String get setDetailEmpty => 'Noch keine Einträge. Füge den ersten hinzu!';

  @override
  String get itemPromptLabel => 'Frage';

  @override
  String get itemAnswerLabel => 'Antwort';

  @override
  String get itemTypeLabel => 'Typ';

  @override
  String get typeChoice => 'Wort (Auswahl)';

  @override
  String get typeFreeText => 'Wort (eintippen)';

  @override
  String get typePhone => 'Telefon';

  @override
  String get typeDate => 'Geburtstag';

  @override
  String get languageDe => 'Deutsch';

  @override
  String get languageEn => 'Englisch';

  @override
  String exerciseDirectionLabel(String fromLanguage, String toLanguage) {
    return '$fromLanguage → $toLanguage';
  }

  @override
  String get itemLanguagePairToggleLabel => 'Vokabel-Übersetzung';

  @override
  String get itemPromptLangLabel => 'Von Sprache';

  @override
  String get itemAnswerLangLabel => 'Zu Sprache';

  @override
  String get errorLanguagePairRequired => 'Wähle beide Sprachen';

  @override
  String get errorLanguagePairSame => 'Sprachen müssen sich unterscheiden';

  @override
  String get shareSet => 'Teilen';

  @override
  String get importSet => 'Importieren';

  @override
  String get setActions => 'Set-Aktionen';

  @override
  String get shareFailed => 'Teilen fehlgeschlagen. Bitte versuch es erneut.';

  @override
  String get importFailed =>
      'Importieren fehlgeschlagen. Bitte versuch es erneut.';

  @override
  String get errorRequired => 'Dieses Feld ist erforderlich';

  @override
  String get errorCreatorLength => 'Max. 50 Zeichen';

  @override
  String get errorInvalidPhone => '3–15 Ziffern eingeben';

  @override
  String get errorInvalidDate => 'JJJJ-MM-TT nutzen (1900-01-01…heute)';

  @override
  String itemDistractorLabel(int index) {
    return 'Distraktor $index';
  }

  @override
  String get itemDistractorHint => 'Optional';

  @override
  String get itemDayLabel => 'Tag';

  @override
  String get itemMonthLabel => 'Monat';

  @override
  String get itemYearLabel => 'Jahr';

  @override
  String get itemDateHint => 'Tag, Monat und Jahr eingeben';

  @override
  String get errorDuplicateChoice => 'Muss sich von der Antwort unterscheiden';

  @override
  String get errorInvalidDay => 'Tag 1–31 eingeben';

  @override
  String get errorInvalidMonth => 'Monat 1–12 eingeben';

  @override
  String get errorInvalidYear => 'Jahr 1900–heute eingeben';

  @override
  String get exercisePhoneDialPrompt => 'Wähle die Nummer';

  @override
  String get exercisePhoneRevealHint => 'Nummer zeigen';

  @override
  String get exercisePhoneRevealHintAria =>
      'Telefonnummer anzeigen (kostet Hinweis-Bonus)';

  @override
  String get exercisePhoneMaskedDigit => '●';

  @override
  String get exercisePhoneCorrect => 'Richtig!';

  @override
  String exercisePhoneWrongAnswer(String answer) {
    return 'Die Nummer war $answer';
  }

  @override
  String get exerciseDateRevealHintAria =>
      'Datum anzeigen (kostet Hinweis-Bonus)';

  @override
  String get exerciseFreeTextPlaceholder => 'Antwort eingeben';

  @override
  String get exerciseFreeTextRevealHintAria =>
      'Ersten Buchstaben anzeigen (kostet Hinweis-Bonus)';

  @override
  String exerciseFreeTextHintLabel(String letter) {
    return 'Beginnt mit: $letter';
  }

  @override
  String exerciseChoicePlaceholderOption(int index) {
    return 'Option $index';
  }

  @override
  String exerciseChoiceOptionSemanticLabel(
    String label,
    int position,
    int total,
  ) {
    return '$label, Option $position von $total';
  }

  @override
  String get lessonEmptySetNote => 'Füge Einträge hinzu, um zu üben!';

  @override
  String get lessonStart => 'Üben';

  @override
  String get lessonTitle => 'Lektion';

  @override
  String get lessonActions => 'Lektionsaktionen';

  @override
  String get lessonQuit => 'Lektion verlassen';

  @override
  String get lessonProgressLabel => 'Lektionsfortschritt';

  @override
  String get lessonCorrect => 'Richtig!';

  @override
  String lessonWrongAnswer(String answer) {
    return 'Die Antwort war $answer';
  }

  @override
  String get lessonCheck => 'PRÜFEN';

  @override
  String get lessonContinue => 'WEITER';

  @override
  String get lessonSkip => 'Überspringen';

  @override
  String get lessonQuitTitle => 'Lektion verlassen?';

  @override
  String get lessonQuitMessage =>
      'Dein Fortschritt geht verloren. Wirklich verlassen?';

  @override
  String get lessonConfirmQuit => 'Verlassen';

  @override
  String lessonScoreSummary(int correct, int total, int pct) {
    return '$correct von $total richtig ($pct%)';
  }

  @override
  String xpEarnedLabel(int xp) {
    return '+$xp XP';
  }

  @override
  String lessonXpBonusCallout(int bonus) {
    return '+$bonus Perfekt!';
  }

  @override
  String lessonLevelUpCallout(int level) {
    return 'Level-Aufstieg! Level $level';
  }

  @override
  String levelLabel(int level) {
    return 'Level $level';
  }

  @override
  String get levelProgressLabel => 'Fortschritt zum nächsten Level';

  @override
  String levelProgressText(int xpIntoLevel, int xpForNextLevel) {
    return '$xpIntoLevel / $xpForNextLevel XP bis zum nächsten Level';
  }

  @override
  String lessonStreakResultText(int streakCount) {
    return '$streakCount-Tage-Streak!';
  }

  @override
  String streakCountLabel(int streakCount) {
    return '$streakCount';
  }

  @override
  String get streakTodayDoneLabel => 'Heutige Lektion gezählt';

  @override
  String get lessonBackToLibrary => 'Zurück zur Bibliothek';

  @override
  String get lessonStreakSavedHeading => 'Streak gesichert!';

  @override
  String get lessonHome => 'Startseite';

  @override
  String get lessonSetOverview => 'Set-Übersicht';

  @override
  String get lessonRedoWholeSet => 'Ganzes Set wiederholen';

  @override
  String get lessonRedoMissedItems => 'Falsche Einträge wiederholen';

  @override
  String get homeGreetingNight => 'Noch wach?';

  @override
  String homeGreetingNightNamed(String name) {
    return 'Noch wach, $name?';
  }

  @override
  String get homeGreetingMorning => 'Guten Morgen!';

  @override
  String homeGreetingMorningNamed(String name) {
    return 'Guten Morgen, $name!';
  }

  @override
  String get homeGreetingAfternoon => 'Guten Tag!';

  @override
  String homeGreetingAfternoonNamed(String name) {
    return 'Guten Tag, $name!';
  }

  @override
  String get homeGreetingEvening => 'Guten Abend!';

  @override
  String homeGreetingEveningNamed(String name) {
    return 'Guten Abend, $name!';
  }

  @override
  String get homeGreetingNewYear => 'Frohes neues Jahr!';

  @override
  String get homeGreetingAprilFools => 'Vorsicht, heute ist Aprilscherz-Tag!';

  @override
  String get homeGreetingHalloween => 'Frohes Halloween!';

  @override
  String get homeGreetingChristmasEve => 'Heiligabend ist da!';

  @override
  String get homeGreetingChristmasDay => 'Frohe Weihnachten!';

  @override
  String get homeGreetingFunny1 => 'Bereit, heute aufzusteigen?';

  @override
  String get homeGreetingFunny2 => 'Moin';

  @override
  String get homeGreetingFunny3 => 'Lass uns den Tag nutzen!';

  @override
  String get homeGreetingFunny4 => 'Hi';

  @override
  String get homeGreetingFunny5 => 'Zeit, den Fuchs mit Fakten zu füttern!';

  @override
  String get homeGreetingFunny6 => 'Lass uns loslegen';

  @override
  String get homeGreetingFunny7 =>
      'Heute ist ein toller Tag, um etwas Neues zu lernen!';

  @override
  String get homeGreetingFunny8 => 'Wie geht es Dir?';

  @override
  String get homeEditNameTooltip => 'Namen bearbeiten';

  @override
  String get homeEditNameDialogTitle => 'Dein Name';

  @override
  String get homeEditNameHint => 'Gib deinen Namen ein (optional)';

  @override
  String get homeContinueButton => 'Weiter üben';

  @override
  String get homeBrowseSetsButton => 'Sets durchsuchen';

  @override
  String get homeGoalRingLabel => 'Tagesziel-Fortschritt';

  @override
  String homeGoalRingValue(int earnedXp, int goalXp) {
    return '$earnedXp / $goalXp XP heute';
  }

  @override
  String homeGoalRingXp(int earnedXp) {
    return '$earnedXp XP';
  }

  @override
  String get homeGoalRingToday => 'heute';

  @override
  String get homeOverflowMenuTooltip => 'Weitere Optionen';

  @override
  String get homeParentalInfoTooltip => 'Für Eltern';

  @override
  String get homeSettingsMenuItem => 'Einstellungen';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsHapticsLabel => 'Haptik';

  @override
  String get settingsHapticsSubtitle => 'Beim Antworten vibrieren';

  @override
  String get settingsSoundLabel => 'Ton';

  @override
  String get settingsSoundSubtitle =>
      'Töne beim Level-Aufstieg und bei richtigen Antworten abspielen';

  @override
  String get settingsDisplayNameLabel => 'Anzeigename';

  @override
  String get settingsDisplayNameUnset => 'Nicht festgelegt';

  @override
  String get settingsDisplayNameDialogTitle => 'Anzeigename';

  @override
  String get settingsDisplayNameHint => 'Gib deinen Namen ein (optional)';

  @override
  String get settingsDailyGoalLabel => 'Tages-XP-Ziel';

  @override
  String settingsDailyGoalSubtitle(int xp) {
    return '$xp XP';
  }

  @override
  String get settingsDailyGoalDialogTitle => 'Tages-XP-Ziel';

  @override
  String get settingsDailyGoalHint => 'Tages-XP-Ziel (10–500)';

  @override
  String get settingsDailyGoalValidationError =>
      'Gib einen Wert zwischen 10 und 500 ein';

  @override
  String get parentalInfoTitle => 'Für Eltern';

  @override
  String get parentalInfoBody =>
      'FoxStreak funktioniert komplett offline auf diesem Gerät. Es gibt keinen Chat, keine sozialen Funktionen und keine Werbung. Der Fortschritt bleibt lokal und wird nirgendwo hochgeladen.';

  @override
  String get onboardingSlide1Title => 'Willkommen bei FoxStreak!';

  @override
  String get onboardingSlide1Body =>
      'Übe jeden Tag ein bisschen und lass deinen Streak wachsen.';

  @override
  String get onboardingSlide2Title => 'XP sammeln, aufsteigen';

  @override
  String get onboardingSlide2Body =>
      'Richtige Antworten bringen XP. Sammle genug, um ein Level aufzusteigen!';

  @override
  String get onboardingSlide3Title => 'Wie sollen wir dich nennen?';

  @override
  String get onboardingSlide3Body =>
      'Ganz optional — du kannst das später jederzeit ändern.';

  @override
  String get onboardingNameHint => 'Dein Name (optional)';

  @override
  String get onboardingSkip => 'Überspringen';

  @override
  String get onboardingNext => 'Weiter';

  @override
  String get onboardingGetStarted => 'Los geht\'s';

  @override
  String petSemanticLabel(String emoji) {
    return 'Pet $emoji';
  }

  @override
  String petEquippedSemanticLabel(String emoji) {
    return 'Pet $emoji, ausgerüstet';
  }

  @override
  String get petLockedSemanticLabel => 'Gesperrtes Pet';

  @override
  String petRarityLabel(String rarity) {
    String _temp0 = intl.Intl.selectLogic(rarity, {
      'common': 'Gewöhnlich',
      'uncommon': 'Ungewöhnlich',
      'epic': 'Episch',
      'legendary': 'Legendär',
      'mythic': 'Mythisch',
      'seasonal': 'Saisonal',
      'other': 'Gewöhnlich',
    });
    return '$_temp0';
  }

  @override
  String get homePetSemanticLabel => 'Deine Pet-Sammlung öffnen';

  @override
  String get petCollectionTitle => 'Deine Pets';

  @override
  String get lootboxHeading => 'Eine Schatzkiste für dich!';

  @override
  String get lootboxTapPrompt => 'Tippe, um deine Belohnung aufzudecken!';

  @override
  String lootboxRevealedTitle(String rarity) {
    String _temp0 = intl.Intl.selectLogic(rarity, {
      'common': 'Du hast ein gewöhnliches Pet bekommen!',
      'uncommon': 'Du hast ein ungewöhnliches Pet bekommen!',
      'epic': 'Du hast ein episches Pet bekommen!',
      'legendary': 'Du hast ein legendäres Pet bekommen!',
      'mythic': 'Du hast ein mythisches Pet bekommen!',
      'seasonal': 'Du hast ein saisonales Pet bekommen!',
      'other': 'Du hast ein neues Pet bekommen!',
    });
    return '$_temp0';
  }

  @override
  String lootboxCoinsRevealedTitle(int amount) {
    return 'Du hast $amount Münzen gewonnen!';
  }

  @override
  String coinsSemanticLabel(int amount) {
    return '$amount Münzen';
  }

  @override
  String homeCoinsCountLabel(int amount) {
    return '$amount';
  }

  @override
  String get editItems => 'Elemente bearbeiten';

  @override
  String get newSetFabCollapseTooltip => 'Schließen';

  @override
  String get homeStreakDetailsSemanticLabel => 'Deine Streak-Historie öffnen';

  @override
  String get streakDetailsTitle => 'Streak-Historie';

  @override
  String streakDetailsCurrentStreakHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aktuelle Streak: $count Tage',
      one: 'Aktuelle Streak: 1 Tag',
      zero: 'Keine aktuelle Streak',
    );
    return '$_temp0';
  }

  @override
  String streakDetailsLongestStreakHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Längste Streak der letzten 6 Monate: $count Tage',
      one: 'Längste Streak der letzten 6 Monate: 1 Tag',
      zero: 'Keine Aktivität in den letzten 6 Monaten',
    );
    return '$_temp0';
  }

  @override
  String get streakDetailsLegendNone => 'Keine Aktivität';

  @override
  String get streakDetailsLegendLow => 'Niedrig';

  @override
  String get streakDetailsLegendMedium => 'Mittel';

  @override
  String get streakDetailsLegendHigh => 'Ziel erreicht';

  @override
  String streakCalendarCellActivityLabel(String day, int xp) {
    return '$day: $xp XP verdient';
  }

  @override
  String streakCalendarCellNoActivityLabel(String day) {
    return '$day: keine Aktivität';
  }
}
