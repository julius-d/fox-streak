import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'src/library/library_screen.dart';
import 'src/theme/fox_streak_theme.dart';

void main() {
  runApp(const ProviderScope(child: FoxStreakApp()));
}

class FoxStreakApp extends StatelessWidget {
  const FoxStreakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoxStreak',
      theme: FoxStreakTheme.light(),
      darkTheme: FoxStreakTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LibraryScreen(),
    );
  }
}
