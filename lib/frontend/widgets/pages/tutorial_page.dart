import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/gradient_hero_section.dart';

const String _tutorialDocsUrl =
    'https://github.com/scriptagher/scriptagher/blob/main/docs/create-your-bot.md';

class TutorialPage extends StatelessWidget {
  const TutorialPage({super.key});

  Future<void> _openDocs(BuildContext context) async {
    final uri = Uri.parse(_tutorialDocsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      const SnackBar(
        content:
            Text('Impossibile aprire la documentazione, controlla la connessione.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1100;
        final isTablet = constraints.maxWidth >= 720 && constraints.maxWidth < 1100;
        final horizontalPadding = isDesktop
            ? 120.0
            : isTablet
                ? 72.0
                : 24.0;

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  isDesktop ? 56 : 24,
                  horizontalPadding,
                  24,
                ),
                sliver: SliverToBoxAdapter(
                  child: GradientHeroSection(
                    leading: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.16),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    eyebrow: 'Guida rapida',
                    title: 'Crea il tuo bot',
                    subtitle:
                        'Impara a strutturare un pacchetto compatibile con Scriptagher e pubblicalo nel marketplace o nel tuo filesystem.',
                    icon: Icons.school_rounded,
                    primaryAction: FilledButton.icon(
                      onPressed: () => _openDocs(context),
                      icon: const Icon(Icons.menu_book_rounded),
                      label: const Text('Apri la guida completa'),
                    ),
                    secondaryAction: OutlinedButton.icon(
                      onPressed: () => _openDocs(context),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Documentazione online'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 12,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Panoramica',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scriptagher esegue bot impacchettati come cartelle con un file Bot.json che descrive metadati, runtime e permessi. Segui i passaggi sotto per crearne uno nuovo.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 28),
                      _TutorialSectionCard(
                        title: 'Struttura del progetto',
                        child: const SelectableText(
                          'my-awesome-bot/\n'
                          '├── Bot.json\n'
                          '├── main.py\n'
                          '├── requirements.txt\n'
                          '└── resources/\n',
                          style: TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Il file Bot.json definisce nome, versione, linguaggio, entrypoint, argomenti opzionali e comandi di installazione. I file sorgente contengono la logica del bot e possono includere dipendenze dichiarate nei comandi di post installazione.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 28),
                      _TutorialSectionCard(
                        title: 'Esempio di Bot.json',
                        child: const SelectableText(
                          '{\n'
                          '  "botName": "MyAwesomeBot",\n'
                          '  "version": "1.0.0",\n'
                          '  "archiveSha256": "0123456789abcdef...",\n'
                          '  "description": "Esempio di bot che stampa un messaggio",\n'
                          '  "author": "Jane Doe",\n'
                          '  "language": "python",\n'
                          '  "entrypoint": "main.py",\n'
                          '  "args": ["--verbose"],\n'
                          '  "environment": {\n'
                          '    "PYTHONPATH": "./"\n'
                          '  },\n'
                          '  "postInstall": [\n'
                          '    "pip install -r requirements.txt"\n'
                          '  ],\n'
                          '  "permissions": [\n'
                          '    "network",\n'
                          '    "filesystem:read"\n'
                          '  ]\n'
                          '}\n',
                          style: TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Flusso di lavoro',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _NumberedList(
                        items: [
                          'Scopri i bot nella libreria Online o prepara una nuova cartella locale.',
                          'Compila Bot.json con metadati, hash SHA-256, permessi e comandi di installazione.',
                          'Testa il bot localmente eseguendo l\'entrypoint con gli stessi argomenti.',
                          'Comprimi la cartella e caricala nel marketplace oppure copiala nelle directory monitorate.',
                          'Scarica o apri il bot da Scriptagher per installarlo ed eseguirlo dal dettaglio.',
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Best practice di sicurezza',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _BulletList(
                        items: [
                          'Isola l\'esecuzione (container, ambienti virtuali) per ridurre l\'impatto di codice malevolo.',
                          'Limita dipendenze e versioni per diminuire vulnerabilità e assicurane l\'aggiornamento.',
                          'Gestisci segreti e token tramite variabili d\'ambiente sicure, mai in chiaro nel repository.',
                          'Richiedi solo le permission strettamente necessarie in Bot.json e verifica gli accessi.',
                          'Valida l\'input e registra log strutturati per facilitare monitoraggio e audit.',
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Risorse aggiuntive',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text.rich(
                        TextSpan(
                          text: 'Consulta la documentazione completa in ',
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: GestureDetector(
                                onTap: () => _openDocs(context),
                                child: Text(
                                  'docs/create-your-bot.md',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const TextSpan(text: ' nel repository.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TutorialSectionCard extends StatelessWidget {
  const _TutorialSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surfaceVariant.withOpacity(0.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _NumberedList extends StatelessWidget {
  const _NumberedList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int index = 0; index < items.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${index + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(items[index])),
              ],
            ),
          ),
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(child: Text(item)),
              ],
            ),
          ),
      ],
    );
  }
}
