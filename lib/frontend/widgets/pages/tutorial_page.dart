import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/app_gradient_background.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crea il tuo bot'),
        actions: [
          FilledButton.tonalIcon(
            onPressed: () => _openDocs(context),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Documentazione'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: AppGradientBackground(
        applyTopSafeArea: false,
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              'Panoramica',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scriptagher esegue bot impacchettati come cartelle con un file Bot.json che descrive '
              'metadati, runtime e permessi. Segui i passaggi sotto per crearne uno nuovo.',
            ),
            const SizedBox(height: 24),
            _SectionHeading(
              icon: Icons.layers_rounded,
              title: 'Struttura del progetto',
            ),
            const SizedBox(height: 8),
            _CodeBlock(
              content: 'my-awesome-bot/\n'
                  '├── Bot.json\n'
                  '├── main.py\n'
                  '├── requirements.txt\n'
                  '└── resources/\n',
            ),
            const SizedBox(height: 16),
            const Text(
              'Il file Bot.json definisce nome, versione, linguaggio, entrypoint, argomenti opzionali e '
              'comandi di installazione. I file sorgente contengono la logica del bot e possono includere '
              'dipendenze dichiarate nei comandi di post installazione.',
            ),
            const SizedBox(height: 24),
            _SectionHeading(
              icon: Icons.code_rounded,
              title: 'Esempio di Bot.json',
            ),
            const SizedBox(height: 8),
            const _CodeBlock(
              content: '{\n'
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
            ),
            const SizedBox(height: 24),
            _SectionHeading(
              icon: Icons.route_rounded,
              title: 'Flusso di lavoro',
            ),
            const SizedBox(height: 8),
            const _NumberedList(
              items: [
                'Scopri i bot nella libreria Online o prepara una nuova cartella locale.',
                'Compila Bot.json con metadati, hash SHA-256, permessi e comandi di installazione.',
                'Testa il bot localmente eseguendo l\'entrypoint con gli stessi argomenti.',
                'Comprimi la cartella e caricala nel marketplace oppure copiala nelle directory monitorate.',
                'Scarica o apri il bot da Scriptagher per installarlo ed eseguirlo dal dettaglio.',
              ],
            ),
            const SizedBox(height: 24),
            _SectionHeading(
              icon: Icons.verified_user_rounded,
              title: 'Best practice di sicurezza',
            ),
            const SizedBox(height: 8),
            const _BulletList(
              items: [
                'Isola l\'esecuzione (container, ambienti virtuali) per ridurre l\'impatto di codice malevolo.',
                'Limita dipendenze e versioni per diminuire vulnerabilità e assicurane l\'aggiornamento.',
                'Gestisci segreti e token tramite variabili d\'ambiente sicure, mai in chiaro nel repository.',
                'Richiedi solo le permission strettamente necessarie in Bot.json e verifica gli accessi.',
                'Valida l\'input e registra log strutturati per facilitare monitoraggio e audit.',
              ],
            ),
            const SizedBox(height: 24),
            _SectionHeading(
              icon: Icons.link_rounded,
              title: 'Risorse aggiuntive',
            ),
            const SizedBox(height: 8),
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
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: ' nel repository.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: colorScheme.onPrimaryContainer, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: SelectableText(
        content,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
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
