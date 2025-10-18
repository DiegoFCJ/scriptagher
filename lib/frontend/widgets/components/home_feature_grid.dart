import 'package:flutter/material.dart';

class HomeFeatureGrid extends StatelessWidget {
  const HomeFeatureGrid({
    super.key,
    required this.features,
  });

  final List<HomeFeatureItem> features;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mediaQueryWidth = MediaQuery.of(context).size.width;
          final maxWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
              ? constraints.maxWidth
              : mediaQueryWidth;

          final crossAxisCount = _crossAxisCountFor(maxWidth);
          final spacing = crossAxisCount > 1 ? 24.0 : 20.0;
          final horizontalGaps = crossAxisCount > 1
              ? (crossAxisCount - 1) * spacing
              : 0.0;
          final availableWidth = (maxWidth - horizontalGaps).clamp(0.0, maxWidth);
          final tileWidth = crossAxisCount == 1
              ? maxWidth
              : availableWidth / crossAxisCount;

          final aspectRatio = crossAxisCount == 1 ? 16 / 9 : 4 / 3;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final feature in features)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: tileWidth,
                    minWidth: tileWidth,
                  ),
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: _FeatureCard(feature: feature),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  int _crossAxisCountFor(double width) {
    if (width >= 1200) return 3;
    if (width >= 760) return 2;
    return 1;
  }
}

class HomeFeatureItem {
  const HomeFeatureItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    required this.accentColor,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});

  final HomeFeatureItem feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final brightness = ThemeData.estimateBrightnessForColor(feature.accentColor);
    final foregroundColor = brightness == Brightness.dark
        ? Colors.white
        : theme.colorScheme.onSurface.withOpacity(0.9);

    return Material(
      elevation: 4,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: feature.onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                feature.accentColor.withOpacity(0.85),
                feature.accentColor,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: feature.accentColor.withOpacity(0.24),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: foregroundColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(feature.icon, size: 28, color: foregroundColor),
              ),
              const SizedBox(height: 18),
              Text(
                feature.title,
                style: textTheme.headlineSmall?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  feature.description,
                  style: textTheme.bodyLarge?.copyWith(
                    color: foregroundColor.withOpacity(0.85),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Apri',
                    style: textTheme.labelLarge?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: foregroundColor, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
