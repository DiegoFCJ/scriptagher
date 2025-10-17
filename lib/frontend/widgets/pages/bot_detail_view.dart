import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:scriptagher/shared/utils/log_storage.dart';

import '../../models/bot.dart';

class BotDetailView extends StatefulWidget {
  final Bot bot;

  BotDetailView({super.key, required this.bot});

  @override
  State<BotDetailView> createState() => _BotDetailViewState();
}

class _BotDetailViewState extends State<BotDetailView> {
  late Future<List<RunLogEntry>> _logsFuture;

  String get _botIdentifier =>
      widget.bot.id?.toString() ?? widget.bot.botName;

  @override
  void initState() {
    super.initState();
    _logsFuture = LogStorage.fetchRunLogs(_botIdentifier);
  }

  Future<void> _refreshLogs() async {
    setState(() {
      _logsFuture = LogStorage.fetchRunLogs(_botIdentifier);
    });
    try {
      await _logsFuture;
    } catch (_) {
      // L'errore verrà gestito dal FutureBuilder mostrando il messaggio adeguato.
    }
  }

  Future<void> _openLog(BuildContext context, RunLogEntry entry) async {
    final content = await LogStorage.readLogContent(entry);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.fileName),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(content.isEmpty
                ? 'Il log è vuoto.'
                : content),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportLog(BuildContext context, RunLogEntry entry) async {
    try {
      final exportedFile = await LogStorage.exportLogFile(entry);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Log esportato in: ${exportedFile.path}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore durante l\'esportazione: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bot.botName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aggiorna log',
            onPressed: _refreshLogs,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nome: ${widget.bot.botName}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Descrizione: ${widget.bot.description}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Esegui bot: ${widget.bot.botName}')),
                );
              },
              child: const Text('Esegui Bot'),
            ),
            const SizedBox(height: 30),
            Text(
              'Log Esecuzioni',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<RunLogEntry>>(
                future: _logsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                          'Errore durante il caricamento dei log: ${snapshot.error}'),
                    );
                  }

                  final logs = snapshot.data ?? [];
                  if (logs.isEmpty) {
                    return const Center(
                      child: Text('Nessun log disponibile per questo bot.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = logs[index];
                      final modified = dateFormatter.format(entry.lastModified);
                      return ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(entry.fileName),
                        subtitle: Text('Ultima modifica: $modified'),
                        onTap: () => _openLog(context, entry),
                        trailing: IconButton(
                          icon: const Icon(Icons.download_outlined),
                          tooltip: 'Esporta log',
                          onPressed: () => _exportLog(context, entry),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
