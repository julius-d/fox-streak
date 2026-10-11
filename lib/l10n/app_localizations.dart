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
  String get setTitleLabel;
  String get setCreatorLabel;
  String get setDescriptionLabel;
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
  String get typeVocab;
  String get typePhone;
  String get typeDate;
  String get directionDeEn;
  String get directionEnDe;
  String get shareSet;
  String get importSet;
  String get setActions;
  String get shareFailed;
  String get importFailed;
  String get errorRequired;
  String get errorCreatorLength;
  String get errorInvalidPhone;
  String get errorInvalidDate;
  String get errorDirectionRequired;
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

  // Lesson shell (#005)
  String get lessonStart;
  String get lessonTitle;
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
  String get lessonXpComingSoon;
  String get lessonStreakComingSoon;
  String get lessonPracticeAgain;
  String get lessonBackToLibrary;
  String get lessonEmptySetNote;
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
  String get setTitleLabel => 'Title';
  @override
  String get setCreatorLabel => 'Your name';
  @override
  String get setDescriptionLabel => 'Description (optional)';
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
  String get typeVocab => 'Word';
  @override
  String get typePhone => 'Phone';
  @override
  String get typeDate => 'Birthday';
  @override
  String get directionDeEn => 'German → English';
  @override
  String get directionEnDe => 'English → German';
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
  String get errorDirectionRequired => 'Pick a direction';
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
  String get exercisePhoneRevealHintAria => 'Reveal the phone number (costs hint bonus)';
  @override
  String get exercisePhoneMaskedDigit => '●';
  @override
  String get exercisePhoneCorrect => 'Correct!';
  @override
  String exercisePhoneWrongAnswer(String answer) => 'The number was $answer';

  // Lesson shell (#005)
  @override
  String get lessonStart => 'Practice';
  @override
  String get lessonTitle => 'Lesson';
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
  String get lessonQuitMessage => 'Your progress will be lost. Are you sure you want to quit?';
  @override
  String get lessonConfirmQuit => 'Quit';
  @override
  String get lessonCelebrate => 'Well done!';
  @override
  String get lessonNoScore => 'Keep practicing!';
  @override
  String lessonScoreSummary(int correct, int total, int pct) => '$correct of $total correct ($pct%)';
  @override
  String get lessonXpComingSoon => 'XP — coming soon';
  @override
  String get lessonStreakComingSoon => 'Streak — coming soon';
  @override
  String get lessonPracticeAgain => 'Practice again';
  @override
  String get lessonBackToLibrary => 'Back to library';
  @override
  String get lessonEmptySetNote => 'Add items to start practicing!';
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
  String get setTitleLabel => 'Titel';
  @override
  String get setCreatorLabel => 'Dein Name';
  @override
  String get setDescriptionLabel => 'Beschreibung (optional)';
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
  String get typeVocab => 'Wort';
  @override
  String get typePhone => 'Telefon';
  @override
  String get typeDate => 'Geburtstag';
  @override
  String get directionDeEn => 'Deutsch → Englisch';
  @override
  String get directionEnDe => 'Englisch → Deutsch';
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
  String get errorDirectionRequired => 'Wähle eine Richtung';
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
  String get exercisePhoneRevealHintAria => 'Telefonnummer anzeigen (kostet Hinweis-Bonus)';
  @override
  String get exercisePhoneMaskedDigit => '●';
  @override
  String get exercisePhoneCorrect => 'Richtig!';
  @override
  String exercisePhoneWrongAnswer(String answer) => 'Die Nummer war $answer';

  // Lesson shell (#005)
  @override
  String get lessonStart => 'Üben';
  @override
  String get lessonTitle => 'Lektion';
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
  String get lessonQuitMessage => 'Dein Fortschritt geht verloren. Wirklich verlassen?';
  @override
  String get lessonConfirmQuit => 'Verlassen';
  @override
  String get lessonCelebrate => 'Gut gemacht!';
  @override
  String get lessonNoScore => 'Weiter üben!';
  @override
  String lessonScoreSummary(int correct, int total, int pct) => '$correct von $total richtig ($pct%)';
  @override
  String get lessonXpComingSoon => 'XP — kommt bald';
  @override
  String get lessonStreakComingSoon => 'Serie — kommt bald';
  @override
  String get lessonPracticeAgain => 'Nochmal üben';
  @override
  String get lessonBackToLibrary => 'Zurück zur Bibliothek';
  @override
  String get lessonEmptySetNote => 'Füge Einträge hinzu, um zu üben!';
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
