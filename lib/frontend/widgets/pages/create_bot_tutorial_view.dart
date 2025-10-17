import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CreateBotTutorialPage extends StatelessWidget {
  CreateBotTutorialPage({super.key});

  final Uri _docsUrl = Uri.parse(
    'https://github.com/diegofcj/scriptagher/blob/main/docs/creating-your-bot.md',
  );

  Future<void> _openDocs(BuildContext context) async {
    if (!await launchUrl(_docsUrl, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile aprire la guida online.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crea il tuo bot'),
        actions: [
          TextButton.icon(
            onPressed: () => _openDocs(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Apri guida completa'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Metti in produzione il tuo bot con Scriptagher',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Questa guida rapida riepiloga la struttura minima di un bot, '
              'il ciclo di download/esecuzione e le migliori pratiche di sicurezza. '
              'Trovi maggiori dettagli nella documentazione completa.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            _Section(
              title: '1. Architettura in breve',
              children: const [
                _Bullet(
                  'Repository remoto GitHub: il file bots.json elenca i bot suddivisi per linguaggio.',
                ),
                _Bullet(
                  'Backend locale (Shelf): scarica e registra i bot tramite BotDownloadService e BotDatabase.',
                ),
                _Bullet(
                  'Frontend Flutter: mostra le informazioni del bot e prepara il comando di avvio (startCommand).',
                ),
                _Bullet(
                  'Cartella localbots/: conserva le copie scaricate per l\'utilizzo offline.',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _Section(
              title: '2. Struttura del pacchetto .zip',
              children: [
                Text(
                  'Comprimi la cartella del bot mantenendo questa struttura:',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                const _CodeBlock(
                  '''<NomeBot>.zip
└── <NomeBot>/
    ├── Bot.json
    ├── README.md (opzionale)
    ├── src/ (codice sorgente)
    └── assets/ (configurazioni o modelli opzionali)''',
                ),
                const SizedBox(height: 12),
                Text(
                  'Il nome della cartella principale deve corrispondere al nome del bot e '
                  'alla cartella indicata in bots.json sul repository remoto.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _Section(
              title: '3. Esempio di Bot.json',
              children: const [
                _CodeBlock(
                  '''{
  "botName": "TrendFollower",
  "description": "Esegue ordini seguendo il trend delle medie mobili.",
  "language": "python",
  "version": "1.0.0",
  "entryPoint": "src/main.py",
  "startCommand": "python src/main.py --config config.yaml",
  "dependencies": [
    "pandas==2.2.2",
    "numpy==2.0.1"
  ],
  "environment": {
    "PYTHONUNBUFFERED": "1"
  },
  "permissions": {
    "network": false,
    "filesystem": "read"
  },
  "author": {
    "name": "Team Scriptagher",
    "contact": "devs@example.com"
  }
}''',
                ),
                SizedBox(height: 12),
                _Bullet('Campi obbligatori: botName, description, language, startCommand.'),
                _Bullet(
                  'Documenta il comando di avvio esatto che il runner dovrà eseguire (ad es. python src/main.py).',
                ),
                _Bullet(
                  'Usa i campi opzionali per chiarire dipendenze, permessi richiesti e informazioni sull\'autore.',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _Section(
              title: '4. Flusso di download ed esecuzione',
              children: const [
                _Bullet('La UI chiama l\'endpoint /bots per elencare le opzioni disponibili.'),
                _Bullet('BotDownloadService scarica lo zip, lo estrae in data/remote/<linguaggio>/<nomeBot> e registra il bot in SQLite.'),
                _Bullet('Le copie vengono replicate in localbots/ per essere mostrate in BotList e disponibili offline.'),
                _Bullet('Quando premi "Esegui Bot", lo startCommand viene passato al runner locale (integrazione in sviluppo).'),
              ],
            ),
            const SizedBox(height: 24),
            _Section(
              title: '5. Sicurezza e best practice',
              children: const [
                _Bullet('Firma o pubblica hash degli archivi .zip e verifica l\'integrità prima dell\'estrazione.'),
                _Bullet('Blocca le dipendenze a versioni specifiche e preferisci repository affidabili.'),
                _Bullet('Esegui i bot in ambienti isolati con privilegi minimi e documenta le necessità nei campi permissions.'),
                _Bullet('Non inserire credenziali nel pacchetto: usa variabili d\'ambiente o secret manager locali.'),
                _Bullet('Aggiungi logging e audit trail non sensibili per monitorare l\'attività del bot.'),
                _Bullet('Aggiorna version e changelog a ogni release per distinguere facilmente le build.'),
                _Bullet('Sottoponi il codice a review e scanner di sicurezza prima di pubblicarlo.'),
              ],
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => _openDocs(context),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Leggi la documentazione completa'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: SelectableText(
        code,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
    );
  }
}
