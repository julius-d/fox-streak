// Coin shop screen (issue #091).
//
// Reached by tapping Home's CoinBadge (mirrors #084's StreakBadge ->
// StreakDetailsScreen entry point). A single-item shop for now: buy one
// streak on ice for a fixed price, reusing #087's `addStreakFreezes`
// increment rather than adding a new repository method for the freeze
// balance — this issue only adds the spend-coins side.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../data/providers.dart';
import '../stats/stats_providers.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';

/// Fixed price of one streak on ice, in coins — no bulk pricing/discounts
/// in scope (issue #091).
const int kStreakOnIcePriceCoins = 2500;

class CoinShopScreen extends ConsumerStatefulWidget {
  const CoinShopScreen({super.key});

  @override
  ConsumerState<CoinShopScreen> createState() => _CoinShopScreenState();
}

class _CoinShopScreenState extends ConsumerState<CoinShopScreen> {
  // Screen-scoped only (not persisted/one-time like #087's Home banner) —
  // shown after any successful buy for the rest of this visit, repeatable
  // on each purchase.
  bool _showPurchaseSuccess = false;

  Future<void> _buy(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool? confirmed = await FoxConfirmDialog.show(
      context: context,
      title: l10n.coinShopConfirmTitle,
      message: l10n.coinShopConfirmMessage(kStreakOnIcePriceCoins),
      confirmLabel: l10n.coinShopBuyButtonLabel(kStreakOnIcePriceCoins),
      cancelLabel: l10n.cancel,
      danger: false,
      confirmKey: const Key('coinShopConfirmBuyButton'),
      cancelKey: const Key('coinShopCancelBuyButton'),
    );
    if (confirmed != true) return;

    final statsRepo = ref.read(statsRepositoryProvider);
    final bool spent = await statsRepo.transaction(() async {
      final bool spent = await statsRepo.spendCoins(kStreakOnIcePriceCoins);
      if (spent) await statsRepo.addStreakFreezes(1);
      return spent;
    });
    if (!spent || !context.mounted) return;
    setState(() => _showPurchaseSuccess = true);
    await FoxFeedback.success(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final AsyncValue<ProfileStat> profileAsync = ref.watch(profileProvider);
    return Scaffold(
      key: const Key('coinShopScreen'),
      appBar: AppBar(title: Text(l10n.coinShopTitle)),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text(e.toString())),
        data: (ProfileStat profile) {
          final bool canAfford = profile.coinsTotal >= kStreakOnIcePriceCoins;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(FoxSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_showPurchaseSuccess) ...<Widget>[
                    FoxFeedbackBanner.success(
                      key: const Key('coinShopPurchaseSuccessBanner'),
                      message: l10n.coinShopPurchaseSuccessMessage,
                    ),
                    const SizedBox(height: FoxSpacing.lg),
                  ],
                  Center(
                    child: CoinBadge(
                      key: const Key('coinShopCoinBadge'),
                      coinsCountLabel: l10n.homeCoinsCountLabel(
                        profile.coinsTotal,
                      ),
                      semanticsLabel: l10n.coinsSemanticLabel(
                        profile.coinsTotal,
                      ),
                    ),
                  ),
                  const SizedBox(height: FoxSpacing.lg),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.ac_unit, color: foxSemantics(context).ice),
                        const SizedBox(width: FoxSpacing.sm),
                        Text(
                          l10n.coinShopStreakOnIceCountLabel(
                            profile.streakFreezesAvailable,
                          ),
                          key: const Key('coinShopStreakOnIceCountLabel'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FoxSpacing.xxl),
                  FoxPrimaryButton(
                    key: const Key('coinShopBuyButton'),
                    label: l10n.coinShopBuyButtonLabel(kStreakOnIcePriceCoins),
                    expanded: true,
                    onPressed: canAfford ? () => _buy(context) : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
