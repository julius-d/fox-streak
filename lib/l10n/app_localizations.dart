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

  /// Label for the item editor's optional image type dropdown (issue #014)
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get itemImageTypeFieldLabel;

  /// Dropdown option clearing the item's image (issue #014)
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get itemImageTypeNone;

  /// Dropdown option for an emoji item image (issue #014)
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get itemImageTypeEmoji;

  /// Dropdown option for an embedded base64 item image (issue #014)
  ///
  /// In en, this message translates to:
  /// **'Base64 image'**
  String get itemImageTypeBase64;

  /// Dropdown option for a remote URL item image (issue #014)
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get itemImageTypeUrl;

  /// Label for the content field when imageType is emoji (issue #014)
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get itemImageEmojiContentLabel;

  /// Label for the content field when imageType is base64 (issue #014)
  ///
  /// In en, this message translates to:
  /// **'Base64 image data'**
  String get itemImageBase64ContentLabel;

  /// Label for the content field when imageType is url (issue #014)
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get itemImageUrlContentLabel;

  /// Inline error when the emoji image content field is empty (issue #014)
  ///
  /// In en, this message translates to:
  /// **'Enter an emoji or symbol'**
  String get errorInvalidImageEmoji;

  /// Inline error when the base64 image content field is not decodable (issue #014)
  ///
  /// In en, this message translates to:
  /// **'Enter valid base64 image data'**
  String get errorInvalidImageBase64;

  /// Inline error when the URL image content field is not a valid http(s) link (issue #014)
  ///
  /// In en, this message translates to:
  /// **'Enter a valid http(s) link'**
  String get errorInvalidImageUrl;

  /// Label for the item editor's optional image copyright/credit field, shown only for base64/url image types (issue #094)
  ///
  /// In en, this message translates to:
  /// **'Copyright / credit (optional)'**
  String get itemImageCopyrightFieldLabel;

  /// Inline error when the image copyright field is multi-line or over 120 characters (issue #094)
  ///
  /// In en, this message translates to:
  /// **'Enter a single line, up to 120 characters'**
  String get errorInvalidImageCopyright;

  /// Screen-reader hint on a tappable base64/url item image, announcing that it opens a full-screen view (issue #094)
  ///
  /// In en, this message translates to:
  /// **'Opens a full-screen view'**
  String get fullScreenImageViewHint;

  /// Screen-reader/tooltip label of the close (X) button in the full-screen image view (issue #113)
  ///
  /// In en, this message translates to:
  /// **'Close image'**
  String get fullScreenImageCloseLabel;

  /// Message shown in place of a question-card/full-screen url image after automatic retries are exhausted (issue #102)
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this image'**
  String get questionImageLoadFailed;

  /// Tappable retry button shown alongside questionImageLoadFailed, re-running the load (issue #102)
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get questionImageRetryButton;

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
  /// **'Reveal the answer (costs hint bonus)'**
  String get exerciseFreeTextRevealHintAria;

  /// Hint shown after reveal-hint is used, with the full expected answer
  ///
  /// In en, this message translates to:
  /// **'{answer}'**
  String exerciseFreeTextHintLabel(String answer);

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

  /// A11y label for XpUpScreen's milestone-only pet (issue #111) — StreakSavedScreen already announces the exact streak count just before this screen, so this only needs to flag the same milestone moment, not restate the number
  ///
  /// In en, this message translates to:
  /// **'Streak milestone!'**
  String get xpUpMilestonePetSemanticLabel;

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

  /// Button label to go back to library (also reused by the empty-set CTA on SetDetailScreen)
  ///
  /// In en, this message translates to:
  /// **'Back to library'**
  String get lessonBackToLibrary;

  /// Heading on the streak-saved completion screen, shown only when the lesson just completed advanced today's streak (issue #078)
  ///
  /// In en, this message translates to:
  /// **'Streak saved!'**
  String get lessonStreakSavedHeading;

  /// Summary screen button label returning to Home, regardless of lesson entry point (issue #078)
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get lessonHome;

  /// Summary screen button label restarting with only this session's wrong/skipped items; omitted on a perfect score (issue #078)
  ///
  /// In en, this message translates to:
  /// **'Redo missed items'**
  String get lessonRedoMissedItems;

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

  /// Visible rarity/seasonal label shown under a collection-screen tile, owned or locked (issue #069). rarity is one of: common, uncommon, epic, legendary, mythic, seasonal
  ///
  /// In en, this message translates to:
  /// **'{rarity, select, common{Common} uncommon{Uncommon} epic{Epic} legendary{Legendary} mythic{Mythic} seasonal{Seasonal} other{Common}}'**
  String petRarityLabel(String rarity);

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

  /// Heading on the unopened lootbox screen (issue #059; reworded off "Daily" since #067 made it recur multiple times a day)
  ///
  /// In en, this message translates to:
  /// **'A lootbox for you!'**
  String get lootboxHeading;

  /// Tap-to-open prompt on the unopened lootbox screen (issue #059; reworded reward-agnostic by #069 since the reward may be coins, not a pet)
  ///
  /// In en, this message translates to:
  /// **'Tap to reveal your reward!'**
  String get lootboxTapPrompt;

  /// Heading shown once the lootbox has been opened with a pet reward, naming the won pet's rarity/seasonal label (issue #059; reworded by #069). rarity is one of: common, uncommon, epic, legendary, mythic, seasonal
  ///
  /// In en, this message translates to:
  /// **'{rarity, select, common{You got a Common pet!} uncommon{You got an Uncommon pet!} epic{You got an Epic pet!} legendary{You got a Legendary pet!} mythic{You got a Mythic pet!} seasonal{You got a Seasonal pet!} other{You got a new pet!}}'**
  String lootboxRevealedTitle(String rarity);

  /// Heading shown once the lootbox has been opened with a coins reward (issue #065)
  ///
  /// In en, this message translates to:
  /// **'You won {amount} coins!'**
  String lootboxCoinsRevealedTitle(int amount);

  /// A11y label for the coin-reveal animation on the opened lootbox screen (issue #065); also reused as the Semantics.label for Home's CoinBadge (issue #080)
  ///
  /// In en, this message translates to:
  /// **'{amount} coins'**
  String coinsSemanticLabel(int amount);

  /// Coin-count label shown inside CoinBadge on Home, next to the coin icon (issue #080)
  ///
  /// In en, this message translates to:
  /// **'{amount}'**
  String homeCoinsCountLabel(int amount);

  /// Label for the "Edit items" entry in a set card's three-dot menu, opening SetDetailScreen — distinct from editSet, which is SetEditorScreen's title (issue #074)
  ///
  /// In en, this message translates to:
  /// **'Edit items'**
  String get editItems;

  /// Tooltip for the Library's main FAB when expanded into the New set/Import speed-dial, showing a close icon to collapse it without running either action (issue #074)
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get newSetFabCollapseTooltip;

  /// A11y label for Home's tap-to-open streak details button (issue #084)
  ///
  /// In en, this message translates to:
  /// **'Open your streak history'**
  String get homeStreakDetailsSemanticLabel;

  /// App bar title of the Streak Details (activity calendar) screen (issue #084)
  ///
  /// In en, this message translates to:
  /// **'Streak history'**
  String get streakDetailsTitle;

  /// Headline on the Streak Details screen showing the exact current streak, from profile.streakCount (issue #084)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No current streak} =1{Current streak: 1 day} other{Current streak: {count} days}}'**
  String streakDetailsCurrentStreakHeadline(int count);

  /// Headline on the Streak Details screen showing the longest run of active days within the visible ~6-month window — explicitly labeled as windowed, not a lifetime "longest streak ever" claim (issue #084)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No activity in the last 6 months} =1{Longest in the last 6 months: 1 day} other{Longest in the last 6 months: {count} days}}'**
  String streakDetailsLongestStreakHeadline(int count);

  /// Calendar color-bucket legend label: no daily_activity row for that day (issue #084)
  ///
  /// In en, this message translates to:
  /// **'No activity'**
  String get streakDetailsLegendNone;

  /// Calendar color-bucket legend label: lowest non-empty bucket, below 50% of the daily goal (or a future streak-on-ice day at 0 XP) (issue #084)
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get streakDetailsLegendLow;

  /// Calendar color-bucket legend label: 50-99% of the daily goal (issue #084)
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get streakDetailsLegendMedium;

  /// Calendar color-bucket legend label: at or above 100% of the daily goal (issue #084)
  ///
  /// In en, this message translates to:
  /// **'Goal reached'**
  String get streakDetailsLegendHigh;

  /// Screen-reader label for one activity-calendar cell that has a daily_activity row, naming the formatted day and the XP earned that day (issue #084)
  ///
  /// In en, this message translates to:
  /// **'{day}: {xp} XP earned'**
  String streakCalendarCellActivityLabel(String day, int xp);

  /// Screen-reader label for one activity-calendar cell with no daily_activity row (issue #084)
  ///
  /// In en, this message translates to:
  /// **'{day}: no activity'**
  String streakCalendarCellNoActivityLabel(String day);

  /// Heading on the unspun wheel-of-fortune screen (issue #085)
  ///
  /// In en, this message translates to:
  /// **'Spin the wheel!'**
  String get wheelHeading;

  /// Tap-to-spin prompt on the unspun wheel-of-fortune screen, also its a11y button label while idle/spinning (issue #085)
  ///
  /// In en, this message translates to:
  /// **'Tap to spin!'**
  String get wheelTapPrompt;

  /// Heading shown once the wheel has stopped, naming the won coin amount (issue #085)
  ///
  /// In en, this message translates to:
  /// **'You won {amount} coins!'**
  String wheelWonText(int amount);

  /// Heading shown once the wheel has stopped on its rare streak-on-ice segment, instead of a coin amount (issue #087)
  ///
  /// In en, this message translates to:
  /// **'You won a streak freeze! ❄️'**
  String get wheelWonStreakOnIceText;

  /// A11y label for the wheel's streak-on-ice slice/win, once stopped (issue #087) — the streak-on-ice counterpart to coinsSemanticLabel
  ///
  /// In en, this message translates to:
  /// **'Streak freeze'**
  String get streakOnIceSemanticLabel;

  /// One-time FoxFeedbackBanner on Home informing the user their streak was auto-saved by consuming a banked streak freeze (issue #087)
  ///
  /// In en, this message translates to:
  /// **'Your streak was saved with a streak freeze! ❄️'**
  String get streakFreezeAppliedBannerText;

  /// Streak Details screen headline showing the current streakFreezesAvailable balance (issue #087)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No streak freezes available} =1{1 streak freeze available} other{{count} streak freezes available}}'**
  String streakFreezesAvailableLabel(int count);

  /// Calendar color-bucket legend label for a streakOnIce day, distinct from the ActivityLevel buckets (issue #087)
  ///
  /// In en, this message translates to:
  /// **'Streak freeze used'**
  String get streakDetailsLegendStreakOnIce;

  /// Screen-reader label for one activity-calendar cell whose daily_activity row has source streakOnIce (issue #087)
  ///
  /// In en, this message translates to:
  /// **'{day}: streak freeze used'**
  String streakCalendarCellStreakOnIceLabel(String day);

  /// AppBar title for the coin shop screen, reached by tapping Home's CoinBadge (issue #091)
  ///
  /// In en, this message translates to:
  /// **'Coin shop'**
  String get coinShopTitle;

  /// Buy button label on the coin shop screen, interpolating the fixed streak-on-ice price; also reused as the confirm-dialog's confirm button label (issue #091)
  ///
  /// In en, this message translates to:
  /// **'Buy for {price} coins'**
  String coinShopBuyButtonLabel(int price);

  /// Title of the FoxConfirmDialog shown when tapping the coin shop's buy button (issue #091)
  ///
  /// In en, this message translates to:
  /// **'Buy streak on ice?'**
  String get coinShopConfirmTitle;

  /// Message of the FoxConfirmDialog shown when tapping the coin shop's buy button, interpolating the fixed price (issue #091)
  ///
  /// In en, this message translates to:
  /// **'Spend {price} coins for one streak on ice?'**
  String coinShopConfirmMessage(int price);

  /// Success banner message shown on the coin shop screen after a completed purchase (issue #091)
  ///
  /// In en, this message translates to:
  /// **'You bought a streak on ice! ❄️'**
  String get coinShopPurchaseSuccessMessage;

  /// Coin shop screen label showing the current streakFreezesAvailable balance (issue #091)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No streak on ice yet} =1{1 streak on ice} other{{count} streak on ice}}'**
  String coinShopStreakOnIceCountLabel(int count);

  /// A11y label for Home's tap-to-open coin shop button (issue #091)
  ///
  /// In en, this message translates to:
  /// **'Open the coin shop'**
  String get homeCoinShopSemanticLabel;

  /// Marketplace mini-FAB label/tooltip on the Library speed-dial, and the Marketplace sources screen's app bar title (issue #101)
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get marketplace;

  /// Empty-state title on the Marketplace sources screen when no source has been added yet (issue #101)
  ///
  /// In en, this message translates to:
  /// **'No marketplaces yet'**
  String get marketplaceSourcesEmptyTitle;

  /// Empty-state message on the Marketplace sources screen (issue #101)
  ///
  /// In en, this message translates to:
  /// **'Add a marketplace to browse ready-made packs.'**
  String get marketplaceSourcesEmptyMessage;

  /// Action label for adding a marketplace source (FAB, empty-state CTA, dialog title) (issue #101)
  ///
  /// In en, this message translates to:
  /// **'Add a marketplace'**
  String get marketplaceAddSource;

  /// Hint text for the marketplace URL field in the add-a-marketplace dialog (issue #101)
  ///
  /// In en, this message translates to:
  /// **'Marketplace URL'**
  String get marketplaceAddSourceUrlHint;

  /// Confirm button label in the add-a-marketplace dialog (issue #101)
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get marketplaceAddSourceConfirm;

  /// Error shown in the add-a-marketplace dialog when the URL could not be fetched/validated as a marketplace manifest (issue #101)
  ///
  /// In en, this message translates to:
  /// **'Could not add this marketplace. Check the URL and try again.'**
  String get marketplaceAddSourceError;

  /// Error shown in the add-a-marketplace dialog when the URL was already added as a source (issue #101)
  ///
  /// In en, this message translates to:
  /// **'This marketplace was already added.'**
  String get marketplaceAddSourceDuplicate;

  /// Menu entry + confirm-dialog button label for removing a marketplace source (issue #101)
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get marketplaceRemoveSourceAction;

  /// Confirm-dialog title for removing a marketplace source (issue #101)
  ///
  /// In en, this message translates to:
  /// **'Remove marketplace?'**
  String get marketplaceRemoveSourceTitle;

  /// Confirm-dialog body for removing a marketplace source, with its name; sets already imported from it are kept (issue #101)
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\"? Sets you already imported from it stay in your Library.'**
  String marketplaceRemoveSourceMessage(String name);

  /// Empty-state title on the Marketplace Packs screen when a source has no packs (issue #101)
  ///
  /// In en, this message translates to:
  /// **'No packs yet'**
  String get marketplacePacksEmptyTitle;

  /// Empty-state message on the Marketplace Packs screen (issue #101)
  ///
  /// In en, this message translates to:
  /// **'This marketplace has no packs yet.'**
  String get marketplacePacksEmptyMessage;

  /// Empty-state title on the Marketplace Sets screen when a pack has no sets (issue #101)
  ///
  /// In en, this message translates to:
  /// **'No sets yet'**
  String get marketplaceSetsEmptyTitle;

  /// Empty-state message on the Marketplace Sets screen (issue #101)
  ///
  /// In en, this message translates to:
  /// **'This pack has no sets yet.'**
  String get marketplaceSetsEmptyMessage;

  /// Error shown in place of the list/preview on any Marketplace screen when a fetch fails (no network, broken source, bad response) (issue #101)
  ///
  /// In en, this message translates to:
  /// **'Could not load this marketplace. Check your connection and try again.'**
  String get marketplaceFetchError;

  /// Creator line on the Marketplace Set preview screen (issue #101)
  ///
  /// In en, this message translates to:
  /// **'Created by {creator}'**
  String marketplacePreviewCreatedBy(String creator);

  /// Number of sets in a pack, shown in the library section header (issue #121)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No sets} =1{1 set} other{{count} sets}}'**
  String packSetCount(int count);

  /// Screen-reader label of an expanded library pack header (issue #121)
  ///
  /// In en, this message translates to:
  /// **'{title}, {count, plural, =1{1 set} other{{count} sets}}, expanded. Tap to collapse.'**
  String packHeaderExpanded(String title, int count);

  /// Screen-reader label of a collapsed library pack header (issue #121)
  ///
  /// In en, this message translates to:
  /// **'{title}, {count, plural, =1{1 set} other{{count} sets}}, collapsed. Tap to expand.'**
  String packHeaderCollapsed(String title, int count);

  /// Hint inside an empty own pack in the library (issue #121)
  ///
  /// In en, this message translates to:
  /// **'This pack has no sets yet.'**
  String get packEmptyHint;

  /// Action in an empty own pack that creates a set in it (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Add set'**
  String get packAddSet;

  /// Label of the pack picker when creating/importing a set (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Pack'**
  String get packPickerLabel;

  /// Picker entry that reveals the inline new-pack field (issue #121)
  ///
  /// In en, this message translates to:
  /// **'New pack…'**
  String get packPickerNewPack;

  /// Label of the inline new-pack title field (issue #121)
  ///
  /// In en, this message translates to:
  /// **'New pack title'**
  String get packNewTitleLabel;

  /// Button creating the inline new pack (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Create pack'**
  String get packNewCreate;

  /// Title of the dialog asking for the target pack of a file import (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Import into which pack?'**
  String get packImportTitle;

  /// Title of the pack management screen and its app bar action tooltip (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Packs'**
  String get packManageTitle;

  /// Badge/subtitle marking a downloaded pack (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get packDownloadedLabel;

  /// Pack menu entry and rename dialog title (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Rename pack'**
  String get packRename;

  /// Pack menu entry (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Delete pack'**
  String get packDelete;

  /// Tooltip of a pack's three-dot menu (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Pack actions'**
  String get packActions;

  /// Confirm title for deleting a pack (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Delete this pack?'**
  String get packDeleteTitle;

  /// Confirm body for deleting a pack, with the number of sets that go with it (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\" together with {count, plural, =0{no sets} =1{its 1 set} other{its {count} sets}}? This cannot be undone.'**
  String packDeleteMessage(String title, int count);

  /// Set menu entry moving an own set to another own pack (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Move to pack…'**
  String get moveToPack;

  /// Title of the move-set dialog (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Move to which pack?'**
  String get moveToPackTitle;

  /// Marketplace pack screen primary action when the pack is not downloaded yet (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Download pack'**
  String get marketplaceDownloadPack;

  /// Marketplace pack screen primary action when the pack has updates (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Update pack'**
  String get marketplaceUpdatePack;

  /// Disabled marketplace pack action when everything is current (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Pack is up to date'**
  String get marketplacePackUpToDate;

  /// Progress text during a pack download/update (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Downloading set {done} of {total}…'**
  String marketplaceDownloadProgress(int done, int total);

  /// Error banner after a failed pack download/update (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Download failed — nothing was saved. Check your connection and try again.'**
  String get marketplaceDownloadFailed;

  /// Snackbar after a successful pack download (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Pack added to your Library.'**
  String get marketplacePackDownloaded;

  /// Snackbar after a successful pack update (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Pack updated.'**
  String get marketplacePackUpdated;

  /// Dialog title when a pack update would overwrite locally edited sets (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Overwrite your local edits?'**
  String get marketplacePackOverwriteTitle;

  /// Dialog body listing locally edited sets (issue #121)
  ///
  /// In en, this message translates to:
  /// **'You edited these sets since downloading them:\n{sets}\n\nOverwriting replaces them with the marketplace version — matching items keep their progress, others start fresh.'**
  String marketplacePackOverwriteMessage(String sets);

  /// Overwrite button of the pack update dialog (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get marketplacePackOverwriteConfirm;

  /// Skip button of the pack update dialog (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Skip these sets'**
  String get marketplacePackOverwriteSkip;

  /// Heading above the read-only set preview list (issue #121)
  ///
  /// In en, this message translates to:
  /// **'Sets in this pack'**
  String get marketplacePackSetsHeading;

  /// Screen-reader description of the Android home-screen widget: streak length and today's XP progress (issue #115)
  ///
  /// In en, this message translates to:
  /// **'{streakCount, plural, =1{1 day streak} other{{streakCount} day streak}}, {earnedXp} of {goalXp} XP today'**
  String widgetSemanticsLabel(int streakCount, int earnedXp, int goalXp);

  /// Encouraging line on the Android home-screen widget when the streak is at risk (streak > 0, no activity yet today) (issue #115)
  ///
  /// In en, this message translates to:
  /// **'Practice today to keep your streak!'**
  String get widgetAtRiskText;

  /// Home banner: one downloaded pack has new content (issue #125)
  ///
  /// In en, this message translates to:
  /// **'New content in {title}'**
  String packUpdateBannerOne(String title);

  /// Home banner: several downloaded packs have updates (issue #125)
  ///
  /// In en, this message translates to:
  /// **'Updates available for {count} packs'**
  String packUpdateBannerMany(int count);

  /// Home pack-update banner action button (issue #125)
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get packUpdateAction;

  /// Screen-reader label of the pack-update banner close button (issue #125)
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get packUpdateDismiss;

  /// Pack-update banner text while updating (issue #125)
  ///
  /// In en, this message translates to:
  /// **'Updating packs… {done} of {total} sets'**
  String packUpdateProgress(int done, int total);

  /// Pack-update banner success confirmation (issue #125)
  ///
  /// In en, this message translates to:
  /// **'Packs updated'**
  String get packUpdateSuccess;

  /// Pack-update banner failure text (issue #125)
  ///
  /// In en, this message translates to:
  /// **'The update did not finish. Check your connection and try again.'**
  String get packUpdateFailed;

  /// Pack-update banner failure text when some packs already updated (issue #125)
  ///
  /// In en, this message translates to:
  /// **'Some packs are updated. The rest did not finish – check your connection and try again.'**
  String get packUpdateFailedPartial;

  /// Pack-update banner retry button (issue #125)
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get packUpdateRetry;
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
