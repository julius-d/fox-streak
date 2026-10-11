// Manual `AppLocalizations` (issue #003 i18n scaffold).
//
// `lib/l10n/app_en.arb` / `app_de.arb` are the source of truth and
// `l10n.yaml` documents the `flutter gen-l10n` codegen for machines where it
// runs. `flutter gen-l10n` currently fails on Windows (Dart `FileStat`
// reports `r-xr-xr-x` for every directory, so the tool thinks nothing is
// writable); until that is fixed this hand-written delegate mirrors the arb
// strings 1:1 so `flutter analyze`/`flutter test` work everywhere.
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
  String get errorRequired;
  String get errorCreatorLength;
  String get errorInvalidPhone;
  String get errorInvalidDate;
  String get errorDirectionRequired;
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
  String get errorRequired => 'This field is required';
  @override
  String get errorCreatorLength => 'Max 50 characters';
  @override
  String get errorInvalidPhone => 'Enter 3–15 digits';
  @override
  String get errorInvalidDate => 'Use YYYY-MM-DD (1900-01-01…today)';
  @override
  String get errorDirectionRequired => 'Pick a direction';
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
  String get errorRequired => 'Dieses Feld ist erforderlich';
  @override
  String get errorCreatorLength => 'Max. 50 Zeichen';
  @override
  String get errorInvalidPhone => '3–15 Ziffern eingeben';
  @override
  String get errorInvalidDate => 'JJJJ-MM-TT nutzen (1900-01-01…heute)';
  @override
  String get errorDirectionRequired => 'Wähle eine Richtung';
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
