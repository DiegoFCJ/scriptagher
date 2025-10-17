import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../models/bot.dart';
import '../../models/execution_log.dart';
import '../../services/browser_runner/browser_bot_runner.dart';
import '../../services/browser_runner/browser_runner_models.dart';

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
  BrowserBotRunner? _browserRunner;
  BrowserRunnerSession? _browserSession;
  StreamSubscription<BrowserRunnerEvent>? _browserSubscription;
  bool _autoScroll = true;
  bool _isRunning = false;
  bool _isLoadingLogs = false;
  bool _isSendingSignal = false;
  String _buffer = '';
  String? _error;
  int? _lastExitCode;

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
    _browserRunner?.dispose();
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
          if (!_isRunning && logs.isNotEmpty) {
            _lastExitCode = logs.first.exitCode;
          }
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

  Future<void> _requestExecution() async {
    if (_isRunning) return;
    final permissions = widget.bot.permissions;
    if (permissions.isNotEmpty) {
      final accepted = await _showPermissionsDialog(permissions);
      if (accepted != true) {
        return;
      }
      await _startExecution(grantedPermissions: permissions);
    } else {
      await _startExecution();
    }
  }

  Future<void> _startExecution({List<String>? grantedPermissions}) async {
    _stopExecution();
    setState(() {
      _entries.clear();
      _error = null;
      _isRunning = true;
      _isSendingSignal = false;
      _lastExitCode = null;
    });

    final client = http.Client();
    _client = client;

    final baseUri = Uri.parse(
        '${widget.baseUrl}/bots/${Uri.encodeComponent(widget.bot.language)}/${Uri.encodeComponent(widget.bot.botName)}/stream');
    final uri = (grantedPermissions != null && grantedPermissions.isNotEmpty)
        ? baseUri.replace(queryParameters: {
            ...baseUri.queryParameters,
            'grantedPermissions': grantedPermissions.join(','),
          })
        : baseUri;

    try {
      final request = http.Request('GET', uri)
        ..headers['Accept'] = 'text/event-stream';
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        String errorMessage =
            'Impossibile avviare il bot. Codice risposta: ${response.statusCode}';
        try {
          final decoded = jsonDecode(errorBody) as Map<String, dynamic>;
          final reason = decoded['error']?.toString();
          if (reason != null && reason.isNotEmpty) {
            if (decoded['missing_permissions'] is List) {
              final missing = (decoded['missing_permissions'] as List)
                  .whereType<String>()
                  .join(', ');
              errorMessage =
                  '$reason${missing.isNotEmpty ? ': $missing' : ''}';
            } else {
              errorMessage = reason;
            }
          }
        } catch (_) {
          if (errorBody.isNotEmpty) {
            errorMessage = errorBody;
          }
        }
        setState(() {
          _error = errorMessage;
          _isRunning = false;
          _isSendingSignal = false;
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
          _isSendingSignal = false;
        });
        _stopExecution();
      }, onDone: () {
        if (!mounted) return;
        setState(() {
          _isRunning = false;
          _isSendingSignal = false;
        });
        _stopExecution();
        _loadLogs();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Errore durante l\'avvio: $e';
        _isRunning = false;
        _isSendingSignal = false;
      });
      _stopExecution();
    }
  }

  Future<bool> _showPermissionsDialog(List<String> permissions) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Permessi richiesti'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Il bot richiede i seguenti permessi per essere eseguito:'),
                  const SizedBox(height: 12),
                  ...permissions.map(
                    (perm) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.shield_outlined, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(perm)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annulla'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Conferma'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _stopExecution({bool closeClient = true}) {
    _subscription?.cancel();
    _subscription = null;
    if (closeClient) {
      _client?.close();
      _client = null;
    }
    _browserSubscription?.cancel();
    _browserSubscription = null;
    _browserSession?.stop();
    _browserSession = null;
    _isSendingSignal = false;
  }

  Future<void> _handleStopRequest() async {
    if (!_isRunning) return;
    if (_shouldUseBrowserRunner) {
      await _browserSession?.stop();
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _isSendingSignal = false;
      });
      return;
    }
    await _sendControlCommand('stop');
  }

  Future<void> _handleKillRequest() async {
    if (!_isRunning) return;
    if (_shouldUseBrowserRunner) {
      await _browserSession?.stop();
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _isSendingSignal = false;
      });
      return;
    }
    await _sendControlCommand('kill');
  }

  Future<void> _sendControlCommand(String action) async {
    if (!_isRunning || _isSendingSignal || !mounted) {
      return;
    }

    setState(() {
      _isSendingSignal = true;
    });

    final actionLabel = action == 'kill' ? 'Kill' : 'Stop';
    final uri = Uri.parse(
        '${widget.baseUrl}/bots/${Uri.encodeComponent(widget.bot.language)}/${Uri.encodeComponent(widget.bot.botName)}/$action');

    try {
      final response = await http.post(uri);
      Map<String, dynamic>? data;
      if (response.body.isNotEmpty) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            data = decoded;
          }
        } catch (_) {
          data = null;
        }
      }

      if (mounted && data != null) {
        final exitValue = data['exit_code'];
        final status = data['status']?.toString();
        setState(() {
          if (exitValue is num) {
            _lastExitCode = exitValue.toInt();
          }
          if (status == 'not_running') {
            _isRunning = false;
          }
        });
      }

      final successMessage = 'Comando $actionLabel inviato.';
      final errorMessage =
          'Errore (${response.statusCode}) durante il comando $actionLabel.';
      final message = data != null && data['message'] != null
          ? data!['message'].toString()
          : (response.statusCode >= 200 && response.statusCode < 300
              ? successMessage
              : errorMessage);

      _showSnackBar(message);
    } catch (e) {
      _showSnackBar(
          'Errore durante l\'invio del comando $actionLabel: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSendingSignal = false;
        });
      } else {
        _isSendingSignal = false;
      }
    }
  }

  bool get _shouldUseBrowserRunner =>
      kIsWeb && BrowserBotRunner.isSupported && widget.bot.compat.canRunInBrowser;

  bool get _canExecuteBot {
    if (kIsWeb) {
      return _shouldUseBrowserRunner;
    }
    return true;
  }

  Future<void> _startBrowserExecution() async {
    _stopExecution();
    setState(() {
      _entries.clear();
      _error = null;
      _isRunning = true;
      _isSendingSignal = false;
      _lastExitCode = null;
    });

    _appendEntry(
      _ConsoleEntry(
        message: 'Avvio sandbox browser...',
        type: 'status',
      ),
    );

    _browserRunner ??= BrowserBotRunner();

    try {
      final session = await _browserRunner!.start(
        widget.bot,
        baseUrl: widget.baseUrl,
      );
      _browserSession = session;
      _browserSubscription = session.stream.listen((event) {
        if (!mounted) return;
        if (event.type == 'status') {
          if (event.code != null) {
            setState(() {
              _lastExitCode = event.code;
            });
          }
          final display = event.code != null
              ? '${event.message} (code: ${event.code})'
              : event.message;
          _appendEntry(
            _ConsoleEntry(
              message: display,
              type: event.type,
            ),
          );
          if (event.message == 'finished' || event.message == 'failed') {
            setState(() {
              _isRunning = false;
              _isSendingSignal = false;
              if (event.message == 'failed' && _error == null) {
                _error = 'Esecuzione fallita nella sandbox browser.';
              }
            });
          }
          return;
        }

        _appendEntry(
          _ConsoleEntry(
            message: event.message,
            type: event.type,
          ),
        );
      }, onError: (Object error, StackTrace _) {
        if (!mounted) return;
        setState(() {
          _error = 'Errore sandbox: $error';
          _isRunning = false;
          _isSendingSignal = false;
        });
      }, onDone: () {
        if (!mounted) return;
        setState(() {
          _isRunning = false;
          _isSendingSignal = false;
        });
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossibile avviare nel browser: $error';
        _isRunning = false;
        _isSendingSignal = false;
      });
      _browserSession?.stop();
      _browserSession = null;
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
        if (code is num) {
          setState(() {
            _lastExitCode = code.toInt();
          });
        }
        final display =
            code != null ? '$message (code: $code)' : message;
        _appendEntry(_ConsoleEntry(
          message: display,
          type: type,
        ));
        if (message == 'finished') {
          setState(() {
            _isRunning = false;
            _isSendingSignal = false;
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
            _buildPermissionsSection(context),
            if (widget.bot.permissions.isNotEmpty) const SizedBox(height: 12),
            _buildCompatBadges(context),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton(
                  onPressed:
                      _isRunning ? null : () => _requestExecution(),
                  child: Text(_isRunning ? 'Esecuzione in corso...' : 'Esegui Bot'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _isRunning && !_isSendingSignal
                      ? () => _handleStopRequest()
                      : null,
                  child: const Text('Stop'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _isRunning && !_isSendingSignal && !_shouldUseBrowserRunner
                      ? () => _handleKillRequest()
                      : null,
                  child: const Text('Kill'),
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
            const SizedBox(height: 8),
            Text(
              _isRunning
                  ? 'Codice di uscita: in esecuzione...'
                  : 'Codice di uscita: ${_lastExitCode?.toString() ?? 'n/d'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (kIsWeb && !_shouldUseBrowserRunner) ...[
              const SizedBox(height: 12),
              Text(
                widget.bot.compat.browserReason ??
                    'Questo bot non è compatibile con il runner browser.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
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

  Widget _buildPermissionsSection(BuildContext context) {
    final permissions = widget.bot.permissions;
    if (permissions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Permessi richiesti',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: permissions
              .map(
                (perm) => Chip(
                  avatar: const Icon(Icons.shield_outlined, size: 18),
                  label: Text(perm),
                ),
              )
              .toList(),
        ),
      ],
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
