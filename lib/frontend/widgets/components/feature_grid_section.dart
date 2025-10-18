import 'package:flutter/material.dart';

class FeatureGridItem {
  const FeatureGridItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color? accentColor;
}

class FeatureGridSection extends StatelessWidget {
  const FeatureGridSection({
    super.key,
    required this.items,
    required this.crossAxisCount,
    this.gap = 18,
  });

  final List<FeatureGridItem> items;
  final int crossAxisCount;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (crossAxisCount <= 1) {
      return SliverList.separated(
        itemBuilder: (context, index) => _FeatureCard(item: items[index]),
        separatorBuilder: (_, __) => SizedBox(height: gap),
        itemCount: items.length,
      );
    }

    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _FeatureCard(item: items[index]),
        childCount: items.length,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: gap,
        mainAxisSpacing: gap,
        childAspectRatio: 1.2,
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.item});

  final FeatureGridItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final accent = item.accentColor ?? theme.colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: item.onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(item.icon, color: accent, size: 28),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              item.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                item.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Esplora',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.arrow_outward_rounded, color: accent, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
