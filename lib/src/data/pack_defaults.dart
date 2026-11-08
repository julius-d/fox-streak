// Default own pack naming (issue #121).

import 'dart:ui' show PlatformDispatcher;

/// Title of the auto-created own pack: "My sets" / DE "Meine Sets", picked
/// from the device language (the data layer has no `BuildContext`).
String defaultPackTitle() =>
    PlatformDispatcher.instance.locale.languageCode == 'de'
    ? 'Meine Sets'
    : 'My sets';
