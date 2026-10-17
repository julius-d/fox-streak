// Manual `AppLocalizations` (issue #003 i18n scaffold).
//
// `lib/l10n/app_en.arb` / `app_de.arb` are the source of truth and this
// hand-written delegate mirrors them 1:1 so `flutter analyze`/`flutter test`
// /`flutter build` work everywhere, including checkouts where `flutter
// gen-l10n` cannot run (see `lib/l10n/README.md` for why there is no root
// `l10n.yaml` and how to regenerate on a machine where codegen works).
// When regenerating, verify this file matches the arb files.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

abstract class AppLocalizations {
  AppLocalizations(this.localeName);

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('de'),
  ];

  String get appTitle;
  String get libraryTitle;
  String get libraryEmptyTitle;
  String get libraryEmptyMessage;
  String get libraryTryDemo;
  String get libraryLoading;
  String get librarySeedError;
  String get librarySeedLoading;
  String setItemCount(int count);
  String get newSet;
  String get createSet;
  String get editSet;
  String get editItem;
  String get setTitleLabel;
  String get setCreatorLabel;
  String get setDescriptionLabel;
  String get setCategoryLabel;
  String get categoryVocab;
  String get categoryMath;
  String get categoryGeography;
  String get categoryGeneral;
  String get cancel;
  String get save;
  String get edit;
  String get create;
  String get rename;
  String get duplicate;
  String get delete;
  String get deleteSetTitle;
  String deleteSetMessage(String title);
  String get deleteItemTitle;
  String get deleteItemMessage;
  String get confirmDelete;
  String get setDetailAddItem;
  String get setDetailEmpty;
  String get itemPromptLabel;
  String get itemAnswerLabel;
  String get itemTypeLabel;
  String get typeChoice;
  String get typeFreeText;
  String get typePhone;
  String get typeDate;
  String get languageDe;
  String get languageEn;
  String exerciseDirectionLabel(String fromLanguage, String toLanguage);
  String get itemLanguagePairToggleLabel;
  String get itemPromptLangLabel;
  String get itemAnswerLangLabel;
  String get errorLanguagePairRequired;
  String get errorLanguagePairSame;
  String get shareSet;
  String get importSet;
  String get setActions;
  String get shareFailed;
  String get importFailed;
  String get errorRequired;
  String get errorCreatorLength;
  String get errorInvalidPhone;
  String get errorInvalidDate;
  String itemDistractorLabel(int index);
  String get itemDistractorHint;
  String get itemDayLabel;
  String get itemMonthLabel;
  String get itemYearLabel;
  String get itemDateHint;
  String get errorDuplicateChoice;
  String get errorInvalidDay;
  String get errorInvalidMonth;
  String get errorInvalidYear;

  // Phone exercise (#008)
  String get exercisePhoneDialPrompt;
  String get exercisePhoneRevealHint;
  String get exercisePhoneRevealHintAria;
  String get exercisePhoneMaskedDigit;
  String get exercisePhoneCorrect;
  String exercisePhoneWrongAnswer(String answer);
  String get exerciseDateRevealHintAria;

  // Free-text exercise (#007)
  String get exerciseFreeTextPlaceholder;
  String get exerciseFreeTextRevealHintAria;
  String exerciseFreeTextHintLabel(String letter);

  // Multiple-choice exercise (#006)
  String exerciseChoicePlaceholderOption(int index);
  String exerciseChoiceOptionSemanticLabel(
    String label,
    int position,
    int total,
  );

  // Lesson shell (#005)
  String get lessonStart;
  String get lessonTitle;
  String get lessonActions;
  String get lessonQuit;
  String get lessonProgressLabel;
  String get lessonCorrect;
  String lessonWrongAnswer(String answer);
  String get lessonCheck;
  String get lessonContinue;
  String get lessonSkip;
  String get lessonQuitTitle;
  String get lessonQuitMessage;
  String get lessonConfirmQuit;
  String get lessonCelebrate;
  String get lessonNoScore;
  String lessonScoreSummary(int correct, int total, int pct);
  String xpEarnedLabel(int xp);
  String lessonXpBonusCallout(int bonus);
  String lessonLevelUpCallout(int level);
  String levelLabel(int level);
  String get levelProgressLabel;
  String levelProgressText(int xpIntoLevel, int xpForNextLevel);
  String lessonStreakResultText(int streakCount);
  String streakCountLabel(int streakCount);
  String get streakTodayDoneLabel;
  String get lessonPracticeAgain;
  String get lessonBackToLibrary;
  String get lessonBackToHome;
  String get lessonEmptySetNote;

  // Home dashboard / onboarding / parental info (#012)
  String get homeGreetingMorning;
  String homeGreetingMorningNamed(String name);
  String get homeGreetingAfternoon;
  String homeGreetingAfternoonNamed(String name);
  String get homeGreetingEvening;
  String homeGreetingEveningNamed(String name);
  String get homeEditNameTooltip;
  String get homeEditNameDialogTitle;
  String get homeEditNameHint;
  String get homeContinueButton;
  String get homeBrowseSetsButton;
  String get homeGoalRingLabel;
  String homeGoalRingValue(int earnedXp, int goalXp);
  String homeGoalRingXp(int earnedXp);
  String get homeGoalRingToday;
  String get homeParentalInfoTooltip;
  String get parentalInfoTitle;
  String get parentalInfoBody;
  String get onboardingSlide1Title;
  String get onboardingSlide1Body;
  String get onboardingSlide2Title;
  String get onboardingSlide2Body;
  String get onboardingSlide3Title;
  String get onboardingSlide3Body;
  String get onboardingNameHint;
  String get onboardingSkip;
  String get onboardingNext;
  String get onboardingGetStarted;
}

