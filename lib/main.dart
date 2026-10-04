import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: FoxStreakApp()));
}

class FoxStreakApp extends StatelessWidget {
  const FoxStreakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoxStreak',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const BootstrapHomePage(),
    );
  }
}

class BootstrapHomePage extends StatelessWidget {
  const BootstrapHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FoxStreak')),
      body: const Center(
        child: Text(
          'FoxStreak bootstrap OK\n(Android + iOS + Windows)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
