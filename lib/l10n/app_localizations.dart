import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'FoxStreak'**
  String get appTitle;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'My Sets'**
  String get libraryTitle;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No sets yet'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Create your first set or try the demo set.'**
  String get libraryEmptyMessage;

  /// No description provided for @libraryTryDemo.
  ///
  /// In en, this message translates to:
  /// **'Try demo set'**
  String get libraryTryDemo;

  /// No description provided for @libraryLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading sets…'**
  String get libraryLoading;

  /// No description provided for @librarySeedError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the demo set. Please try again.'**
  String get librarySeedError;

  /// No description provided for @librarySeedLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading demo set…'**
  String get librarySeedLoading;

  /// Item count subtitle on a set card
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} =1{1 item} other{{count} items}}'**
  String setItemCount(int count);

  /// No description provided for @newSet.
  ///
  /// In en, this message translates to:
  /// **'New set'**
  String get newSet;

  /// No description provided for @createSet.
  ///
  /// In en, this message translates to:
  /// **'Create set'**
  String get createSet;

  /// No description provided for @editSet.
  ///
  /// In en, this message translates to:
  /// **'Edit set'**
  String get editSet;

  /// No description provided for @editItem.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get editItem;

  /// No description provided for @setTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get setTitleLabel;

  /// No description provided for @setCreatorLabel.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get setCreatorLabel;

  /// No description provided for @setDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get setDescriptionLabel;

  /// No description provided for @setCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get setCategoryLabel;

  /// No description provided for @categoryVocab.
  ///
  /// In en, this message translates to:
  /// **'Vocab'**
  String get categoryVocab;

  /// No description provided for @categoryMath.
  ///
  /// In en, this message translates to:
  /// **'Math'**
  String get categoryMath;

  /// No description provided for @categoryGeography.
  ///
  /// In en, this message translates to:
  /// **'Geography'**
  String get categoryGeography;

  /// No description provided for @categoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get categoryGeneral;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete set?'**
  String get deleteSetTitle;

  /// Delete confirmation body with set title
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\" with all its items? This cannot be undone.'**
  String deleteSetMessage(String title);

  /// No description provided for @deleteItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete item?'**
  String get deleteItemTitle;

  /// No description provided for @deleteItemMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete this item? This cannot be undone.'**
  String get deleteItemMessage;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get confirmDelete;

  /// No description provided for @setDetailAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get setDetailAddItem;

  /// No description provided for @setDetailEmpty.
  ///
  /// In en, this message translates to:
  /// **'No items yet. Add the first one!'**
  String get setDetailEmpty;

  /// No description provided for @itemPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get itemPromptLabel;

  /// No description provided for @itemAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get itemAnswerLabel;

  /// No description provided for @itemTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get itemTypeLabel;

  /// No description provided for @typeChoice.
  ///
  /// In en, this message translates to:
  /// **'Word (choice)'**
  String get typeChoice;

  /// No description provided for @typeFreeText.
  ///
  /// In en, this message translates to:
  /// **'Word (type answer)'**
  String get typeFreeText;

  /// No description provided for @typePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get typePhone;

  /// No description provided for @typeDate.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get typeDate;

  /// Display name for the German language code (de)
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageDe;

  /// Display name for the English language code (en)
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEn;

  /// Generic X -> Y direction-framing label built from promptLang/answerLang display names (#022)
  ///
  /// In en, this message translates to:
  /// **'{fromLanguage} → {toLanguage}'**
  String exerciseDirectionLabel(String fromLanguage, String toLanguage);

  /// Toggle label revealing the promptLang/answerLang dropdowns in the item editor (#022)
  ///
  /// In en, this message translates to:
  /// **'Vocabulary translation'**
  String get itemLanguagePairToggleLabel;

  /// Label for the prompt-language dropdown in the item editor (#022)
  ///
  /// In en, this message translates to:
  /// **'From language'**
  String get itemPromptLangLabel;

  /// Label for the answer-language dropdown in the item editor (#022)
  ///
  /// In en, this message translates to:
  /// **'To language'**
  String get itemAnswerLangLabel;

  /// Inline error when the language-pair toggle is on but a language is not picked (#022)
  ///
  /// In en, this message translates to:
  /// **'Pick both languages'**
  String get errorLanguagePairRequired;

  /// Inline error when both picked languages are the same (#022)
  ///
  /// In en, this message translates to:
  /// **'Languages must differ'**
  String get errorLanguagePairSame;

  /// No description provided for @shareSet.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareSet;

  /// No description provided for @importSet.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importSet;

  /// No description provided for @setActions.
  ///
  /// In en, this message translates to:
  /// **'Set actions'**
  String get setActions;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Sharing failed. Please try again.'**
  String get shareFailed;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed. Please try again.'**
  String get importFailed;

  /// No description provided for @errorRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get errorRequired;

  /// No description provided for @errorCreatorLength.
  ///
  /// In en, this message translates to:
  /// **'Max 50 characters'**
  String get errorCreatorLength;

  /// No description provided for @errorInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter 3–15 digits'**
  String get errorInvalidPhone;

  /// No description provided for @errorInvalidDate.
  ///
  /// In en, this message translates to:
  /// **'Use YYYY-MM-DD (1900-01-01…today)'**
  String get errorInvalidDate;

  /// Label for one optional vocab distractor field
  ///
  /// In en, this message translates to:
  /// **'Distractor {index}'**
  String itemDistractorLabel(int index);

  /// No description provided for @itemDistractorHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get itemDistractorHint;

  /// No description provided for @itemDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get itemDayLabel;

  /// No description provided for @itemMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get itemMonthLabel;

  /// No description provided for @itemYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get itemYearLabel;

  /// No description provided for @itemDateHint.
  ///
  /// In en, this message translates to:
  /// **'Enter day, month and year'**
  String get itemDateHint;

  /// No description provided for @errorDuplicateChoice.
  ///
  /// In en, this message translates to:
  /// **'Must be different from the answer'**
  String get errorDuplicateChoice;

  /// No description provided for @errorInvalidDay.
  ///
  /// In en, this message translates to:
  /// **'Enter a day 1–31'**
  String get errorInvalidDay;

  /// No description provided for @errorInvalidMonth.
  ///
  /// In en, this message translates to:
  /// **'Enter a month 1–12'**
  String get errorInvalidMonth;

  /// No description provided for @errorInvalidYear.
  ///
  /// In en, this message translates to:
  /// **'Enter a year 1900–today'**
  String get errorInvalidYear;

  /// Prompt shown above the dial pad for phone exercises
  ///
  /// In en, this message translates to:
  /// **'Dial the number'**
  String get exercisePhoneDialPrompt;

  /// Tooltip/label for the reveal hint button (eye icon)
  ///
  /// In en, this message translates to:
  /// **'Reveal number'**
  String get exercisePhoneRevealHint;

  /// Accessibility label for reveal hint button
  ///
  /// In en, this message translates to:
  /// **'Reveal the phone number (costs hint bonus)'**
  String get exercisePhoneRevealHintAria;

  /// Character used to mask digits as they are typed
  ///
  /// In en, this message translates to:
  /// **'●'**
  String get exercisePhoneMaskedDigit;

  /// Success message when phone number is dialed correctly
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get exercisePhoneCorrect;

  /// Error message showing the correct phone number
  ///
  /// In en, this message translates to:
  /// **'The number was {answer}'**
  String exercisePhoneWrongAnswer(String answer);

  /// Accessibility label for the date exercise reveal hint button
  ///
  /// In en, this message translates to:
  /// **'Reveal the date (costs hint bonus)'**
  String get exerciseDateRevealHintAria;

  /// Placeholder shown in the empty free-text answer field
  ///
  /// In en, this message translates to:
  /// **'Type the answer'**
  String get exerciseFreeTextPlaceholder;

  /// Accessibility label/tooltip for the free-text reveal hint button
  ///
  /// In en, this message translates to:
  /// **'Reveal the first letter (costs hint bonus)'**
  String get exerciseFreeTextRevealHintAria;

  /// Hint shown after reveal-hint is used, with the expected answer's first letter
  ///
  /// In en, this message translates to:
  /// **'Starts with: {letter}'**
  String exerciseFreeTextHintLabel(String letter);

  /// Placeholder distractor label used when there are not enough real distractors (#006)
  ///
  /// In en, this message translates to:
  /// **'Option {index}'**
  String exerciseChoicePlaceholderOption(int index);

  /// Accessibility label for a multiple-choice option: its text plus its position among the options
  ///
  /// In en, this message translates to:
  /// **'{label}, option {position} of {total}'**
  String exerciseChoiceOptionSemanticLabel(
    String label,
    int position,
    int total,
  );

  /// Empty state message for set with no items, prompting to add items
  ///
  /// In en, this message translates to:
  /// **'Add items to start practicing!'**
  String get lessonEmptySetNote;

  /// Button label to start a lesson/practice session
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get lessonStart;

  /// App bar title for the lesson screen
  ///
  /// In en, this message translates to:
  /// **'Lesson'**
  String get lessonTitle;

  /// Tooltip for the lesson overflow menu button
  ///
  /// In en, this message translates to:
  /// **'Lesson actions'**
  String get lessonActions;

  /// Tooltip for the quit button in lesson app bar
  ///
  /// In en, this message translates to:
  /// **'Quit lesson'**
  String get lessonQuit;

  /// Accessibility label for lesson progress bar
  ///
  /// In en, this message translates to:
  /// **'Lesson progress'**
  String get lessonProgressLabel;

  /// Feedback message for correct answer
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get lessonCorrect;

  /// Feedback message for wrong answer with correct answer placeholder
  ///
  /// In en, this message translates to:
  /// **'The answer was {answer}'**
  String lessonWrongAnswer(String answer);

  /// Button label to check/submit answer
  ///
  /// In en, this message translates to:
  /// **'CHECK'**
  String get lessonCheck;

  /// Button label to continue to next question after feedback
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get lessonContinue;

  /// Button label to skip current question
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get lessonSkip;

  /// Title for quit lesson confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Quit lesson?'**
  String get lessonQuitTitle;

  /// Message for quit lesson confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Your progress will be lost. Are you sure you want to quit?'**
  String get lessonQuitMessage;

  /// Confirm button label for quit lesson dialog
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get lessonConfirmQuit;

  /// Score summary with correct count, total, and percentage
  ///
  /// In en, this message translates to:
  /// **'{correct} of {total} correct ({pct}%)'**
  String lessonScoreSummary(int correct, int total, int pct);

  /// XP-earned count-up label on the lesson result screen (issue #010)
  ///
  /// In en, this message translates to:
  /// **'+{xp} XP'**
  String xpEarnedLabel(int xp);

  /// Separate callout shown when the lesson's perfect-score XP bonus applies (issue #010)
  ///
  /// In en, this message translates to:
  /// **'+{bonus} Perfect!'**
  String lessonXpBonusCallout(int bonus);

  /// Callout shown when the lesson's completion crossed at least one level boundary (issue #053)
  ///
  /// In en, this message translates to:
  /// **'Level Up! Level {level}'**
  String lessonLevelUpCallout(int level);

  /// Current level label on the level-progress widget (issue #010)
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String levelLabel(int level);

  /// Screen-reader label for the level-progress bar (issue #010)
  ///
  /// In en, this message translates to:
  /// **'Progress to next level'**
  String get levelProgressLabel;

  /// Numeric XP-into-level / XP-needed-for-level text under the level-progress bar (issue #010)
  ///
  /// In en, this message translates to:
  /// **'{xpIntoLevel} / {xpForNextLevel} XP to next level'**
  String levelProgressText(int xpIntoLevel, int xpForNextLevel);

  /// Headline announcing the streak on the lesson result screen (issue #011)
  ///
  /// In en, this message translates to:
  /// **'{streakCount}-day streak!'**
  String lessonStreakResultText(int streakCount);

  /// Streak-count label shown inside StreakBadge, next to the flame icon (issue #011)
  ///
  /// In en, this message translates to:
  /// **'{streakCount}'**
  String streakCountLabel(int streakCount);

  /// Accessibility label for StreakBadge's "today done" check indicator (issue #011)
  ///
  /// In en, this message translates to:
  /// **'Today\'s lesson counted'**
  String get streakTodayDoneLabel;

  /// Button label to practice the same set again
  ///
  /// In en, this message translates to:
  /// **'Practice again'**
  String get lessonPracticeAgain;

  /// Button label to go back to library
  ///
  /// In en, this message translates to:
  /// **'Back to library'**
  String get lessonBackToLibrary;

  /// Lesson result button label when the lesson was reached directly from Home (issue #034), not via the library/set-detail flow
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get lessonBackToHome;

  /// Generic late-night greeting on Home (before 5am) when no display name is set (issue #060)
  ///
  /// In en, this message translates to:
  /// **'Up late?'**
  String get homeGreetingNight;

  /// Late-night greeting on Home (before 5am) with the display name (issue #060)
  ///
  /// In en, this message translates to:
  /// **'Up late, {name}?'**
  String homeGreetingNightNamed(String name);

  /// Generic morning greeting on Home when no display name is set (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Good morning!'**
  String get homeGreetingMorning;

  /// Morning greeting on Home with the display name (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}!'**
  String homeGreetingMorningNamed(String name);

  /// Generic afternoon greeting on Home when no display name is set (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Good afternoon!'**
  String get homeGreetingAfternoon;

  /// Afternoon greeting on Home with the display name (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}!'**
  String homeGreetingAfternoonNamed(String name);

  /// Generic evening greeting on Home when no display name is set (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Good evening!'**
  String get homeGreetingEvening;

  /// Evening greeting on Home with the display name (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}!'**
  String homeGreetingEveningNamed(String name);

  /// Fixed-date holiday greeting on Home for Jan 1, overriding the time-of-day greeting (issue #061)
  ///
  /// In en, this message translates to:
  /// **'Happy New Year!'**
  String get homeGreetingNewYear;

  /// Fixed-date holiday greeting on Home for Apr 1, overriding the time-of-day greeting (issue #061)
  ///
  /// In en, this message translates to:
  /// **'Watch out for pranks today!'**
  String get homeGreetingAprilFools;

  /// Fixed-date holiday greeting on Home for Oct 31, overriding the time-of-day greeting (issue #061)
  ///
  /// In en, this message translates to:
  /// **'Happy Halloween!'**
  String get homeGreetingHalloween;

  /// Fixed-date holiday greeting on Home for Dec 24, overriding the time-of-day greeting (issue #061)
  ///
  /// In en, this message translates to:
  /// **'Christmas Eve is here!'**
  String get homeGreetingChristmasEve;

  /// Fixed-date holiday greeting on Home for Dec 25, overriding the time-of-day greeting (issue #061)
  ///
  /// In en, this message translates to:
  /// **'Merry Christmas!'**
  String get homeGreetingChristmasDay;

  /// Playful rotation greeting on Home, shown on some non-holiday days instead of the plain time-of-day greeting; generic copy, no name personalization (issue #061)
  ///
  /// In en, this message translates to:
  /// **'Ready to level up today?'**
  String get homeGreetingFunny1;

  /// Playful rotation greeting on Home (issue #061)
  ///
  /// In en, this message translates to:
  /// **'Your foxy brain is warming up!'**
  String get homeGreetingFunny2;

  /// Playful rotation greeting on Home (issue #061)
  ///
  /// In en, this message translates to:
  /// **'Let\'s make today count!'**
  String get homeGreetingFunny3;

  /// Playful rotation greeting on Home (issue #061)
  ///
  /// In en, this message translates to:
  /// **'Knowledge snacks, coming right up!'**
  String get homeGreetingFunny4;

  /// Playful rotation greeting on Home (issue #061)
  ///
  /// In en, this message translates to:
  /// **'Time to feed the fox some facts!'**
  String get homeGreetingFunny5;

  /// Playful rotation greeting on Home (issue #061)
  ///
  /// In en, this message translates to:
  /// **'Brain gains await!'**
  String get homeGreetingFunny6;

  /// Playful rotation greeting on Home (issue #061)
  ///
  /// In en, this message translates to:
  /// **'Today\'s a great day to learn something new!'**
  String get homeGreetingFunny7;

  /// Playful rotation greeting on Home (issue #061)
  ///
  /// In en, this message translates to:
  /// **'Fox mode: activated!'**
  String get homeGreetingFunny8;

  /// Tooltip/accessibility label on Home's tappable greeting, opening the rename dialog (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Edit your name'**
  String get homeEditNameTooltip;

  /// Title of the tap-to-rename dialog (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get homeEditNameDialogTitle;

  /// Hint text in the tap-to-rename dialog's text field (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Enter your name (optional)'**
  String get homeEditNameHint;

  /// Home's Continue button label, resuming the last practiced set (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Continue practicing'**
  String get homeContinueButton;

  /// Home's Browse sets button label, navigating to the library (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Browse sets'**
  String get homeBrowseSetsButton;

  /// Accessibility label for Home's daily-goal ring (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Daily goal progress'**
  String get homeGoalRingLabel;

  /// Accessibility value and center label for Home's daily-goal ring: XP earned today over the daily goal (issue #012)
  ///
  /// In en, this message translates to:
  /// **'{earnedXp} / {goalXp} XP today'**
  String homeGoalRingValue(int earnedXp, int goalXp);

  /// Primary line of Home's daily-goal ring center label (issue #037); the goal amount is conveyed visually by the ring's fill, not restated here
  ///
  /// In en, this message translates to:
  /// **'{earnedXp} XP'**
  String homeGoalRingXp(int earnedXp);

  /// Secondary (caption) line of Home's daily-goal ring center label (issue #037)
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get homeGoalRingToday;

  /// Tooltip/accessibility label for Home's app bar overflow menu button (issue #055)
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get homeOverflowMenuTooltip;

  /// Label of Home's overflow-menu entry opening the parental info screen (issue #012, menu entry since #055)
  ///
  /// In en, this message translates to:
  /// **'For parents'**
  String get homeParentalInfoTooltip;

  /// Label of Home's overflow-menu entry opening the settings screen (issue #055)
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettingsMenuItem;

  /// App bar title for the settings screen (issue #055)
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Title of the haptics SwitchListTile on the settings screen (issue #055)
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get settingsHapticsLabel;

  /// Subtitle of the haptics SwitchListTile on the settings screen (issue #055)
  ///
  /// In en, this message translates to:
  /// **'Vibrate on correct and incorrect answers'**
  String get settingsHapticsSubtitle;

  /// Title of the sound SwitchListTile on the settings screen (issue #055)
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get settingsSoundLabel;

  /// Subtitle of the sound SwitchListTile on the settings screen (issue #055)
  ///
  /// In en, this message translates to:
  /// **'Play chimes on level-up and correct answers'**
  String get settingsSoundSubtitle;

  /// Title of the display name ListTile on the settings screen (issue #057)
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get settingsDisplayNameLabel;

  /// Placeholder subtitle of the display name ListTile when no name is set (issue #057)
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settingsDisplayNameUnset;

  /// Title of the settings display name edit dialog (issue #057)
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get settingsDisplayNameDialogTitle;

  /// Hint text in the settings display name edit dialog's text field (issue #057)
  ///
  /// In en, this message translates to:
  /// **'Enter your name (optional)'**
  String get settingsDisplayNameHint;

  /// Title of the daily XP goal ListTile on the settings screen (issue #057)
  ///
  /// In en, this message translates to:
  /// **'Daily XP goal'**
  String get settingsDailyGoalLabel;

  /// Subtitle of the daily XP goal ListTile, showing the current goal (issue #057)
  ///
  /// In en, this message translates to:
  /// **'{xp} XP'**
  String settingsDailyGoalSubtitle(int xp);

  /// Title of the settings daily XP goal edit dialog (issue #057)
  ///
  /// In en, this message translates to:
  /// **'Daily XP goal'**
  String get settingsDailyGoalDialogTitle;

  /// Hint text in the settings daily XP goal edit dialog's text field (issue #057)
  ///
  /// In en, this message translates to:
  /// **'Daily XP goal (10–500)'**
  String get settingsDailyGoalHint;

  /// Validation message shown in the daily XP goal dialog for non-numeric or out-of-range input (issue #057)
  ///
  /// In en, this message translates to:
  /// **'Enter a value between 10 and 500'**
  String get settingsDailyGoalValidationError;

  /// App bar title for the static parental info screen (issue #012)
  ///
  /// In en, this message translates to:
  /// **'For parents'**
  String get parentalInfoTitle;

  /// Body copy of the static parental info screen (issue #012)
  ///
  /// In en, this message translates to:
  /// **'FoxStreak works fully offline on this device. There\'s no chat, no social features, and no ads. All progress stays local and is never uploaded anywhere.'**
  String get parentalInfoBody;

  /// First onboarding slide title (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Welcome to FoxStreak!'**
  String get onboardingSlide1Title;

  /// First onboarding slide body (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Practice a little every day and watch your streak grow.'**
  String get onboardingSlide1Body;

  /// Second onboarding slide title (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Earn XP, level up'**
  String get onboardingSlide2Title;

  /// Second onboarding slide body (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Correct answers earn XP. Collect enough to level up!'**
  String get onboardingSlide2Body;

  /// Third onboarding slide title, with optional name capture (issue #012)
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get onboardingSlide3Title;

  /// Third onboarding slide body (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Totally optional — you can always change this later.'**
  String get onboardingSlide3Body;

  /// Hint text in the onboarding name field (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Your name (optional)'**
  String get onboardingNameHint;

  /// Skip button label on every onboarding slide (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// Next button label on non-final onboarding slides (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// Final onboarding slide's primary button label (issue #012)
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingGetStarted;

  /// Generic a11y/visible label for an equipped or revealed pet, decoded from its filename into the literal emoji — no per-animal arb keys (issue #059)
  ///
  /// In en, this message translates to:
  /// **'Pet {emoji}'**
  String petSemanticLabel(String emoji);

  /// A11y label for the currently-equipped pet tile in the collection grid (issue #059)
  ///
  /// In en, this message translates to:
  /// **'Pet {emoji}, equipped'**
  String petEquippedSemanticLabel(String emoji);

  /// A11y label for a not-yet-owned pet tile in the collection grid (issue #059)
  ///
  /// In en, this message translates to:
  /// **'Locked pet'**
  String get petLockedSemanticLabel;

  /// A11y label for Home's tap-to-collect pet button (issue #059)
  ///
  /// In en, this message translates to:
  /// **'Open your pet collection'**
  String get homePetSemanticLabel;

  /// App bar title of the pet collection/equip screen (issue #059)
  ///
  /// In en, this message translates to:
  /// **'Your pets'**
  String get petCollectionTitle;

  /// Heading on the unopened lootbox screen (issue #059)
  ///
  /// In en, this message translates to:
  /// **'Daily lootbox!'**
  String get lootboxHeading;

  /// Tap-to-open prompt on the unopened lootbox screen (issue #059)
  ///
  /// In en, this message translates to:
  /// **'Tap to reveal your new pet!'**
  String get lootboxTapPrompt;

  /// Heading shown once the lootbox has been opened with a pet reward (issue #059)
  ///
  /// In en, this message translates to:
  /// **'You got a new pet!'**
  String get lootboxRevealedTitle;

  /// Heading shown once the lootbox has been opened with a coins reward (issue #065)
  ///
  /// In en, this message translates to:
  /// **'You won {amount} coins!'**
  String lootboxCoinsRevealedTitle(int amount);

  /// A11y label for the coin-reveal animation on the opened lootbox screen (issue #065)
  ///
  /// In en, this message translates to:
  /// **'{amount} coins'**
  String coinsSemanticLabel(int amount);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
