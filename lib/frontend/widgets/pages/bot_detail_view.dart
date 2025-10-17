import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../models/bot.dart';
import '../../models/execution_log.dart';
import '../../services/bot_get_service.dart';

class BotDetailView extends StatefulWidget {
  const BotDetailView(
      {super.key, required this.bot, this.baseUrl = 'http://localhost:8080'});

  final Bot bot;
  final String baseUrl;

  @override
  State<BotDetailView> createState() => _BotDetailViewState();
}

class _BotDetailViewState extends State<BotDetailView> {
  final ScrollController _scrollController = ScrollController();
  final List<_ConsoleEntry> _entries = [];
  final List<ExecutionLog> _logHistory = [];
  late BotGetService _botGetService;

  Bot? _downloadedBot;

  http.Client? _client;
  StreamSubscription<String>? _subscription;
  bool _autoScroll = true;
  bool _isRunning = false;
  bool _isLoadingLogs = false;
  bool _isCheckingDownload = false;
  bool _isDownloading = false;
  bool _isDownloaded = false;
  bool _isUpdateAvailable = false;
  String _buffer = '';
  String? _error;

  Bot get _effectiveBot => _downloadedBot ?? widget.bot;

  void _openTutorial() {
    Navigator.pushNamed(context, '/tutorial');
  }

  @override
  void initState() {
    super.initState();
    _botGetService = BotGetService(baseUrl: widget.baseUrl);
    _loadLogs();
    _refreshDownloadStatus();
  }

