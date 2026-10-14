// Static parental info screen (issue #012): local-only, no chat, no ads.
//
// Reachable from Home's app bar. Pure copy, no state, no data access.
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/fox_streak_theme.dart';

class ParentalInfoScreen extends StatelessWidget {
  const ParentalInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      key: const Key('parentalInfoScreen'),
      appBar: AppBar(title: Text(l10n.parentalInfoTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FoxSpacing.xl),
          child: Text(
            l10n.parentalInfoBody,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
