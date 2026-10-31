# Issue 091: Coin shop — buy streak on ice with coins

Status: open | Priority: P3 | Type: feature | Refined-at: 2026-10-31

## Context

#065 already built coins end-to-end: `profile_stats.coinsTotal`, written
exclusively (today) by `PetService`'s coin-reward branch via
`StatsRepository.addCoins`, and displayed on Home via `CoinBadge`
(`lib/src/widgets/coin_badge.dart`) — currently display-only (its own doc
comment says "no tap target, no spending mechanic yet") and only rendered
when `profile.coinsTotal > 0` (`lib/src/home/home_screen.dart`).

`streakFreezesAvailable` does **not exist yet**. It's fully specified in
#087 ("Streak on ice"), which is itself still open and blocked on #085
(Wheel of Fortune, also open). #087 already plans a single repository
method that increments/decrements `streakFreezesAvailable`, mirroring
`addCoins`'s shape, specifically so a future "buy ice" issue could reuse
it without adding its own column or method — that issue is this one.

**This issue is blocked on #087 landing first** (schema column +
increment/decrement method). #091 only adds the spend-coins side and the
shop UI; it adds zero new repository surface for `streakFreezesAvailable`.

Home already has precedent for turning a read-only badge into a tappable
entry point: `StreakBadge` is wrapped in an `InkWell`
(`Key('streakBadgeButton')`) that pushes `StreakDetailsScreen` via
`Navigator.of(context).push<void>(MaterialPageRoute<void>(...))`. This
issue follows the same pattern for `CoinBadge`.

## Goal

Let users spend coins to buy a "streak on ice" directly, instead of only
winning one from the Wheel of Fortune (#085/#087). Tapping the coin badge
on Home opens a new coin shop screen showing the user's current coin
balance and current streak-on-ice count, with a buy button for one more
streak on ice at a fixed price of 2500 coins.

## Decisions

- **Dependency**: blocked on #087 (and transitively #085). Do not start
  implementation until #087's `streakFreezesAvailable` column and its
  increment/decrement repository method exist.
- **Entry point — `CoinBadge` becomes tappable, visibility unchanged**:
  keep the existing `profile.coinsTotal > 0` gate on Home as-is (no new
  always-visible shop icon); when the badge is shown, wrap it in an
  `InkWell` (mirroring `streakBadgeButton`) that pushes a new
  `CoinShopScreen`. No shop entry point when the user has never earned a
  coin.
- **Spend-coins API — new `spendCoins(int amount)` method**, kept
  separate from `addCoins` for clearer intent (not `addCoins` with a
  negative amount). Guards against the balance going negative (no-op or
  throws if `amount > coinsTotal` — exact behavior at implementation time,
  but the UI's disabled-button state below means this should only be hit
  defensively, not as the primary guard). `StatsRepository`'s class-level
  ownership comment for `coinsTotal` is updated to name both callers
  (`PetService`'s coin-reward branch adds, the coin shop subtracts).
- **Streak-freeze API — reuse #087's method, no new method in #091**:
  buying calls #087's increment/decrement method with `+1`. #091 does not
  define its own method for `streakFreezesAvailable`.
- **Price — fixed at 2500 coins**, no bulk pricing/discounts in scope.
- **Stockpile — uncapped**, matching #087's "no maximum" decision for
  wheel wins. The buy button's only gate is affordability.
- **Buy flow — confirm dialog, repeatable**: tapping "buy" shows a
  `FoxConfirmDialog` (title/message/confirm/cancel, `danger: false` since
  this isn't a destructive action); confirming calls `spendCoins(2500)`
  then #087's increment method. The buy button stays enabled afterward so
  the user can buy another immediately if they can still afford it, and
  is disabled/greyed out once balance < 2500 (checked live against the
  watched profile, not just at dialog-open time).
- **Purchase feedback — banner + haptic**: on successful purchase, show a
  `FoxFeedbackBanner.success` (or `.withIcon`) confirming the buy, plus a
  `FoxFeedback.success` haptic buzz — consistent with other reward/spend
  moments in the app, gated the same way existing haptics are
  (`foxHapticsEnabledProvider`).
- **Screen layout**: new `lib/src/shop/coin_shop_screen.dart` (new
  `lib/src/shop/` directory — this isn't lesson/pet/stats related). Shows
  the coin balance and streak-on-ice count using the existing kit
  components where they fit (`CoinBadge` for the balance; a new, small
  streak-on-ice count display — reuse `FoxSemanticColors`' icy-blue token
  from #087 if that lands first, otherwise a placeholder color is fine
  since #087 owns finalizing it), and a `FoxPrimaryButton` "Buy" action.
  Standard back navigation (`AppBar` back arrow), no `PopScope` lock —
  unlike reward screens, nothing here is lost by backing out.
- **Localization**: new DE+EN arb strings for the shop screen title, buy
  button label, confirm dialog title/message (interpolating the 2500
  price), the streak-on-ice count label/semantics, and the success
  feedback message — following existing naming (`homeCoinsCountLabel`,
  `coinsSemanticLabel` precedent), e.g. `coinShopTitle`,
  `coinShopBuyButtonLabel`, `coinShopConfirmTitle`,
  `coinShopConfirmMessage`, `coinShopPurchaseSuccessMessage`,
  `coinShopStreakOnIceCountLabel`.

## Acceptance criteria

- [ ] `StatsRepository.spendCoins(int amount)` deducts from `coinsTotal`;
  doc comment on `coinsTotal` updated to list both callers (add/spend).
- [ ] `CoinBadge` on Home is wrapped in an `InkWell`
  (`Key('coinBadgeButton')`) that pushes `CoinShopScreen`; visibility
  stays gated on `profile.coinsTotal > 0`, unchanged from today.
- [ ] `CoinShopScreen` displays the current coin balance and current
  `streakFreezesAvailable` count, both live (via the watched profile
  provider, updating immediately after a purchase).
- [ ] A "Buy" button, labelled with the 2500-coin price, is disabled when
  `coinsTotal < 2500` and enabled otherwise.
- [ ] Tapping "Buy" while enabled shows a `FoxConfirmDialog`; confirming
  calls `spendCoins(2500)` and #087's increment method (+1), and shows a
  success banner + haptic. Cancelling/dismissing the dialog does nothing.
- [ ] After a successful buy, the user can immediately buy again if
  `coinsTotal` is still ≥ 2500 — no one-buy-per-visit limit, no stockpile
  cap.
- [ ] New DE+EN l10n strings added for all new user-visible copy; no
  hardcoded strings in `CoinShopScreen` or the confirm dialog.
- [ ] Tests: a `StatsRepository` test for `spendCoins` (including the
  insufficient-balance guard), and a widget test covering the Home →
  CoinShopScreen navigation and the disabled/enabled buy-button states.
- [ ] `flutter analyze` and `dart format` clean; `flutter test` green.

## Out of scope

- Implementing #087/#085 themselves (hard dependency, not duplicated
  here).
- Bulk pricing, discounts, or any price other than the fixed 2500.
- Any other shop item besides streak on ice (a single-item shop screen
  for now).
