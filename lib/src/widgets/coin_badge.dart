// Coin balance badge, composed on the #015 kit (issue #080).
//
// Dumb/display-only, same shape as StreakBadge: a pill of icon + number,
// tinted via FoxSemanticColors.coin. Display-only — no tap target, no
// `Semantics(button: true)`, since there's no spending mechanic yet.
import 'package:flutter/material.dart';

import '../theme/fox_streak_theme.dart';

/// Coin icon + coin count in a pill, token-driven via
/// [FoxSemanticColors.coin].
class CoinBadge extends StatelessWidget {
  final String coinsCountLabel;
  final String semanticsLabel;

  const CoinBadge({
    super.key,
    required this.coinsCountLabel,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final coin = foxSemantics(context).coin;
    return Semantics(
      label: semanticsLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: FoxSpacing.lg,
          vertical: FoxSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: coin.withValues(alpha: 0.12),
          borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.pill)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on, color: coin),
            const SizedBox(width: FoxSpacing.sm),
            Text(
              coinsCountLabel,
              key: const Key('coinsCountLabel'),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: coin, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
