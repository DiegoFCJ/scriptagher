import 'package:flutter/material.dart';

class MarketplacePage extends StatelessWidget {
  const MarketplacePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    void _showComingSoon() {
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
        const SnackBar(
          content: Text('Funzionalità disponibile a breve!'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marketplace in arrivo',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Stiamo preparando uno spazio dedicato dove scoprire, installare e gestire '
                    'nuovi bot per Scriptagher. Il marketplace ti permetterà di trovare soluzioni '
                    'create dalla community e pubblicare i tuoi automi in pochi minuti.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: const [
                      _MarketplaceHighlight(
                        icon: Icons.explore_outlined,
                        title: 'Esplora cataloghi',
                        description:
                            'Naviga tra i bot consigliati, le novità della settimana e i più scaricati.',
                      ),
                      _MarketplaceHighlight(
                        icon: Icons.cloud_download_outlined,
                        title: 'Installa con un click',
                        description:
                            'Aggiungi bot al tuo ambiente Scriptagher con un processo di installazione guidato.',
                      ),
                      _MarketplaceHighlight(
                        icon: Icons.analytics_outlined,
                        title: 'Valuta e confronta',
                        description:
                            'Recensioni, changelog e indicatori di qualità ti aiuteranno a scegliere in sicurezza.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.primaryContainer.withOpacity(0.25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Icon(
                                Icons.lightbulb_outline,
                                color: theme.colorScheme.primary,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Hai idee o suggerimenti? Condividili con il team per aiutare a '
                                  'modellare il marketplace ideale per la community.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _showComingSoon,
                                icon: const Icon(Icons.chat_outlined),
                                label: const Text('Unisciti al canale Discord'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _showComingSoon,
                                icon: const Icon(Icons.mail_outline),
                                label: const Text('Invia feedback al team'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketplaceHighlight extends StatelessWidget {
  const _MarketplaceHighlight({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Material(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
