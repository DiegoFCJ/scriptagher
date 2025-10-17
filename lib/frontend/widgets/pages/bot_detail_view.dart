import 'package:flutter/material.dart';

import '../../models/bot.dart';
import '../../services/bot_action_service.dart';
import '../../services/bot_get_service.dart';

class BotDetailView extends StatefulWidget {
  final Bot bot;

  const BotDetailView({super.key, required this.bot});

  @override
  State<BotDetailView> createState() => _BotDetailViewState();
}

class _BotDetailViewState extends State<BotDetailView> {
  final BotGetService _botGetService = BotGetService();
  final BotActionService _botActionService = BotActionService();

  Bot? _localBot;
  bool _isDownloading = false;
  bool _isInstalled = false;
  bool _isUpdateAvailable = false;
  String? _errorMessage;

  Bot get _displayBot => _localBot ?? widget.bot;

  @override
  void initState() {
    super.initState();
    _loadLocalState();
  }

  Future<void> _loadLocalState() async {
    try {
      final localBots = await _botGetService.fetchLocalBotsFlat();
      Bot? match;
      try {
        match = localBots.firstWhere(
          (bot) =>
              bot.botName == widget.bot.botName &&
              bot.language.toLowerCase() == widget.bot.language.toLowerCase(),
        );
      } catch (_) {
        match = null;
      }

      if (!mounted) return;

      setState(() {
        _localBot = match;
        _isInstalled = match != null;
        _isUpdateAvailable = match != null && widget.bot.version.isNotEmpty
            ? widget.bot.version != match.version
            : false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Errore nel caricamento dei bot locali: $e';
      });
    }
  }

  Future<void> _handleDownloadOrUpdate() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    try {
      final downloadedBot = await _botActionService.downloadBot(
        widget.bot.language,
        widget.bot.botName,
      );

      if (!mounted) return;
      setState(() {
        _localBot = downloadedBot;
        _isInstalled = true;
        _isUpdateAvailable = widget.bot.version.isNotEmpty
            ? widget.bot.version != downloadedBot.version
            : false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isUpdateAvailable
                ? 'Aggiornamento completato per ${widget.bot.botName}.'
                : 'Download completato per ${widget.bot.botName}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Operazione fallita: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il download: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _handleOpenFolder() async {
    try {
      await _botActionService.openBotFolder(_displayBot);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cartella aperta per ${widget.bot.botName}.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Impossibile aprire la cartella: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore apertura cartella: $e')),
      );
    }
  }

  Future<void> _handleRun() async {
    try {
      await _botActionService.runBot(_displayBot);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Esecuzione avviata per ${widget.bot.botName}.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Impossibile eseguire il bot: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'esecuzione: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bot = _displayBot;
    final metadataStyle = Theme.of(context).textTheme.bodyMedium;

    return Scaffold(
      appBar: AppBar(
        title: Text(bot.botName),
        actions: [
          if (_isInstalled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Chip(
                label: Text(
                  _isUpdateAvailable ? 'Aggiornamento disponibile' : 'Installato',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor:
                    _isUpdateAvailable ? Colors.orange : Colors.green,
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bot.botName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                bot.description.isNotEmpty
                    ? bot.description
                    : 'Nessuna descrizione disponibile.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              if (_isDownloading) const LinearProgressIndicator(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              _buildMetadataRow('Autore', bot.author, metadataStyle),
              _buildMetadataRow('Versione', bot.version, metadataStyle),
              _buildMetadataRow(
                'Permessi richiesti',
                bot.permissions.isNotEmpty
                    ? bot.permissions.join(', ')
                    : 'Nessuno',
                metadataStyle,
              ),
              _buildMetadataRow(
                'Compatibilità piattaforme',
                bot.platformCompatibility.isNotEmpty
                    ? bot.platformCompatibility.join(', ')
                    : 'Non specificata',
                metadataStyle,
              ),
              _buildMetadataRow(
                'Comando di avvio',
                bot.startCommand.isNotEmpty
                    ? bot.startCommand
                    : 'Non specificato',
                metadataStyle,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isDownloading
                        ? null
                        : _handleDownloadOrUpdate,
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: Text(_isInstalled
                        ? (_isUpdateAvailable ? 'Aggiorna' : 'Reinstalla')
                        : 'Scarica'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isInstalled && !_isDownloading
                        ? _handleOpenFolder
                        : null,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Apri cartella'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isInstalled && !_isDownloading
                        ? _handleRun
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Esegui'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataRow(
      String label, String value, TextStyle? metadataStyle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              '$label:',
              style: metadataStyle?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: metadataStyle,
            ),
          ),
        ],
      ),
    );
  }
}
