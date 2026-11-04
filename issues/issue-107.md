# Issue 107: Lower streak-on-ice price to 400 coins

Status: open | Priority: P2 | Type: feature | Refined-at: 2026-11-04

## Context

#091 added the coin shop's single item — buying a "streak on ice" — at a
fixed price of 2500 coins, stored as `kStreakOnIcePriceCoins` in
`lib/src/shop/coin_shop_screen.dart`. In practice 2500 is too steep given
how slowly coins accumulate (coins are earned only via #065's lootbox
coin-flip reward), making the shop's single item feel unreachable. The
price is lowered to 400 coins.

## Goal

The coin shop's "buy streak on ice" price drops from 2500 to 400 coins.
Everything else about the coin shop (#091) — the confirm dialog, the
disabled/enabled buy-button gating, the uncapped stockpile, the success
banner/haptic — is unchanged; only the price constant moves.

## Decisions

- **New price: 400 coins, final** — not a placeholder/tunable value, no
  further balancing pass bundled into this issue.
- **Single source of truth**: only `kStreakOnIcePriceCoins` in
  `lib/src/shop/coin_shop_screen.dart` changes, from `2500` to `400`. The
  DE/EN `coinShop*` arb strings already interpolate `{price}` (added by
  #091), so no l10n copy changes are needed.
- **No economy changes beyond the constant**: coin earn rate (#065's
  lootbox coin-flip) and Wheel-of-Fortune streak-on-ice odds (#087) are
  out of scope here.

## Acceptance criteria

1. `kStreakOnIcePriceCoins` in `lib/src/shop/coin_shop_screen.dart` is
   `400`.
2. The coin shop's buy button reads "Buy for 400 coins" / "Für 400 Münzen
   kaufen" (via the existing interpolated `coinShopBuyButtonLabel`
   string, no arb changes needed).
3. The confirm dialog message reads "Spend 400 coins for one streak on
   ice?" / "400 Münzen für einen Streak-Freeze ausgeben?" (via the
   existing `coinShopConfirmMessage` string).
4. The buy button is disabled when `coinsTotal < 400` and enabled
   otherwise (same gating logic as #091, just against the new threshold).
5. Existing tests referencing the old `2500` price (repository tests in
   `test/data/stats_repository_test.dart`, and any coin-shop widget/
   integration test) are updated to the new `400` price so they keep
   covering the same behavior (sufficient-balance buy, insufficient-
   balance no-op/disabled state).

## Out of scope

- Changing how coins are earned (#065) or streak-on-ice wheel odds
  (#087).
- Bulk pricing, discounts, or any price other than the fixed 400.
- Any other shop item besides streak on ice.
