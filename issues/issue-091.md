# Issue 091: Coin shop — buy streak on ice with coins

Status: open

## Goal

Let users spend coins (`profile_stats.coinsTotal`, earned via #065/#085)
to buy a "streak on ice" (`streakFreezesAvailable`, from #087) directly,
instead of only winning one from the Wheel of Fortune. Tapping the coin
badge on the Home screen opens a new coin shop screen showing the user's
current coin balance, their current streak-on-ice count, and a buy button
for one more streak on ice at a fixed price of 2500 coins.

## Context

- Coins already exist end-to-end: `profile_stats.coinsTotal` (#065),
  written via `StatsRepository.addCoins`, displayed on Home via
  `CoinBadge` (`lib/src/widgets/coin_badge.dart`) — currently
  display-only (no tap target) and only rendered when
  `profile.coinsTotal > 0` (`lib/src/home/home_screen.dart`).
- `streakFreezesAvailable` does **not exist yet** — it's specified in
  #087 ("Streak on ice"), which is itself still open/unimplemented and
  blocked on #085 (Wheel of Fortune, also open). #087's design explicitly
  anticipates this: "Buying streak-on-ice directly (separate from winning
  one) is a later, separate issue" and "A future 'buy ice' issue reuses
  the same increment method."
- **Decision: this issue depends on #087.** Build after #087 lands (schema
  column + increment method), then add the spend/decrement side plus the
  shop UI here. Don't duplicate the schema work.
- **Decision: entry point stays `coinsTotal > 0`-gated.** Keep
  `CoinBadge`'s existing visibility rule as-is; just make it tappable
  (opens the coin shop) when it's shown. No new always-visible shop icon.
- **Decision: buy flow — confirm dialog, repeatable.** Tapping "buy" shows
  a `FoxConfirmDialog`; confirming deducts 2500 coins and increments
  `streakFreezesAvailable` by 1. The buy button stays enabled afterward so
  the user can buy another immediately if they can still afford it, and
  is disabled/greyed out once balance < 2500.

## Open questions for refinement

- Repository method shape for spending coins (mirrors `addCoins`? e.g.
  `spendCoins(int amount)` with a guard against negative balance) and for
  decrementing `streakFreezesAvailable` (#087 adds the increment side —
  does this issue add decrement, or does #087's method already support
  negative deltas?).
- Exact screen layout/navigation: how is the coin shop screen reached
  (push route from Home?), what's shown for balance/count (reuse
  `CoinBadge` and a streak-on-ice equivalent badge?), and what's the
  screen's title/back behavior.
- Feedback on successful purchase (toast/banner, haptics via
  `FoxFeedback`?) vs. silent balance update.
- Localization strings (DE + EN via `lib/l10n` arb) for the shop screen,
  price, and confirm dialog copy.
- Any upper bound on `streakFreezesAvailable` via purchase (uncapped, per
  #087's "no maximum" decision for wins)?
- Price is fixed at 2500 coins for now — confirm no future bulk-pricing
  or discount scope creep.