class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn() : super('en');

  @override
  String get appTitle => 'FoxStreak';
  @override
  String get libraryTitle => 'My Sets';
  @override
  String get libraryEmptyTitle => 'No sets yet';
  @override
  String get libraryEmptyMessage =>
      'Create your first set or try the demo set.';
  @override
  String get libraryTryDemo => 'Try demo set';
  @override
  String get libraryLoading => 'Loading sets…';
  @override
  String get librarySeedError =>
      'Could not load the demo set. Please try again.';
  @override
  String get librarySeedLoading => 'Loading demo set…';
  @override
  String setItemCount(int count) => intl.Intl.plural(
    count,
    locale: localeName,
    zero: 'No items',
    one: '1 item',
    other: '$count items',
  );
  @override
  String get newSet => 'New set';
  @override
  String get createSet => 'Create set';
  @override
  String get editSet => 'Edit set';
  @override
  String get editItem => 'Edit item';
  @override
  String get setTitleLabel => 'Title';
  @override
  String get setCreatorLabel => 'Your name';
  @override
  String get setDescriptionLabel => 'Description (optional)';
  @override
  String get setCategoryLabel => 'Category';
  @override
  String get categoryVocab => 'Vocab';
  @override
  String get categoryMath => 'Math';
  @override
  String get categoryGeography => 'Geography';
  @override
  String get categoryGeneral => 'General';
  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get edit => 'Edit';
  @override
  String get create => 'Create';
  @override
  String get rename => 'Rename';
  @override
  String get duplicate => 'Duplicate';
  @override
  String get delete => 'Delete';
  @override
  String get deleteSetTitle => 'Delete set?';
  @override
  String deleteSetMessage(String title) =>
      'Delete "$title" with all its items? This cannot be undone.';
  @override
  String get deleteItemTitle => 'Delete item?';
  @override
  String get deleteItemMessage => 'Delete this item? This cannot be undone.';
  @override
  String get confirmDelete => 'Delete';
  @override
  String get setDetailAddItem => 'Add item';
  @override
  String get setDetailEmpty => 'No items yet. Add the first one!';
  @override
  String get itemPromptLabel => 'Prompt';
  @override
  String get itemAnswerLabel => 'Answer';
  @override
  String get itemTypeLabel => 'Type';
  @override
  String get typeChoice => 'Word (choice)';
  @override
  String get typeFreeText => 'Word (type answer)';
  @override
  String get typePhone => 'Phone';
  @override
  String get typeDate => 'Birthday';
  @override
  String get languageDe => 'German';
  @override
  String get languageEn => 'English';
  @override
  String exerciseDirectionLabel(String fromLanguage, String toLanguage) =>
      '$fromLanguage → $toLanguage';
  @override
  String get itemLanguagePairToggleLabel => 'Vocabulary translation';
  @override
  String get itemPromptLangLabel => 'From language';
  @override
  String get itemAnswerLangLabel => 'To language';
  @override
  String get errorLanguagePairRequired => 'Pick both languages';
  @override
  String get errorLanguagePairSame => 'Languages must differ';
  @override
  String get shareSet => 'Share';
  @override
  String get importSet => 'Import';
  @override
  String get setActions => 'Set actions';
  @override
  String get shareFailed => 'Sharing failed. Please try again.';
  @override
  String get importFailed => 'Import failed. Please try again.';
  @override
  String get errorRequired => 'This field is required';
  @override
  String get errorCreatorLength => 'Max 50 characters';
  @override
  String get errorInvalidPhone => 'Enter 3–15 digits';
  @override
  String get errorInvalidDate => 'Use YYYY-MM-DD (1900-01-01…today)';
  @override
  String itemDistractorLabel(int index) => 'Distractor $index';
  @override
  String get itemDistractorHint => 'Optional';
  @override
  String get itemDayLabel => 'Day';
  @override
  String get itemMonthLabel => 'Month';
  @override
  String get itemYearLabel => 'Year';
  @override
  String get itemDateHint => 'Enter day, month and year';
  @override
  String get errorDuplicateChoice => 'Must be different from the answer';
  @override
  String get errorInvalidDay => 'Enter a day 1–31';
  @override
  String get errorInvalidMonth => 'Enter a month 1–12';
  @override
  String get errorInvalidYear => 'Enter a year 1900–today';

  // Phone exercise (#008)
  @override
  String get exercisePhoneDialPrompt => 'Dial the number';
  @override
  String get exercisePhoneRevealHint => 'Reveal number';
  @override
  String get exercisePhoneRevealHintAria =>
      'Reveal the phone number (costs hint bonus)';
  @override
  String get exercisePhoneMaskedDigit => '●';
  @override
  String get exercisePhoneCorrect => 'Correct!';
  @override
  String exercisePhoneWrongAnswer(String answer) => 'The number was $answer';
  @override
  String get exerciseDateRevealHintAria => 'Reveal the date (costs hint bonus)';

  // Free-text exercise (#007)
  @override
  String get exerciseFreeTextPlaceholder => 'Type the answer';
  @override
  String get exerciseFreeTextRevealHintAria =>
      'Reveal the first letter (costs hint bonus)';
  @override
  String exerciseFreeTextHintLabel(String letter) => 'Starts with: $letter';

  // Multiple-choice exercise (#006)
  @override
  String exerciseChoicePlaceholderOption(int index) => 'Option $index';
  @override
  String exerciseChoiceOptionSemanticLabel(
    String label,
    int position,
    int total,
  ) => '$label, option $position of $total';

  // Lesson shell (#005)
  @override
  String get lessonStart => 'Practice';
  @override
  String get lessonTitle => 'Lesson';
  @override
  String get lessonActions => 'Lesson actions';
  @override
  String get lessonQuit => 'Quit lesson';
  @override
  String get lessonProgressLabel => 'Lesson progress';
  @override
  String get lessonCorrect => 'Correct!';
  @override
  String lessonWrongAnswer(String answer) => 'The answer was $answer';
  @override
  String get lessonCheck => 'CHECK';
  @override
  String get lessonContinue => 'CONTINUE';
  @override
  String get lessonSkip => 'Skip';
  @override
  String get lessonQuitTitle => 'Quit lesson?';
  @override
  String get lessonQuitMessage =>
      'Your progress will be lost. Are you sure you want to quit?';
  @override
  String get lessonConfirmQuit => 'Quit';
  @override
  String get lessonCelebrate => 'Well done!';
  @override
  String get lessonNoScore => 'Keep practicing!';
  @override
  String lessonScoreSummary(int correct, int total, int pct) =>
      '$correct of $total correct ($pct%)';
  @override
  String xpEarnedLabel(int xp) => '+$xp XP';
  @override
  String lessonXpBonusCallout(int bonus) => '+$bonus Perfect!';
  @override
  String lessonLevelUpCallout(int level) => 'Level Up! Level $level';
  @override
  String levelLabel(int level) => 'Level $level';
  @override
  String get levelProgressLabel => 'Progress to next level';
  @override
  String levelProgressText(int xpIntoLevel, int xpForNextLevel) =>
      '$xpIntoLevel / $xpForNextLevel XP to next level';
  @override
  String lessonStreakResultText(int streakCount) => '$streakCount-day streak!';
  @override
  String streakCountLabel(int streakCount) => '$streakCount';
  @override
  String get streakTodayDoneLabel => "Today's lesson counted";
  @override
  String get lessonPracticeAgain => 'Practice again';
  @override
  String get lessonBackToLibrary => 'Back to library';
  @override
  String get lessonBackToHome => 'Back to home';
  @override
  String get lessonEmptySetNote => 'Add items to start practicing!';

  // Home dashboard / onboarding / parental info (#012)
  @override
  String get homeGreetingMorning => 'Good morning!';
  @override
  String homeGreetingMorningNamed(String name) => 'Good morning, $name!';
  @override
  String get homeGreetingAfternoon => 'Good afternoon!';
  @override
  String homeGreetingAfternoonNamed(String name) => 'Good afternoon, $name!';
  @override
  String get homeGreetingEvening => 'Good evening!';
  @override
  String homeGreetingEveningNamed(String name) => 'Good evening, $name!';
  @override
  String get homeEditNameTooltip => 'Edit your name';
  @override
  String get homeEditNameDialogTitle => 'Your name';
  @override
  String get homeEditNameHint => 'Enter your name (optional)';
  @override
  String get homeContinueButton => 'Continue practicing';
  @override
  String get homeBrowseSetsButton => 'Browse sets';
  @override
  String get homeGoalRingLabel => 'Daily goal progress';
  @override
  String homeGoalRingValue(int earnedXp, int goalXp) =>
      '$earnedXp / $goalXp XP today';
  @override
  String homeGoalRingXp(int earnedXp) => '$earnedXp XP';
  @override
  String get homeGoalRingToday => 'today';
  @override
  String get homeParentalInfoTooltip => 'For parents';
  @override
  String get parentalInfoTitle => 'For parents';
  @override
  String get parentalInfoBody =>
      "FoxStreak works fully offline on this device. There's no chat, no "
      'social features, and no ads. All progress stays local and is never '
      'uploaded anywhere.';
  @override
  String get onboardingSlide1Title => 'Welcome to FoxStreak!';
  @override
  String get onboardingSlide1Body =>
      'Practice a little every day and watch your streak grow.';
  @override
  String get onboardingSlide2Title => 'Earn XP, level up';
  @override
  String get onboardingSlide2Body =>
      'Correct answers earn XP. Collect enough to level up!';
  @override
  String get onboardingSlide3Title => 'What should we call you?';
  @override
  String get onboardingSlide3Body =>
      'Totally optional — you can always change this later.';
  @override
  String get onboardingNameHint => 'Your name (optional)';
  @override
  String get onboardingSkip => 'Skip';
  @override
  String get onboardingNext => 'Next';
  @override
  String get onboardingGetStarted => 'Get started';
}

