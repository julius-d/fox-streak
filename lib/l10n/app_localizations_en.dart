// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String setItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

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
  String deleteSetMessage(String title) {
    return 'Delete \"$title\" with all its items? This cannot be undone.';
  }

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
  String exerciseDirectionLabel(String fromLanguage, String toLanguage) {
    return '$fromLanguage → $toLanguage';
  }

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
  String itemDistractorLabel(int index) {
    return 'Distractor $index';
  }

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
  String exercisePhoneWrongAnswer(String answer) {
    return 'The number was $answer';
  }

  @override
  String get exerciseDateRevealHintAria => 'Reveal the date (costs hint bonus)';

  @override
  String get exerciseFreeTextPlaceholder => 'Type the answer';

  @override
  String get exerciseFreeTextRevealHintAria =>
      'Reveal the first letter (costs hint bonus)';

  @override
  String exerciseFreeTextHintLabel(String letter) {
    return 'Starts with: $letter';
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
    return '$label, option $position of $total';
  }

  @override
  String get lessonEmptySetNote => 'Add items to start practicing!';

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
  String lessonWrongAnswer(String answer) {
    return 'The answer was $answer';
  }

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
  String lessonScoreSummary(int correct, int total, int pct) {
    return '$correct of $total correct ($pct%)';
  }

  @override
  String xpEarnedLabel(int xp) {
    return '+$xp XP';
  }

  @override
  String lessonXpBonusCallout(int bonus) {
    return '+$bonus Perfect!';
  }

  @override
  String lessonLevelUpCallout(int level) {
    return 'Level Up! Level $level';
  }

  @override
  String levelLabel(int level) {
    return 'Level $level';
  }

  @override
  String get levelProgressLabel => 'Progress to next level';

  @override
  String levelProgressText(int xpIntoLevel, int xpForNextLevel) {
    return '$xpIntoLevel / $xpForNextLevel XP to next level';
  }

  @override
  String lessonStreakResultText(int streakCount) {
    return '$streakCount-day streak!';
  }

  @override
  String streakCountLabel(int streakCount) {
    return '$streakCount';
  }

  @override
  String get streakTodayDoneLabel => 'Today\'s lesson counted';

  @override
  String get lessonPracticeAgain => 'Practice again';

  @override
  String get lessonBackToLibrary => 'Back to library';

  @override
  String get lessonBackToHome => 'Back to home';

  @override
  String get homeGreetingNight => 'Up late?';

  @override
  String homeGreetingNightNamed(String name) {
    return 'Up late, $name?';
  }

  @override
  String get homeGreetingMorning => 'Good morning!';

  @override
  String homeGreetingMorningNamed(String name) {
    return 'Good morning, $name!';
  }

  @override
  String get homeGreetingAfternoon => 'Good afternoon!';

  @override
  String homeGreetingAfternoonNamed(String name) {
    return 'Good afternoon, $name!';
  }

  @override
  String get homeGreetingEvening => 'Good evening!';

  @override
  String homeGreetingEveningNamed(String name) {
    return 'Good evening, $name!';
  }

  @override
  String get homeGreetingNewYear => 'Happy New Year!';

  @override
  String get homeGreetingAprilFools => 'Watch out for pranks today!';

  @override
  String get homeGreetingHalloween => 'Happy Halloween!';

  @override
  String get homeGreetingChristmasEve => 'Christmas Eve is here!';

  @override
  String get homeGreetingChristmasDay => 'Merry Christmas!';

  @override
  String get homeGreetingFunny1 => 'Ready to level up today?';

  @override
  String get homeGreetingFunny2 => 'Your foxy brain is warming up!';

  @override
  String get homeGreetingFunny3 => 'Let\'s make today count!';

  @override
  String get homeGreetingFunny4 => 'Knowledge snacks, coming right up!';

  @override
  String get homeGreetingFunny5 => 'Time to feed the fox some facts!';

  @override
  String get homeGreetingFunny6 => 'Brain gains await!';

  @override
  String get homeGreetingFunny7 =>
      'Today\'s a great day to learn something new!';

  @override
  String get homeGreetingFunny8 => 'Fox mode: activated!';

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
  String homeGoalRingValue(int earnedXp, int goalXp) {
    return '$earnedXp / $goalXp XP today';
  }

  @override
  String homeGoalRingXp(int earnedXp) {
    return '$earnedXp XP';
  }

  @override
  String get homeGoalRingToday => 'today';

  @override
  String get homeOverflowMenuTooltip => 'More options';

  @override
  String get homeParentalInfoTooltip => 'For parents';

  @override
  String get homeSettingsMenuItem => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsHapticsLabel => 'Haptics';

  @override
  String get settingsHapticsSubtitle =>
      'Vibrate on correct and incorrect answers';

  @override
  String get settingsSoundLabel => 'Sound';

  @override
  String get settingsSoundSubtitle =>
      'Play chimes on level-up and correct answers';

  @override
  String get settingsDisplayNameLabel => 'Display name';

  @override
  String get settingsDisplayNameUnset => 'Not set';

  @override
  String get settingsDisplayNameDialogTitle => 'Display name';

  @override
  String get settingsDisplayNameHint => 'Enter your name (optional)';

  @override
  String get settingsDailyGoalLabel => 'Daily XP goal';

  @override
  String settingsDailyGoalSubtitle(int xp) {
    return '$xp XP';
  }

  @override
  String get settingsDailyGoalDialogTitle => 'Daily XP goal';

  @override
  String get settingsDailyGoalHint => 'Daily XP goal (10–500)';

  @override
  String get settingsDailyGoalValidationError =>
      'Enter a value between 10 and 500';

  @override
  String get parentalInfoTitle => 'For parents';

  @override
  String get parentalInfoBody =>
      'FoxStreak works fully offline on this device. There\'s no chat, no social features, and no ads. All progress stays local and is never uploaded anywhere.';

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

  @override
  String petSemanticLabel(String emoji) {
    return 'Pet $emoji';
  }

  @override
  String petEquippedSemanticLabel(String emoji) {
    return 'Pet $emoji, equipped';
  }

  @override
  String get petLockedSemanticLabel => 'Locked pet';

  @override
  String petRarityLabel(String rarity) {
    String _temp0 = intl.Intl.selectLogic(rarity, {
      'common': 'Common',
      'uncommon': 'Uncommon',
      'epic': 'Epic',
      'legendary': 'Legendary',
      'mythic': 'Mythic',
      'seasonal': 'Seasonal',
      'other': 'Common',
    });
    return '$_temp0';
  }

  @override
  String get homePetSemanticLabel => 'Open your pet collection';

  @override
  String get petCollectionTitle => 'Your pets';

  @override
  String get lootboxHeading => 'A lootbox for you!';

  @override
  String get lootboxTapPrompt => 'Tap to reveal your reward!';

  @override
  String lootboxRevealedTitle(String rarity) {
    String _temp0 = intl.Intl.selectLogic(rarity, {
      'common': 'You got a Common pet!',
      'uncommon': 'You got an Uncommon pet!',
      'epic': 'You got an Epic pet!',
      'legendary': 'You got a Legendary pet!',
      'mythic': 'You got a Mythic pet!',
      'seasonal': 'You got a Seasonal pet!',
      'other': 'You got a new pet!',
    });
    return '$_temp0';
  }

  @override
  String lootboxCoinsRevealedTitle(int amount) {
    return 'You won $amount coins!';
  }

  @override
  String coinsSemanticLabel(int amount) {
    return '$amount coins';
  }

  @override
  String get editItems => 'Edit items';

  @override
  String get newSetFabCollapseTooltip => 'Close';
}
