# Issue 080: Show coin balance on Home

Status: open | Refined-at: 2026-10-26

## Goal

Surface the player's lifetime coin balance (`profileStats.coinsTotal`,
written by #065's lootbox coin-flip reward) on the Home dashboard, in the
upper-right area of the screen — but only once the player actually has
coins, so a brand-new player with a zero balance never sees it.

## Decisions (2026-10-26, with repo owner)

- **Placement — top-right of the greeting row**: the coin badge sits at
  the right edge of Home's existing greeting row (`lib/src/home/home_screen.dart`,
  the "Hi, `<name>`" `InkWell` that's currently the first item in the
  scrollable column), not in the system `AppBar`. It's the first thing
  visible in the upper-right corner on initial load, and scrolls away with
  the rest of the dashboard like every other Home widget — consistent
  with `StreakBadge`/`FoxLevelProgressBar`/`FoxGoalRing` all already living
  in the scrollable body rather than the `AppBar`.
- **Visual — a pill badge, same shape as `StreakBadge`**: icon + number in
  a rounded pill with a tinted background
  (`lib/src/widgets/streak_badge.dart`'s existing shape — `Container` with
  `FoxRadius.pill`, `FoxSpacing.lg`/`sm` padding, `Row` of icon + bold
  number), for visual consistency with the other Home stat badges rather
  than a bare `AppBar`-style icon+text.
- **Icon — a Material icon, not an asset**: a coin/currency Material icon
  (e.g. `Icons.monetization_on`), not the Lottie/emoji coin asset already
  used for the lootbox coin-reveal
  (`assets/noto-emoji/other/emoji_u1fa99_lottie.json`) — that asset is a
  one-off reveal effect (#065), not a persistent-badge icon, and pulling a
  Lottie into a small always-on badge is unnecessary weight.
- **Color — new dedicated `FoxSemanticColors.coin`/`onCoin` token**, not a
  reuse of the existing `gold`/`goldInk` token. `gold`/`goldInk` is
  documented and already used specifically for XP
  (`fox_streak_theme.dart`'s `FoxSemanticColors` doc comment: "vivid fill
  for XP progress/badges"); coins are a visually distinct currency from XP
  and should read as their own color, not XP's color repurposed. New
  light + dark values must pass the same AA-contrast bar as the existing
  tokens (content-color-on-surface for `coin`/`coinInk` if a surface-safe
  variant is needed, `onCoin` for text/icons on a `coin` fill) — exact hex
  values are an implementation detail, follow the existing token's
  light/dark derivation pattern (content color darkened for light theme,
  lightened for dark theme).
- **Display-only, no tap action**: the badge is not a button — there's no
  spending mechanic yet (coins are only earned via the lootbox today, per
  #065's "no spending, no UI balance yet" decision, which this issue
  partially lifts by adding the balance display but still doesn't add
  spending) and no coin-detail screen to navigate to. No `InkWell`,
  no `Semantics(button: true)`.
- **Visibility — hidden entirely at zero, shown otherwise**: when
  `profile.coinsTotal == 0` the badge renders nothing (not a "0" badge,
  not a greyed-out placeholder) — same precedent as #064's unsurfaced
  mascot-count badge before #069 added it. Once `coinsTotal > 0` it
  appears and stays visible (coins are never currently spent, so this is
  monotonic for now); it already updates reactively because `profile`
  comes from the existing `profileProvider` stream Home already watches —
  no new provider needed.
- **Copy**: a new plain-number display string (mirroring
  `streakCountLabel`'s `"{streakCount}"` / German identical pattern — no
  ICU plural needed, same precedent as the streak count) for the number
  shown in the pill, plus an a11y announcement. The existing
  `coinsSemanticLabel` ("{amount} coins" / "{amount} Münzen", added by
  #065 for the lootbox coin-reveal) is reused verbatim for the badge's
  `Semantics.label` rather than adding a near-duplicate string — its arb
  `@coinsSemanticLabel` description comment is broadened to mention this
  second use site.

## Acceptance criteria

- [ ] A new `CoinBadge` widget (`lib/src/widgets/coin_badge.dart`, added to
  the `widgets.dart` barrel) renders an icon + number in a pill, shaped
  like `StreakBadge`, tinted with the new `FoxSemanticColors.coin`/`onCoin`
  token.
- [ ] `FoxSemanticColors` gains `coin`/`onCoin` fields with AA-checked
  light + dark values, wired through its `copyWith`/`lerp`/`light`/`dark`
  definitions alongside the existing tokens.
- [ ] Home's greeting row (`home_screen.dart`) places `CoinBadge` at its
  right edge, passing `profile.coinsTotal`; the badge is not rendered at
  all when `profile.coinsTotal == 0`.
- [ ] The badge has no tap target — no `InkWell`/`onTap`, no
  `Semantics(button: true)`.
- [ ] New l10n strings (DE + EN): a plain-number display string for the
  pill (e.g. `homeCoinsCountLabel`: `"{amount}"`); `coinsSemanticLabel` is
  reused for the `Semantics.label` (its arb description comment updated to
  note the Home-badge use alongside the lootbox-reveal use).
- [ ] A widget test confirms the badge is absent when `coinsTotal` is `0`
  and present (correct number + a11y label) when `coinsTotal > 0`, on
  Home.
- [ ] A golden test (or an added case in the existing `kit_golden_test.dart`
  pattern) covers `CoinBadge` under both `FoxStreakTheme.light()` and
  `.dark()`.
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
  `dart fix --dry-run`, and `flutter test` are all clean per AGENTS.md's
  Verify section.

## Tasks

1. In `lib/src/theme/fox_streak_theme.dart`: add `coin`/`onCoin` fields to
   `FoxSemanticColors` (constructor, `light`, `dark`, `copyWith`, `lerp`),
   with AA-checked values following the existing tokens' derivation
   pattern.
2. Add `lib/src/widgets/coin_badge.dart`: a `CoinBadge` `StatelessWidget`
   taking `coinsTotal` (or a pre-formatted label, mirroring `StreakBadge`'s
   `streakCountLabel`/`semanticsLabel` constructor shape) and rendering the
   pill; export it from `lib/src/widgets/widgets.dart`.
3. In `lib/src/home/home_screen.dart`: wrap the existing greeting `InkWell`
   and a conditionally-rendered `CoinBadge` in a `Row`, right-aligning the
   badge; only build it when `profile.coinsTotal > 0`.
4. l10n: add `homeCoinsCountLabel` (DE + EN, plain `"{amount}"`); update
   `@coinsSemanticLabel`'s description comment in both arb files to note
   the new Home-badge use; regenerate `app_localizations*.dart`.
5. Add the widget test (badge absent/present) and the golden-test case per
   the acceptance criteria.

## Out of scope

- Any spending mechanic for coins (the "streak on ice" motivation from
  #065) — this issue only displays the balance.
- Any animation/celebration tying a lootbox coin win to the Home badge
  (e.g. a count-up or pulse when the balance changes) — the badge just
  reflects current state, same as `StreakBadge`.
- Number formatting for large balances (thousands separators, abbreviated
  "1.2k", etc.) — plain integer interpolation, same precedent as
  `levelProgressText`'s raw XP numbers.
- Any change to how coins are earned (#065) or how often lootboxes trigger
  (#067).

## Dependencies

- Builds on #065 (`profileStats.coinsTotal`, `StatsRepository.addCoins`,
  `coinsSemanticLabel`) — this issue only adds a read/display path, no
  schema change.
- Builds on #015's `FoxSemanticColors` token system and `StreakBadge`'s
  established pill shape (#011) as the visual precedent.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```
