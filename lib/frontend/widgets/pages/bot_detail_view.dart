import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/bot.dart';
import '../../models/execution_log.dart';
import '../../services/browser_runner/browser_bot_runner.dart';
import '../../services/browser_runner/browser_runner_models.dart';
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
  late final BotGetService _botGetService;
  Bot? _downloadedBot;
  Bot? _remoteBot;

  http.Client? _client;
  StreamSubscription<String>? _subscription;
  BrowserBotRunner? _browserRunner;
  BrowserRunnerSession? _browserSession;
  StreamSubscription<BrowserRunnerEvent>? _browserSubscription;
  bool _autoScroll = true;
  bool _isRunning = false;
  bool _isLoadingLogs = false;
  bool _isDownloading = false;
  bool _isCheckingDownload = false;
  bool _isFetchingRemote = false;
  late final bool _widgetRepresentsLocal;
  String _buffer = '';
  String? _error;
  String? _startStatus;

  void _openTutorial() {
    Navigator.pushNamed(context, '/tutorial');
  }

  @override
  void initState() {
    super.initState();
    _botGetService = BotGetService(baseUrl: widget.baseUrl);
    _widgetRepresentsLocal = _detectLocalBot(widget.bot);
    if (_widgetRepresentsLocal) {
      _downloadedBot = widget.bot;
      _loadRemoteMetadata();
    } else {
      _remoteBot = widget.bot;
    }
    _loadLogs();
    _loadDownloadState();
  }

  @override
  void dispose() {
    _stopExecution();
    _scrollController.dispose();
    _browserRunner?.dispose();
    super.dispose();
  }

  bool _detectLocalBot(Bot bot) {
    if (kIsWeb) {
      return false;
    }
    if (bot.sourcePath.isEmpty) {
      return false;
    }
    try {
      final manifestFile = File(bot.sourcePath);
      if (manifestFile.existsSync()) {
        return true;
      }
      final directory = Directory(bot.sourcePath);
      return directory.existsSync();
    } catch (_) {
      return false;
    }
  }

  Bot? get _effectiveRemoteBot {
    if (_remoteBot != null) {
      return _remoteBot;
    }
    if (!_widgetRepresentsLocal) {
      return widget.bot;
    }
    return null;
  }

  Bot get _primaryBot {
    if (_widgetRepresentsLocal && _downloadedBot != null) {
      return _downloadedBot!;
    }
    return _effectiveRemoteBot ?? _downloadedBot ?? widget.bot;
  }

  bool get _isDownloaded => _downloadedBot != null;

  bool get _hasUpdate {
    final remote = _effectiveRemoteBot;
    final local = _downloadedBot;
    if (remote == null || local == null) {
      return false;
    }
    final remoteHash = remote.archiveSha256;
    final localHash = local.archiveSha256;
    if (remoteHash != null &&
        remoteHash.isNotEmpty &&
        localHash != null &&
        localHash.isNotEmpty &&
        remoteHash != localHash) {
      return true;
    }
    return remote.version != local.version;
  }

  bool get _canDownloadAction {
    if (_isDownloading) {
      return false;
    }
    final remote = _effectiveRemoteBot;
    if (remote == null) {
      return !_isDownloaded;
    }
    if (!_isDownloaded) {
      return true;
    }
    return _hasUpdate;
  }

  String get _downloadButtonLabel {
    if (_isDownloading) {
      return 'Download in corso...';
    }
    if (_hasUpdate) {
      return 'Aggiorna';
    }
    if (!_isDownloaded) {
      return 'Scarica';
    }
    return 'Scaricato';
  }

  String? get _localFolderPath {
    if (kIsWeb) {
      return null;
    }
    final candidate = _downloadedBot?.sourcePath ??
        (_widgetRepresentsLocal ? widget.bot.sourcePath : null);
    if (candidate == null || candidate.isEmpty) {
      return null;
    }
    try {
      final manifestFile = File(candidate);
      if (manifestFile.existsSync()) {
        return manifestFile.parent.path;
      }
      final directory = Directory(candidate);
      if (directory.existsSync()) {
        return directory.path;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> _loadDownloadState() async {
    setState(() {
      _isCheckingDownload = true;
    });

    try {
      final bots = await _botGetService.fetchDownloadedBotsFlat();
      Bot? match;
      for (final bot in bots) {
        if (bot.language == widget.bot.language &&
            bot.botName == widget.bot.botName) {
          match = bot;
          break;
        }
      }
      if (!mounted) return;
      final fallback = _widgetRepresentsLocal
          ? (_downloadedBot ?? widget.bot)
          : _downloadedBot;
      setState(() {
        _downloadedBot = match ?? fallback;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Errore durante il controllo download: $e', isError: true);
    } finally {
      if (!mounted) return;
      setState(() {
        _isCheckingDownload = false;
      });
    }
  }

  Future<void> _loadRemoteMetadata() async {
    setState(() {
      _isFetchingRemote = true;
    });

    try {
      final grouped = await _botGetService.fetchOnlineBots();
      final bots = grouped[widget.bot.language] ?? const <Bot>[];
      Bot? match;
      for (final bot in bots) {
        if (bot.botName == widget.bot.botName) {
          match = bot;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _remoteBot = match;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
          'Impossibile recuperare i metadati online: $e',
          isError: true);
    } finally {
      if (!mounted) return;
      setState(() {
        _isFetchingRemote = false;
      });
    }
  }

  Future<void> _handleDownloadAction() async {
    if (!_canDownloadAction) {
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
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final bot = Bot.fromJson(data);
        if (!mounted) return;
        setState(() {
          _downloadedBot = bot;
        });
        _showSnackBar('Bot scaricato con successo.');
      } else {
        String message = 'codice ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic>) {
              final reason = decoded['message'] ?? decoded['error'];
              if (reason is String && reason.isNotEmpty) {
                message = reason;
              }
            }
          } catch (_) {}
        }
        _showSnackBar('Download fallito: $message', isError: true);
      }
    } catch (e) {
      _showSnackBar('Errore durante il download: $e', isError: true);
    } finally {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
      });
      await _loadDownloadState();
    }
  }

  Future<void> _openFolder() async {
    final path = _localFolderPath;
    if (path == null) {
      _showSnackBar('Cartella locale non disponibile.', isError: true);
      return;
    }

    final uri = Uri.file(path, windows: Platform.isWindows);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      _showSnackBar('Impossibile aprire la cartella.', isError: true);
    }
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
    if (_shouldUseBrowserRunner) {
      await _startBrowserExecution();
      return;
    }

    if (!kIsWeb) {
      await _startDesktopExecution(grantedPermissions: grantedPermissions);
      return;
    }

    await _startServerStream(grantedPermissions: grantedPermissions);
  }

  Future<void> _startDesktopExecution({List<String>? grantedPermissions}) async {
    _stopExecution();
    setState(() {
      _entries.clear();
      _error = null;
      _startStatus = null;
      _isRunning = true;
    });

    final baseUri = Uri.parse(
        '${widget.baseUrl}/bots/${Uri.encodeComponent(widget.bot.language)}/${Uri.encodeComponent(widget.bot.botName)}/start');
    final uri = (grantedPermissions != null && grantedPermissions.isNotEmpty)
        ? baseUri.replace(queryParameters: {
            ...baseUri.queryParameters,
            'grantedPermissions': grantedPermissions.join(','),
          })
        : baseUri;

    try {
      final response = await http.post(uri);
      if (response.statusCode == 200) {
        Map<String, dynamic> data = <String, dynamic>{};
        if (response.body.isNotEmpty) {
          try {
            data = jsonDecode(response.body) as Map<String, dynamic>;
          } catch (_) {
            data = <String, dynamic>{};
          }
        }

        final pid = data['pid']?.toString();
        final processId = data['processId']?.toString();
        final runId = data['runId']?.toString();

        String message = 'Processo avviato';
        if (pid != null && pid.isNotEmpty) {
          message += ' (PID: $pid)';
        }
        if (processId != null && processId.isNotEmpty) {
          message += ' [ID: $processId]';
        }

        setState(() {
          _startStatus = message;
        });

        _appendEntry(_ConsoleEntry(message: message, type: 'status'));
        if (runId != null && runId.isNotEmpty) {
          _appendEntry(_ConsoleEntry(
              message: 'ID log esecuzione: $runId', type: 'status'));
        }
      } else {
        String errorMessage =
            'Impossibile avviare il bot. Codice risposta: ${response.statusCode}';
        final body = response.body;
        if (body.isNotEmpty) {
          try {
            final decoded = jsonDecode(body) as Map<String, dynamic>;
            final reason = decoded['message'] ?? decoded['error'];
            if (reason is String && reason.isNotEmpty) {
              errorMessage = reason;
            } else if (decoded['missing_permissions'] is List) {
              final missing = (decoded['missing_permissions'] as List)
                  .whereType<String>()
                  .join(', ');
              if (missing.isNotEmpty) {
                errorMessage =
                    '${decoded['error'] ?? 'permissions_denied'}: $missing';
              }
            }
          } catch (_) {
            // Ignora eventuali errori di parsing
          }
        }

        setState(() {
          _error = errorMessage;
          _startStatus = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Errore durante l\'avvio: $e';
        _startStatus = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  Future<void> _startServerStream({List<String>? grantedPermissions}) async {
    _stopExecution();
    setState(() {
      _entries.clear();
      _error = null;
      _startStatus = null;
      _isRunning = true;
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
        });
      }, onDone: () {
        if (!mounted) return;
        setState(() {
          _isRunning = false;
        });
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossibile avviare nel browser: $error';
        _isRunning = false;
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

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bot = _primaryBot;
    return Scaffold(
      appBar: AppBar(
        title: Text(bot.botName),
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
              bot.botName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              bot.description.isNotEmpty
                  ? bot.description
                  : 'Nessuna descrizione disponibile.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            _buildMetadataSection(context, bot),
            _buildPermissionsSection(context, bot),
            if (bot.permissions.isNotEmpty) const SizedBox(height: 12),
            _buildCompatBadges(context, bot),
            if (_hasUpdate)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Aggiornamento disponibile: scarica per ottenere le ultime modifiche.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.orange.shade700),
                ),
              ),
            const SizedBox(height: 20),
            _buildActionButtons(context),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_startStatus != null) ...[
              const SizedBox(height: 12),
              Text(
                _startStatus!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
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

  Widget _buildMetadataSection(BuildContext context, Bot bot) {
    final theme = Theme.of(context);
    final remoteVersion = _effectiveRemoteBot?.version;
    final localVersion = _downloadedBot?.version;

    final downloadIcon = _hasUpdate
        ? Icons.update
        : (_isDownloaded
            ? Icons.download_done_outlined
            : Icons.cloud_download_outlined);
    final downloadColor = _hasUpdate
        ? Colors.orange.shade700
        : (_isDownloaded
            ? Colors.green.shade600
            : theme.colorScheme.outline);
    final downloadText = _hasUpdate
        ? 'Aggiornamento disponibile'
        : (_isDownloaded ? 'Bot scaricato localmente' : 'Bot non scaricato');

    final showRemoteVersion = remoteVersion != null &&
        remoteVersion.isNotEmpty &&
        remoteVersion != bot.version;
    final showLocalVersion = localVersion != null &&
        localVersion.isNotEmpty &&
        localVersion != bot.version;

    final hasPlatforms = bot.platformCompatibility.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _metadataEntry(
                  context,
                  icon: Icons.person_outline,
                  label: 'Autore',
                  value: bot.author,
                ),
                _metadataEntry(
                  context,
                  icon: Icons.tag,
                  label: 'Versione',
                  value: bot.version,
                ),
                if (showLocalVersion)
                  _metadataEntry(
                    context,
                    icon: Icons.save_alt_outlined,
                    label: 'Versione locale',
                    value: localVersion!,
                  ),
                if (showRemoteVersion)
                  _metadataEntry(
                    context,
                    icon: Icons.cloud_outlined,
                    label: 'Versione remota',
                    value: remoteVersion!,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Compatibilità piattaforme',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            hasPlatforms
                ? Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: bot.platformCompatibility
                        .map((platform) => _platformChip(context, platform))
                        .toList(),
                  )
                : Text(
                    'Nessuna informazione disponibile.',
                    style: theme.textTheme.bodyMedium,
                  ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(downloadIcon, color: downloadColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    downloadText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _hasUpdate
                          ? downloadColor
                          : (_isDownloaded
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_isCheckingDownload || _isFetchingRemote)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (_hasUpdate && remoteVersion != null && remoteVersion.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  'Versione disponibile: $remoteVersion',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: downloadColor,
                  ),
                ),
              )
            else if (_isDownloaded && localVersion != null && localVersion.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  'Versione installata: $localVersion',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _metadataEntry(BuildContext context,
      {required IconData icon,
      required String label,
      required String value}) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  value.isNotEmpty ? value : 'n/d',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _platformChip(BuildContext context, String platform) {
    final theme = Theme.of(context);
    final normalized = platform.toLowerCase();
    IconData icon;
    String label;
    switch (normalized) {
      case 'desktop':
        icon = Icons.computer;
        label = 'Desktop';
        break;
      case 'browser':
        icon = Icons.public;
        label = 'Browser';
        break;
      default:
        icon = Icons.devices_other;
        label = platform;
        break;
    }
    final color = theme.colorScheme.primary;
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      backgroundColor: color.withOpacity(0.12),
      labelStyle: theme.textTheme.labelMedium
          ?.copyWith(color: color, fontWeight: FontWeight.w600),
      side: BorderSide(color: color.withOpacity(0.4)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final canOpenFolder = _localFolderPath != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: _isRunning ? null : () => _requestExecution(),
              icon: Icon(
                _isRunning ? Icons.hourglass_top : Icons.play_arrow,
              ),
              label: Text(
                  _isRunning ? 'Esecuzione in corso...' : 'Esegui bot'),
            ),
            OutlinedButton.icon(
              onPressed: _canDownloadAction ? _handleDownloadAction : null,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isDownloading
                    ? const SizedBox(
                        key: ValueKey('progress'),
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined, key: ValueKey('icon')),
              ),
              label: Text(_downloadButtonLabel),
            ),
            OutlinedButton.icon(
              onPressed: canOpenFolder ? _openFolder : null,
              icon: const Icon(Icons.folder_open),
              label: const Text('Apri cartella'),
            ),
            OutlinedButton.icon(
              onPressed:
                  _entries.isEmpty && _error == null ? null : _clearLog,
              icon: const Icon(Icons.clear_all),
              label: const Text('Pulisci log'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: Row(
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsSection(BuildContext context, Bot bot) {
    final permissions = bot.permissions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Permessi richiesti',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (permissions.isEmpty)
          Text(
            'Nessun permesso dichiarato nel manifest.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
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

  Widget _buildCompatBadges(BuildContext context, Bot bot) {
    final compat = bot.compat;
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