  @override
  void dispose() {
    _stopExecution();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoadingLogs = true;
    });

    final uri = Uri.parse(
        '${widget.baseUrl}/bots/${Uri.encodeComponent(widget.bot.language)}/${Uri.encodeComponent(widget.bot.botName)}/logs');

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        final logs = data
            .whereType<Map<String, dynamic>>()
            .map(ExecutionLog.fromJson)
            .toList();
        setState(() {
          _logHistory
            ..clear()
            ..addAll(logs);
        });
      } else {
        _showSnackBar(
            'Impossibile recuperare i log (codice ${response.statusCode}).');
      }
    } catch (e) {
      _showSnackBar('Errore durante il caricamento dei log: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLogs = false;
        });
      }
    }
  }

  Future<void> _refreshDownloadStatus() async {
    setState(() {
      _isCheckingDownload = true;
    });

    try {
      final downloaded = await _botGetService.fetchDownloadedBotsFlat();
      Bot? localBot;
      try {
        localBot = downloaded.firstWhere(
          (bot) =>
              bot.language == widget.bot.language &&
              bot.botName == widget.bot.botName,
        );
      } catch (_) {
        localBot = null;
      }

      if (!mounted) return;

      final remoteVersion = widget.bot.version;
      final localVersion = localBot?.version;
      final updateAvailable = localBot != null &&
          remoteVersion != null &&
          localVersion != null &&
          remoteVersion != localVersion;

      setState(() {
        _downloadedBot = localBot;
        _isDownloaded = localBot != null;
        _isUpdateAvailable = updateAvailable;
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Impossibile verificare lo stato del download: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingDownload = false;
        });
      }
    }
  }

  Future<void> _downloadOrUpdateBot() async {
    if (_isDownloading) {
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    final uri = Uri.parse(
        '${widget.baseUrl}/bots/${Uri.encodeComponent(widget.bot.language)}/${Uri.encodeComponent(widget.bot.botName)}');

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final dynamic payload = jsonDecode(response.body);
        if (payload is! Map<String, dynamic>) {
          throw const FormatException('Risposta non valida dal server');
        }
        final downloadedBot = Bot.fromJson(payload);
        if (!mounted) return;
        final bool wasUpdate = _isDownloaded && _isUpdateAvailable;

        setState(() {
          _downloadedBot = downloadedBot;
          _isDownloaded = true;
          _isUpdateAvailable = false;
        });

        _showSnackBar(
            wasUpdate ? 'Bot aggiornato correttamente.' : 'Bot scaricato correttamente.');
      } else {
        if (!mounted) return;
        _showSnackBar(
            'Errore durante il download (codice ${response.statusCode}).');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Errore durante il download: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
      if (mounted) {
        await _refreshDownloadStatus();
      }
    }
  }

  Future<void> _openBotFolder() async {
    final bot = _downloadedBot;
    if (bot == null || bot.sourcePath.isEmpty) {
      _showSnackBar('Scarica il bot per aprire la cartella.');
      return;
    }

    final file = File(bot.sourcePath);
    final directory = file.parent;

    if (!await directory.exists()) {
      _showSnackBar('Cartella non trovata: ${directory.path}');
      return;
    }

    try {
      if (Platform.isMacOS) {
        await Process.run('open', [directory.path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [directory.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [directory.path]);
      } else {
        _showSnackBar(
            'Apertura cartella non supportata su questa piattaforma.');
      }
    } catch (e) {
      _showSnackBar("Errore durante l'apertura della cartella: $e");
    }
  }

  void _startExecution() async {
    if (!_isDownloaded) {
      _showSnackBar('Scarica il bot prima di eseguirlo.');
      return;
    }
    _stopExecution();
    setState(() {
      _entries.clear();
      _error = null;
      _isRunning = true;
    });

    final client = http.Client();
    _client = client;

    final uri = Uri.parse(
        '${widget.baseUrl}/bots/${Uri.encodeComponent(widget.bot.language)}/${Uri.encodeComponent(widget.bot.botName)}/stream');

    try {
      final request = http.Request('GET', uri)
        ..headers['Accept'] = 'text/event-stream';
      final response = await client.send(request);

      if (response.statusCode != 200) {
        setState(() {
          _error =
              'Impossibile avviare il bot. Codice risposta: ${response.statusCode}';
          _isRunning = false;
        });
        _stopExecution();
        return;
      }

      _subscription = response.stream
          .transform(utf8.decoder)
          .listen(_processChunk, onError: (Object error, StackTrace _) {
        if (!mounted) return;
        setState(() {
          _error = 'Errore di connessione: $error';
          _isRunning = false;
        });
        _stopExecution();
      }, onDone: () {
        if (!mounted) return;
        setState(() {
          _isRunning = false;
        });
        _stopExecution();
        _loadLogs();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Errore durante l\'avvio: $e';
        _isRunning = false;
      });
      _stopExecution();
    }
  }

  void _stopExecution({bool closeClient = true}) {
    _subscription?.cancel();
    _subscription = null;
    if (closeClient) {
      _client?.close();
      _client = null;
    }
  }

  void _processChunk(String chunk) {
    _buffer += chunk;

    while (true) {
      final separatorIndex = _buffer.indexOf('\n\n');
      if (separatorIndex == -1) {
        break;
      }

      final rawEvent = _buffer.substring(0, separatorIndex);
      _buffer = _buffer.substring(separatorIndex + 2);

      final lines = rawEvent.split('\n');
      for (final line in lines) {
        if (line.startsWith('data:')) {
          final payload = line.substring(5).trim();
          if (payload.isEmpty) continue;
          _handleEvent(payload);
        }
      }
    }
  }

  void _handleEvent(String payload) {
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final type = decoded['type']?.toString() ?? 'stdout';
      final message = decoded['message']?.toString() ?? '';
      final code = decoded['code'];

      if (type == 'status') {
        final display =
            code != null ? '$message (code: $code)' : message;
        _appendEntry(_ConsoleEntry(
          message: display,
          type: type,
        ));
        if (message == 'finished') {
          setState(() {
            _isRunning = false;
          });
          _loadLogs();
        }
        return;
      }

      _appendEntry(_ConsoleEntry(message: message, type: type));
    } catch (e) {
      _appendEntry(
          _ConsoleEntry(message: 'Evento non valido: $payload', type: 'stderr'));
    }
  }

  void _appendEntry(_ConsoleEntry entry) {
    if (!mounted) return;
    setState(() {
      _entries.add(entry);
    });

    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _clearLog() {
    setState(() {
      _entries.clear();
      _error = null;
    });
  }

  Future<void> _openLog(ExecutionLog log) async {
    final uri = Uri.parse(
        '${widget.baseUrl}/bots/${Uri.encodeComponent(widget.bot.language)}/${Uri.encodeComponent(widget.bot.botName)}/logs/${Uri.encodeComponent(log.runId)}');
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final content = utf8.decode(response.bodyBytes);
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Log ${log.runId}'),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: SelectableText(content),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Chiudi'),
                ),
              ],
            );
          },
        );
      } else {
        _showSnackBar(
            'Impossibile aprire il log (codice ${response.statusCode}).');
      }
    } catch (e) {
      _showSnackBar('Errore durante l\'apertura del log: $e');
    }
  }

  Future<void> _exportLog(ExecutionLog log) async {
    final uri = Uri.parse(
        '${widget.baseUrl}/bots/${Uri.encodeComponent(widget.bot.language)}/${Uri.encodeComponent(widget.bot.botName)}/logs/${Uri.encodeComponent(log.runId)}');
    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        _showSnackBar(
            'Impossibile esportare il log (codice ${response.statusCode}).');
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${log.logFileName}');
      await file.writeAsBytes(response.bodyBytes);
      _showSnackBar('Log salvato in ${file.path}');
    } catch (e) {
      _showSnackBar('Errore durante l\'esportazione del log: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildMetadataSection(BuildContext context) {
    final theme = Theme.of(context);
    final author =
        _effectiveBot.author?.isNotEmpty == true ? _effectiveBot.author! : 'Non specificato';
    final remoteVersion = widget.bot.version ?? 'n/d';
    final localVersion = _isDownloaded ? (_downloadedBot?.version ?? 'n/d') : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Autore: $author', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            Text('Versione online: $remoteVersion',
                style: theme.textTheme.bodyMedium),
            if (localVersion != null)
              Text('Versione locale: $localVersion',
                  style: theme.textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }

  Widget _buildPermissionsSection(BuildContext context) {
    final permissions = _effectiveBot.permissions;
    final theme = Theme.of(context);
    if (permissions.isEmpty) {
      return Text(
        'Permessi dichiarati: nessuno',
        style: theme.textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Permessi dichiarati', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: permissions
              .map(
                (permission) => Chip(
                  label: Text(permission),
                  visualDensity: VisualDensity.compact,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPlatformCompatibilitySection(BuildContext context) {
    final theme = Theme.of(context);
    final compatibility = _effectiveBot.platformCompatibility;

    if (compatibility.isEmpty) {
      return Text(
        'Compatibilità piattaforme: non dichiarata',
        style: theme.textTheme.bodyMedium,
      );
    }

    final List<Widget> chips = [];
    compatibility.platforms.forEach((platform, status) {
      switch (status) {
        case BotPlatformSupportStatus.supported:
          chips.add(_compatChip(
            context,
            label: platform,
            icon: Icons.check_circle_outline,
            color: Colors.green.shade600,
          ));
          break;
        case BotPlatformSupportStatus.partial:
          chips.add(_compatChip(
            context,
            label: platform,
            icon: Icons.info_outline,
            color: Colors.orange.shade700,
          ));
          break;
        case BotPlatformSupportStatus.unsupported:
          chips.add(_compatChip(
            context,
            label: platform,
            icon: Icons.block,
            color: Colors.red.shade600,
          ));
          break;
        case BotPlatformSupportStatus.unknown:
          chips.add(_compatChip(
            context,
            label: platform,
            icon: Icons.help_outline,
            color: Colors.blueGrey.shade600,
          ));
          break;
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Compatibilità piattaforme', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: chips,
        ),
        if (compatibility.notes.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Note: ${compatibility.notes.join(', ')}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildUpdateBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final remoteVersion = widget.bot.version ?? 'n/d';
    final localVersion = _downloadedBot?.version ?? 'n/d';

    return Card(
      color: colorScheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(Icons.system_update_alt,
            color: colorScheme.onTertiaryContainer),
        title: const Text('Aggiornamento disponibile'),
        subtitle: Text(
          'Versione locale: $localVersion • Versione online: $remoteVersion',
        ),
        trailing: _isDownloading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final downloadLabel = _isDownloading
        ? 'Download in corso...'
        : (_isUpdateAvailable ? 'Aggiorna' : 'Scarica');
    final Widget downloadIcon = _isDownloading
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            _isUpdateAvailable ? Icons.system_update_alt : Icons.download,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: _isDownloading ? null : _downloadOrUpdateBot,
              icon: downloadIcon,
              label: Text(downloadLabel),
            ),
            OutlinedButton.icon(
              onPressed: _isDownloaded ? _openBotFolder : null,
              icon: const Icon(Icons.folder_open),
              label: const Text('Apri cartella'),
            ),
            ElevatedButton.icon(
              onPressed: (_isRunning || !_isDownloaded) ? null : _startExecution,
              icon: const Icon(Icons.play_arrow),
              label:
                  Text(_isRunning ? 'Esecuzione in corso...' : 'Esegui'),
            ),
            OutlinedButton.icon(
              onPressed:
                  _entries.isEmpty && _error == null ? null : _clearLog,
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('Pulisci log'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Auto-scroll'),
            Switch(
              value: _autoScroll,
              onChanged: (value) {
                setState(() {
                  _autoScroll = value;
                });
              },
            ),
            if (_isCheckingDownload && !_isDownloading) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBot = _effectiveBot;
    return Scaffold(
      appBar: AppBar(
        title: Text(effectiveBot.botName),
        actions: [
          IconButton(
            tooltip: 'Guida: crea il tuo bot',
            onPressed: _openTutorial,
            icon: const Icon(Icons.school_outlined),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              effectiveBot.botName,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              effectiveBot.description.isEmpty
                  ? 'Nessuna descrizione disponibile.'
                  : effectiveBot.description,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            _buildMetadataSection(context),
            const SizedBox(height: 12),
            _buildPermissionsSection(context),
            const SizedBox(height: 12),
            _buildPlatformCompatibilitySection(context),
            const SizedBox(height: 12),
            _buildCompatBadges(context),
            if (_isUpdateAvailable) ...[
              const SizedBox(height: 12),
              _buildUpdateBanner(context),
            ],
            if (_isDownloaded && !_isUpdateAvailable) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: _compatChip(
                  context,
                  label: 'Bot scaricato',
                  icon: Icons.download_done_outlined,
                  color: Colors.green.shade600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildActionButtons(context),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                padding: const EdgeInsets.all(12),
                child: _entries.isEmpty
                    ? const Center(
                        child: Text(
                          'Nessun output disponibile. Avvia il bot per vedere i log.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _entries.length,
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          return Text(
                            entry.message,
                            style: TextStyle(
                              color: entry.color,
                              fontFamily: 'monospace',
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Storico esecuzioni',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Aggiorna',
                            onPressed: _isLoadingLogs ? null : _loadLogs,
                            icon: _isLoadingLogs
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _buildLogList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompatBadges(BuildContext context) {
    final compat = _effectiveBot.compat;
    final List<Widget> chips = [];

    if (compat.desktopStatus == 'compatible') {
      chips.add(_compatChip(
        context,
        label: 'Compatibile',
        icon: Icons.check_circle_outline,
        color: Colors.green.shade600,
      ));
    } else if (compat.desktopStatus == 'missing-runner') {
      final missing = compat.missingDesktopRuntimes.join(', ');
      final label = missing.isEmpty
          ? 'Runner mancante'
          : 'Runner mancante: $missing';
      chips.add(_compatChip(
        context,
        label: label,
        icon: Icons.warning_amber_rounded,
        color: Colors.orange.shade700,
      ));
    }

    if (compat.browserStatus == 'unsupported') {
      chips.add(_compatChip(
        context,
        label: compat.browserReason ?? 'Non supportato nel browser',
        icon: Icons.block,
        color: Colors.blueGrey.shade600,
      ));
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: chips,
    );
  }

  Widget _compatChip(BuildContext context,
      {required String label,
      required IconData icon,
      required Color color}) {
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      backgroundColor: color.withOpacity(0.12),
      labelStyle: Theme.of(context)
          .textTheme
          .labelMedium
          ?.copyWith(color: color, fontWeight: FontWeight.w600),
      side: BorderSide(color: color.withOpacity(0.4)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildLogList() {
    if (_isLoadingLogs && _logHistory.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_logHistory.isEmpty) {
      return const Center(
        child: Text('Nessun log disponibile per questo bot.'),
      );
    }

    return ListView.separated(
      itemCount: _logHistory.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final log = _logHistory[index];
        return ListTile(
          title: Text('${log.formattedStartedAt} • ${log.status}'),
          subtitle: Text(
            'Fine: ${log.formattedFinishedAt} • Exit code: ${log.exitCode ?? 'n/d'} • Dimensione: ${log.formattedSize}',
          ),
          trailing: Wrap(
            spacing: 8,
            children: [
              IconButton(
                tooltip: 'Apri log',
                icon: const Icon(Icons.visibility),
                onPressed: () => _openLog(log),
              ),
              IconButton(
                tooltip: 'Esporta log',
                icon: const Icon(Icons.download),
                onPressed: () => _exportLog(log),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConsoleEntry {
  _ConsoleEntry({required this.message, required this.type});

  final String message;
  final String type;

  Color get color {
    switch (type) {
      case 'stderr':
        return Colors.redAccent;
      case 'status':
        return Colors.blueAccent;
      default:
        return Colors.greenAccent;
    }
  }
}
