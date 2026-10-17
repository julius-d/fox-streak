import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'l10n/app_localizations.dart';
import 'src/home/home_screen.dart';
import 'src/theme/fox_streak_theme.dart';

void main() async {
  if (Platform.isMacOS || Platform.isWindows) {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(size: Size(390, 844), center: true),
    );
    await windowManager.show();
    await windowManager.focus();
  }
  runApp(const ProviderScope(child: FoxStreakApp()));
}

class FoxStreakApp extends StatelessWidget {
  const FoxStreakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoxStreak',
      debugShowCheckedModeBanner: false,
      theme: FoxStreakTheme.light(),
      darkTheme: FoxStreakTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeScreen(),
    );
  }
}
