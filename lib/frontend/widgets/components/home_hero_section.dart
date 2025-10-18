import 'package:flutter/material.dart';

class HomeHeroSection extends StatelessWidget {
  const HomeHeroSection({
    super.key,
    required this.onExploreBots,
    required this.onOpenDocs,
  });

  final VoidCallback onExploreBots;
  final VoidCallback onOpenDocs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = colorScheme.onPrimary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Automatizza i tuoi flussi con Scriptagher',
              style: theme.textTheme.displaySmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Gestisci bot sicuri su ogni piattaforma, sincronizza marketplace, '
              'monitora esecuzioni e mantieni il controllo con un solo clic.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: foreground.withOpacity(0.85),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                _HeroHighlight(
                  icon: Icons.shield_rounded,
                  label: 'Runtime isolati',
                  color: foreground,
                ),
                _HeroHighlight(
                  icon: Icons.bolt_rounded,
                  label: 'Deploy immediati',
                  color: foreground,
                ),
                _HeroHighlight(
                  icon: Icons.dataset_rounded,
                  label: 'Gestione permessi',
                  color: foreground,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onExploreBots,
                  icon: const Icon(Icons.apps_rounded),
                  label: const Text('Sfoglia libreria bot'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenDocs,
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('Apri documentazione'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: foreground,
                    side: BorderSide(color: foreground.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
          ],
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primaryContainer,
                colorScheme.primary,
                colorScheme.primary.withOpacity(0.85),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.25),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: 32),
                    Expanded(
                      child: _HeroShowcase(
                        overlayColor: foreground.withOpacity(0.12),
                        textColor: foreground,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    content,
                    const SizedBox(height: 32),
                    _HeroShowcase(
                      overlayColor: foreground.withOpacity(0.14),
                      textColor: foreground,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _HeroHighlight extends StatelessWidget {
  const _HeroHighlight({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroShowcase extends StatelessWidget {
  const _HeroShowcase({
    required this.overlayColor,
    required this.textColor,
  });

  final Color overlayColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.titleMedium?.copyWith(
      color: textColor.withOpacity(0.9),
    );

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: overlayColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: textColor.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 28, color: textColor),
              const SizedBox(width: 12),
              Text(
                'Perché Scriptagher',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Installa, testa e distribuisci bot multi-linguaggio con un hub '
            'unificato. Supporto per ambienti isolati, telemetria e gestione '
            'dei permessi integrata.',
            style: textStyle,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroMetric(
                icon: Icons.cloud_sync_rounded,
                label: 'Marketplace live',
                color: textColor,
              ),
              _HeroMetric(
                icon: Icons.security_rounded,
                label: 'Policy granulari',
                color: textColor,
              ),
              _HeroMetric(
                icon: Icons.speed_rounded,
                label: 'Deploy rapidi',
                color: textColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      backgroundColor: color.withOpacity(0.14),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }
}