class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe() : super('de');

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
  String setItemCount(int count) => intl.Intl.plural(
    count,
    locale: localeName,
    zero: 'Keine Einträge',
    one: '1 Eintrag',
    other: '$count Einträge',
  );
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
  String deleteSetMessage(String title) =>
      '"$title" mit allen Einträgen löschen? Das kann nicht rückgängig gemacht werden.';
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
  String exerciseDirectionLabel(String fromLanguage, String toLanguage) =>
      '$fromLanguage → $toLanguage';
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
  String itemDistractorLabel(int index) => 'Distraktor $index';
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

  // Phone exercise (#008)
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
  String exercisePhoneWrongAnswer(String answer) => 'Die Nummer war $answer';
  @override
  String get exerciseDateRevealHintAria =>
      'Datum anzeigen (kostet Hinweis-Bonus)';

  // Free-text exercise (#007)
  @override
  String get exerciseFreeTextPlaceholder => 'Antwort eingeben';
  @override
  String get exerciseFreeTextRevealHintAria =>
      'Ersten Buchstaben anzeigen (kostet Hinweis-Bonus)';
  @override
  String exerciseFreeTextHintLabel(String letter) => 'Beginnt mit: $letter';

  // Multiple-choice exercise (#006)
  @override
  String exerciseChoicePlaceholderOption(int index) => 'Option $index';
  @override
  String exerciseChoiceOptionSemanticLabel(
    String label,
    int position,
    int total,
  ) => '$label, Option $position von $total';

  // Lesson shell (#005)
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
  String lessonWrongAnswer(String answer) => 'Die Antwort war $answer';
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
  String get lessonCelebrate => 'Gut gemacht!';
  @override
  String get lessonNoScore => 'Weiter üben!';
  @override
  String lessonScoreSummary(int correct, int total, int pct) =>
      '$correct von $total richtig ($pct%)';
  @override
  String xpEarnedLabel(int xp) => '+$xp XP';
  @override
  String lessonXpBonusCallout(int bonus) => '+$bonus Perfekt!';
  @override
  String lessonLevelUpCallout(int level) => 'Level-Aufstieg! Level $level';
  @override
  String levelLabel(int level) => 'Level $level';
  @override
  String get levelProgressLabel => 'Fortschritt zum nächsten Level';
  @override
  String levelProgressText(int xpIntoLevel, int xpForNextLevel) =>
      '$xpIntoLevel / $xpForNextLevel XP bis zum nächsten Level';
  @override
  String lessonStreakResultText(int streakCount) => '$streakCount Tage Serie!';
  @override
  String streakCountLabel(int streakCount) => '$streakCount';
  @override
  String get streakTodayDoneLabel => 'Heutige Lektion gezählt';
  @override
  String get lessonPracticeAgain => 'Nochmal üben';
  @override
  String get lessonBackToLibrary => 'Zurück zur Bibliothek';
  @override
  String get lessonBackToHome => 'Zurück zur Startseite';
  @override
  String get lessonEmptySetNote => 'Füge Einträge hinzu, um zu üben!';

  // Home dashboard / onboarding / parental info (#012)
  @override
  String get homeGreetingMorning => 'Guten Morgen!';
  @override
  String homeGreetingMorningNamed(String name) => 'Guten Morgen, $name!';
  @override
  String get homeGreetingAfternoon => 'Guten Tag!';
  @override
  String homeGreetingAfternoonNamed(String name) => 'Guten Tag, $name!';
  @override
  String get homeGreetingEvening => 'Guten Abend!';
  @override
  String homeGreetingEveningNamed(String name) => 'Guten Abend, $name!';
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
  String homeGoalRingValue(int earnedXp, int goalXp) =>
      '$earnedXp / $goalXp XP heute';
  @override
  String homeGoalRingXp(int earnedXp) => '$earnedXp XP';
  @override
  String get homeGoalRingToday => 'heute';
  @override
  String get homeParentalInfoTooltip => 'Für Eltern';
  @override
  String get parentalInfoTitle => 'Für Eltern';
  @override
  String get parentalInfoBody =>
      'FoxStreak funktioniert komplett offline auf diesem Gerät. Es gibt '
      'keinen Chat, keine sozialen Funktionen und keine Werbung. Der '
      'Fortschritt bleibt lokal und wird nirgendwo hochgeladen.';
  @override
  String get onboardingSlide1Title => 'Willkommen bei FoxStreak!';
  @override
  String get onboardingSlide1Body =>
      'Übe jeden Tag ein bisschen und lass deine Serie wachsen.';
  @override
  String get onboardingSlide2Title => 'XP sammeln, aufsteigen';
  @override
  String get onboardingSlide2Body =>
      'Richtige Antworten bringen XP. Sammle genug, um ein Level '
      'aufzusteigen!';
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
  String get onboardingGetStarted => "Los geht's";
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final String name =
        locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
    final String localeName = intl.Intl.canonicalizedLocale(name);
    intl.Intl.defaultLocale = localeName;
    if (locale.languageCode == 'de') {
      return AppLocalizationsDe();
    }
    return AppLocalizationsEn();
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
