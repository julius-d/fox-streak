// Library grouping by pack (issue #121): pure grouping + the collapsible
// section header.

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../data/packs_repository.dart';
import '../theme/fox_streak_theme.dart';

/// One pack with its sets, in library order.
class PackSection {
  final Pack pack;
  final List<QuestionSet> sets;

  const PackSection(this.pack, this.sets);
}

/// Groups [sets] under their pack, keeping [packs]' order (own first, then
/// downloaded) and each pack's sets in their given order. Packs without sets
/// still get a (empty) section.
List<PackSection> groupSetsByPack(List<Pack> packs, List<QuestionSet> sets) {
  return [
    for (final pack in packs)
      PackSection(pack, [
        for (final set in sets)
          if (set.packId == pack.id) set,
      ]),
  ];
}

/// Tappable section header: wrapping title, set count, expand/collapse
/// chevron. 48dp minimum target; announces its collapsed/expanded state.
class PackSectionHeader extends StatelessWidget {
  final Pack pack;
  final int setCount;
  final VoidCallback onToggle;

  const PackSectionHeader({
    super.key,
    required this.pack,
    required this.setCount,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final semanticsLabel = pack.collapsed
        ? l10n.packHeaderCollapsed(pack.title, setCount)
        : l10n.packHeaderExpanded(pack.title, setCount);
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onToggle,
      child: InkWell(
        key: Key('packHeader-${pack.id}'),
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: FoxButtonMetrics.minSize,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FoxSpacing.lg,
              vertical: FoxSpacing.sm,
            ),
            child: Row(
              children: [
                if (pack.isDownloaded) ...[
                  Icon(
                    Icons.cloud_download_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: FoxSpacing.sm),
                ],
                Expanded(
                  child: Text(pack.title, style: theme.textTheme.titleMedium),
                ),
                const SizedBox(width: FoxSpacing.sm),
                Text(
                  l10n.packSetCount(setCount),
                  style: theme.textTheme.bodySmall,
                ),
                Icon(pack.collapsed ? Icons.expand_more : Icons.expand_less),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
