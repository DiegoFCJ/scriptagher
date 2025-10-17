import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../models/bot.dart';
import '../../models/execution_log.dart';

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

  http.Client? _client;
  StreamSubscription<String>? _subscription;
  bool _autoScroll = true;
  bool _isRunning = false;
  bool _isLoadingLogs = false;
  String _buffer = '';
  String? _error;
  String? _startStatus;

  void _openTutorial() {
    Navigator.pushNamed(context, '/tutorial');
  }

  @override
  void initState() {
    super.initState();
    _loadLogs();
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

  void _startExecution() async {
    _stopExecution();
    setState(() {
      _entries.clear();
      _error = null;
      _startStatus = 'Avvio del bot in corso...';
      _isRunning = true;
    });

    final startUri = Uri.parse(
        '${widget.baseUrl}/bots/${Uri.encodeComponent(widget.bot.language)}/${Uri.encodeComponent(widget.bot.botName)}/start');

    try {
      final startResponse = await http.post(startUri);
      if (startResponse.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _error =
              'Impossibile avviare il bot. Codice risposta: ${startResponse.statusCode}';
          _startStatus = 'Avvio fallito';
          _isRunning = false;
        });
        _stopExecution();
        return;
      }

      final dynamic decoded = jsonDecode(startResponse.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Risposta non valida dal server');
      }

      final dynamic pidValue = decoded['pid'];
      final int? pid = pidValue is int
          ? pidValue
          : (pidValue is String ? int.tryParse(pidValue) : null);

      if (pid == null) {
        throw const FormatException('PID non fornito nella risposta');
      }

      if (!mounted) return;
      setState(() {
        _startStatus = 'Processo avviato (PID: $pid)';
      });

      await _openExecutionStream(pid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Errore durante l\'avvio: $e';
        _startStatus = 'Avvio fallito';
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

  Future<void> _openExecutionStream(int pid) async {
    final client = http.Client();
    _client = client;

    final uri = Uri.parse(
        '${widget.baseUrl}/bots/${Uri.encodeComponent(widget.bot.language)}/${Uri.encodeComponent(widget.bot.botName)}/stream?pid=$pid');

    try {
      final request = http.Request('GET', uri)
        ..headers['Accept'] = 'text/event-stream';
      final response = await client.send(request);

      if (response.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _error =
              'Impossibile connettersi allo stream. Codice risposta: ${response.statusCode}';
          _startStatus = 'Connessione log fallita';
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
          _startStatus = 'Connessione log fallita';
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
        _error = 'Errore durante la connessione allo stream: $e';
        _startStatus = 'Connessione log fallita';
        _isRunning = false;
      });
      _stopExecution();
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
            _startStatus =
                code != null ? 'Esecuzione completata (codice: $code)' :
                    'Esecuzione completata';
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
      _startStatus = null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bot.botName),
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
              'Nome: ${widget.bot.botName}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Descrizione: ${widget.bot.description}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            _buildCompatBadges(context),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isRunning ? null : _startExecution,
                  child: Text(_isRunning ? 'Esecuzione in corso...' : 'Esegui Bot'),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: _entries.isEmpty && _error == null ? null : _clearLog,
                  child: const Text('Pulisci log'),
                ),
                const Spacer(),
                Row(
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
                  ],
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_startStatus != null) ...[
              const SizedBox(height: 8),
              Text(
                _startStatus!,
                style: Theme.of(context).textTheme.bodyMedium,
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
    final compat = widget.bot.compat;
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
