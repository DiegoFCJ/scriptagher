import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:scriptagher/shared/config/api_base_url.dart';

import '../../models/bot.dart';
import '../../models/execution_log.dart';
import '../../services/bot_download_service.dart';
import '../../services/bot_get_service.dart';
import '../../services/browser_runner/browser_bot_runner.dart';
import '../../services/browser_runner/browser_runner_models.dart';

class BotDetailView extends StatefulWidget {
  const BotDetailView(
      {super.key,
      required this.bot,
      this.baseUrl,
      this.botGetService,
      this.botDownloadService});

  final Bot bot;
  final String? baseUrl;
  final BotGetService? botGetService;
  final BotDownloadService? botDownloadService;

  @override
  State<BotDetailView> createState() => _BotDetailViewState();
}

class _BotDetailViewState extends State<BotDetailView> {
  final ScrollController _scrollController = ScrollController();
  final List<_ConsoleEntry> _entries = [];
  final List<ExecutionLog> _logHistory = [];
  static const ValueKey<String> _runButtonKey =
      ValueKey<String>('bot-detail-run-button');
  String? _baseUrl;
  late final BotGetService _botGetService;
  BotDownloadService? _botDownloadService;
  Object? _backendError;
  bool _hasBackend = false;
  Bot? _downloadedBot;
  Bot? _remoteBot;
  bool _isStatusLoading = false;
  bool _isDownloadingBot = false;
  bool _isDeletingBot = false;
  bool _isDownloaded = false;
  bool _hasUpdateAvailable = false;

  http.Client? _client;
  StreamSubscription<String>? _subscription;
  BrowserBotRunner? _browserRunner;
  BrowserRunnerSession? _browserSession;
  StreamSubscription<BrowserRunnerEvent>? _browserSubscription;
  bool _autoScroll = true;
  bool _isRunning = false;
  bool _isTerminating = false;
  bool _isLoadingLogs = false;
  String _buffer = '';
  String? _error;
  String? _startStatus;
  String? _activeProcessId;
  int? _lastExitCode;

  String get _backendMissingMessage =>
      'Configura un endpoint API con --dart-define=API_BASE_URL=<url> per abilitare questa funzionalità.';

  String? get _backendErrorMessage {
    final error = _backendError;
    if (error == null) {
      return null;
    }
    if (error is StateError) {
      return error.message;
    }
    return error.toString();
  }

  bool get _canUseBackend =>
      _hasBackend && _baseUrl != null && _baseUrl!.isNotEmpty;

  Bot get _primaryBot => _remoteBot ?? _downloadedBot ?? widget.bot;
  Bot? get _installedBot => _downloadedBot;
  bool get _isDesktopPlatform => !kIsWeb &&
      (Platform.isLinux || Platform.isMacOS || Platform.isWindows);
  bool get _isMobilePlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool get _canOpenFolderAction =>
      _canUseBackend && _isDesktopPlatform && _isDownloaded && !_isDeletingBot;
  bool get _hasRunnableArtifacts => _canUseBackend &&
      (_isDownloaded || _primaryBot.isLocal || _shouldUseBrowserRunner);

  void _openTutorial() {
    Navigator.pushNamed(context, '/tutorial');
  }

  @override
  void initState() {
    super.initState();
    final providedBase = widget.baseUrl ?? ApiBaseUrl.resolve();
    _baseUrl = providedBase;
    _hasBackend = providedBase != null && providedBase.isNotEmpty;

    if (widget.botGetService != null) {
      _botGetService = widget.botGetService!;
    } else {
      try {
        _botGetService = BotGetService(baseUrl: providedBase);
      } on StateError catch (error) {
        _backendError = error;
        _botGetService = BotGetService.unavailable();
        _hasBackend = false;
      }
    }

    _botDownloadService = widget.botDownloadService;
    if (_botDownloadService == null && _hasBackend) {
      _botDownloadService = BotDownloadService(baseUrl: providedBase);
    }

    if (!widget.bot.isDownloaded && !widget.bot.isLocal) {
      _remoteBot = widget.bot;
    }
    if (_canUseBackend) {
      _loadLogs();
    }
    unawaited(_refreshBotStatus());
  }

  @override
  void dispose() {
    _stopExecution();
    _scrollController.dispose();
    _browserRunner?.dispose();
    super.dispose();
  }

  Future<void> _refreshBotStatus() async {
    setState(() {
      _isStatusLoading = true;
    });

    Bot? downloaded;
    Bot? remote = _remoteBot;

    try {
      downloaded = await _fetchDownloadedBot();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Errore durante il controllo dei bot scaricati: $e');
      }
    }

    if (remote == null) {
      try {
        remote = await _fetchRemoteBot();
      } catch (e) {
        if (mounted) {
          _showSnackBar('Errore durante il recupero dei metadati remoti: $e');
        }
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _downloadedBot = downloaded;
      if (remote != null) {
        _remoteBot = remote;
      }
      _isDownloaded = downloaded != null;
      _hasUpdateAvailable =
          remote != null && downloaded != null && _isRemoteNewer(remote, downloaded);
      _isStatusLoading = false;
    });
  }

  Future<Bot?> _fetchDownloadedBot() async {
    final bots = await _botGetService.fetchDownloadedBotsFlat();
    return _findMatchingBot(bots);
  }

  Future<Bot?> _fetchRemoteBot() async {
    // Evita chiamate inutili se il bot di partenza è già remoto.
    if (!widget.bot.isDownloaded && !widget.bot.isLocal) {
      return widget.bot;
    }

    final grouped = await _botGetService.fetchOnlineBots();
    final botsForLanguage = grouped[widget.bot.language] ?? const <Bot>[];
    return _findMatchingBot(botsForLanguage);
  }

  Bot? _findMatchingBot(Iterable<Bot> bots) {
    for (final bot in bots) {
      if (bot.botName == widget.bot.botName &&
          bot.language == widget.bot.language) {
        return bot;
      }
    }
    return null;
  }

  bool _isRemoteNewer(Bot remote, Bot local) {
    final remoteHash = remote.archiveSha256;
    final localHash = local.archiveSha256;
    if (remoteHash != null &&
        remoteHash.isNotEmpty &&
        localHash != null &&
        localHash.isNotEmpty &&
        remoteHash != localHash) {
      return true;
    }

    final remoteVersion = remote.version;
    final localVersion = local.version;
    if (remoteVersion.isNotEmpty &&
        localVersion.isNotEmpty &&
        remoteVersion != localVersion) {
      return true;
    }

    return false;
  }

  Future<void> _handleDownloadOrUpdate() async {
    if (_isDownloadingBot) {
      return;
    }

    final downloadService = _botDownloadService;
    if (!_canUseBackend || downloadService == null) {
      _showSnackBar(_backendMissingMessage);
      return;
    }

    setState(() {
      _isDownloadingBot = true;
    });

    var completed = false;
    try {
      final bot = await downloadService.downloadBot(
          widget.bot.language, widget.bot.botName);
      completed = true;
      if (!mounted) {
        return;
      }
      setState(() {
        _downloadedBot = bot;
        _isDownloaded = true;
        _hasUpdateAvailable = false;
      });
      _showSnackBar('Bot scaricato correttamente.');
    } catch (e) {
      if (mounted) {
        _showSnackBar('Errore durante il download: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingBot = false;
        });
      }
    }

    if (completed && mounted) {
      await _refreshBotStatus();
    }
  }

  Future<void> _confirmAndDeleteBot() async {
    if (!_isDownloaded || _isDeletingBot) {
      return;
    }

    final downloadService = _botDownloadService;
    if (!_canUseBackend || downloadService == null) {
      _showSnackBar(_backendMissingMessage);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Elimina bot'),
          content: Text(
              'Vuoi eliminare definitivamente ${widget.bot.botName}? Verranno rimossi i file locali.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isDeletingBot = true;
    });

    var deleted = false;
    try {
      await downloadService.deleteBot(
          widget.bot.language, widget.bot.botName);
      deleted = true;
    } catch (e) {
      if (mounted) {
        _showSnackBar('Errore durante l\'eliminazione: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingBot = false;
        });
      }
    }

    if (!mounted || !deleted) {
      return;
    }

    setState(() {
      _downloadedBot = null;
      _isDownloaded = false;
      _hasUpdateAvailable = false;
    });
    _showSnackBar('Bot eliminato correttamente.');

    await _refreshBotStatus();
  }

  Future<void> _openBotFolder() async {
    if (!_canOpenFolderAction) {
      _showSnackBar('Apertura cartella non supportata su questa piattaforma.');
      return;
    }

    final bot = _installedBot;
    if (bot == null) {
      _showSnackBar('Scarica il bot per aprire la cartella.');
      return;
    }

    final sourcePath = bot.sourcePath;
    if (sourcePath.isEmpty) {
      _showSnackBar('Percorso della cartella non disponibile.');
      return;
    }

    final file = File(sourcePath);
    Directory directory;
    if (await file.exists()) {
      directory = file.parent;
    } else {
      directory = Directory(sourcePath);
    }

    if (!await directory.exists()) {
      _showSnackBar('Cartella non trovata: ${directory.path}');
      return;
    }

    try {
      late final String command;
      late final List<String> args;

      if (Platform.isMacOS) {
        command = 'open';
        args = [directory.path];
      } else if (Platform.isWindows) {
        command = 'explorer';
        args = [directory.path];
      } else if (Platform.isLinux) {
        command = 'xdg-open';
        args = [directory.path];
      } else {
        _showSnackBar('Sistema operativo non supportato per questa operazione.');
        return;
      }

      final result = await Process.run(command, args);
      if (result.exitCode != 0) {
        final stderrOutput = result.stderr?.toString().trim();
        final errorMessage =
            (stderrOutput != null && stderrOutput.isNotEmpty)
                ? stderrOutput
                : 'exit code ${result.exitCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      _showSnackBar('Errore durante l\'apertura della cartella: $e');
      return;
    }

    _showSnackBar('Cartella aperta: ${directory.path}');
  }

  Future<void> _loadLogs() async {
    if (!_canUseBackend) {
      setState(() {
        _isLoadingLogs = false;
        _logHistory.clear();
        _lastExitCode = null;
      });
      return;
    }

    setState(() {
      _isLoadingLogs = true;
    });

    final uri = Uri.parse(
        '${_baseUrl!}/bots/${Uri.encodeComponent(widget.bot.language)}/${Uri.encodeComponent(widget.bot.botName)}/logs');

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
          _lastExitCode = logs.isNotEmpty ? logs.first.exitCode : null;
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
    final permissions = _primaryBot.permissions;
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
    final reason = _executionDisabledReason;
    assert(_hasRunnableArtifacts,
        'Cannot start execution without local artifacts');
    assert(_canExecuteBot, 'Cannot start execution on incompatible platform');
    if (reason != null) {
      _showSnackBar(reason);
      return;
    }

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
    if (!_canUseBackend) {
      _showSnackBar(_backendMissingMessage);
      return;
    }

    _stopExecution();
    setState(() {
      _entries.clear();
      _error = null;
      _startStatus = null;
      _isRunning = true;
      _activeProcessId = null;
      _lastExitCode = null;
    });

    final baseUri = Uri.parse(
        '${_baseUrl!}/bots/${Uri.encodeComponent(widget.bot.language)}/${Uri.encodeComponent(widget.bot.botName)}/start');
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
          _activeProcessId = processId;
          _lastExitCode = null;
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
    if (!_canUseBackend) {
      _showSnackBar(_backendMissingMessage);
      return;
    }

    _stopExecution();
    setState(() {
      _entries.clear();
      _error = null;
      _startStatus = null;
      _isRunning = true;
      _activeProcessId = null;
      _lastExitCode = null;
    });

    final client = http.Client();
    _client = client;

    final baseUri = Uri.parse(
        '${_baseUrl!}/bots/${Uri.encodeComponent(widget.bot.language)}/${Uri.encodeComponent(widget.bot.botName)}/stream');
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
          _activeProcessId = null;
        });
        _stopExecution();
      }, onDone: () {
        if (!mounted) return;
        setState(() {
          _isRunning = false;
          _activeProcessId = null;
        });
        _stopExecution();
        _loadLogs();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Errore durante l\'avvio: $e';
        _isRunning = false;
        _activeProcessId = null;
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

  Future<void> _sendSignal(String action) async {
    if (!_canUseBackend) {
      _showSnackBar(_backendMissingMessage);
      return;
    }

    final processId = _activeProcessId;
    if (processId == null) {
      _showSnackBar('Nessun processo attivo da controllare.');
      return;
    }

    setState(() {
      _isTerminating = true;
    });

    final uri = Uri.parse(
            '${_baseUrl!}/bots/${Uri.encodeComponent(widget.bot.language)}/${Uri.encodeComponent(widget.bot.botName)}/$action')
        .replace(queryParameters: {'processId': processId});

    try {
      final response = await http.post(uri);
      if (response.statusCode != 200) {
        String message =
            'Impossibile completare l\'operazione ($action). Codice ${response.statusCode}.';
        if (response.body.isNotEmpty) {
          try {
            final decoded = jsonDecode(response.body) as Map<String, dynamic>;
            final error = decoded['message'] ?? decoded['error'];
            if (error is String && error.isNotEmpty) {
              message = error;
            }
          } catch (_) {}
        }
        _showSnackBar(message);
        return;
      }

      Map<String, dynamic> data = <String, dynamic>{};
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {}
      }

      final exitCode = data['exitCode'];
      final status = data['status']?.toString();

      setState(() {
        if (exitCode is int) {
          _lastExitCode = exitCode;
        }
        if (status == 'terminated' || exitCode is int) {
          _activeProcessId = null;
        }
      });

      if (status == 'terminated') {
        _showSnackBar('Processo terminato (exit code: ${exitCode ?? 'n/d'}).');
        await _loadLogs();
      } else if (status == 'not_running') {
        _showSnackBar('Nessun processo attivo. Exit code: ${exitCode ?? 'n/d'}');
        await _loadLogs();
      } else {
        _showSnackBar('Segnale "$action" inviato al processo.');
      }
    } catch (e) {
      _showSnackBar('Errore durante l\'invio del segnale: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTerminating = false;
        });
      }
    }
  }

  Future<void> _stopBot() => _sendSignal('stop');

  Future<void> _killBot() => _sendSignal('kill');

  bool get _shouldUseBrowserRunner => _canUseBackend &&
      kIsWeb &&
      BrowserBotRunner.isSupported &&
      _primaryBot.compat.canRunInBrowser;

  bool get _canExecuteBot {
    final compat = _primaryBot.compat;

    if (kIsWeb) {
      if (!BrowserBotRunner.isSupported) {
        return false;
      }
      return compat.canRunInBrowser;
    }

    if (_isDesktopPlatform) {
      if (compat.desktopRuntimes.isEmpty) {
        return true;
      }
      return compat.missingDesktopRuntimes.isEmpty;
    }

    if (_isMobilePlatform) {
      final mobileCompat = compat.mobile;
      if (!mobileCompat.isSupported) {
        return false;
      }
      final platformKey = Platform.isIOS ? 'ios' : 'android';
      return mobileCompat.supportsPlatform(platformKey);
    }

    return true;
  }

  String? get _executionDisabledReason {
    if (!_canUseBackend) {
      return _backendMissingMessage;
    }

    if (!_hasRunnableArtifacts) {
      if (!_isDownloaded && !_primaryBot.isLocal) {
        return 'Scarica il bot per eseguirlo prima di avviare l\'esecuzione.';
      }
      return 'Il bot non dispone dei file necessari per essere eseguito.';
    }

    if (_canExecuteBot) {
      return null;
    }

    final compat = _primaryBot.compat;
    if (kIsWeb) {
      if (!BrowserBotRunner.isSupported) {
        return 'Il browser corrente non supporta l\'esecuzione dei bot.';
      }
      return compat.browserReason?.isNotEmpty == true
          ? compat.browserReason
          : 'Il bot non è compatibile con l\'esecuzione nel browser.';
    }

    if (_isDesktopPlatform) {
      final missing = compat.missingDesktopRuntimes;
      if (missing.isNotEmpty) {
        return 'Runtime mancanti: ${missing.join(', ')}.';
      }
      if (!compat.isDesktopCompatible && compat.desktopRuntimes.isNotEmpty) {
        return 'Il bot non è compatibile con questo ambiente desktop.';
      }
      return 'Il bot non può essere eseguito su questo computer.';
    }

    if (_isMobilePlatform) {
      final reason = compat.mobile.reason;
      if (reason != null && reason.isNotEmpty) {
        return reason;
      }
      final platformName = Platform.isIOS ? 'iOS' : 'Android';
      return 'Il bot non è compatibile con $platformName.';
    }

    return 'Il bot non è compatibile con questo dispositivo.';
  }

  Future<void> _startBrowserExecution() async {
    if (!_canUseBackend) {
      _showSnackBar(_backendMissingMessage);
      return;
    }

    _stopExecution();
    setState(() {
      _entries.clear();
      _error = null;
      _isRunning = true;
      _activeProcessId = null;
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
        _primaryBot,
        baseUrl: _baseUrl!,
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
              _activeProcessId = null;
              if (event.code is int) {
                _lastExitCode = event.code as int;
              }
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
          _activeProcessId = null;
        });
      }, onDone: () {
        if (!mounted) return;
        setState(() {
          _isRunning = false;
          _activeProcessId = null;
        });
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossibile avviare nel browser: $error';
        _isRunning = false;
        _activeProcessId = null;
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
    if (!_canUseBackend) {
      _showSnackBar(_backendMissingMessage);
      return;
    }

    final uri = Uri.parse(
        '${_baseUrl!}/bots/${Uri.encodeComponent(widget.bot.language)}/${Uri.encodeComponent(widget.bot.botName)}/logs/${Uri.encodeComponent(log.runId)}');
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
    if (!_canUseBackend) {
      _showSnackBar(_backendMissingMessage);
      return;
    }

    final uri = Uri.parse(
        '${_baseUrl!}/bots/${Uri.encodeComponent(widget.bot.language)}/${Uri.encodeComponent(widget.bot.botName)}/logs/${Uri.encodeComponent(log.runId)}');
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

  Widget _buildBackendBanner(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondaryContainer;
    final onColor = theme.colorScheme.onSecondaryContainer;
    final textTheme = theme.textTheme;
    final errorMessage = _backendErrorMessage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_off_outlined, color: onColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Funzionalità limitate',
                  style: textTheme.titleMedium?.copyWith(
                    color: onColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _backendMissingMessage,
            style: textTheme.bodyMedium?.copyWith(color: onColor),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 6),
            Text(
              'Nel browser è disponibile solo una modalità anteprima con i metadati pubblicati tramite GitHub Pages.',
              style: textTheme.bodySmall?.copyWith(color: onColor),
            ),
          ],
          if (errorMessage != null && errorMessage.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              errorMessage,
              style: textTheme.bodySmall?.copyWith(color: onColor),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bot = _primaryBot;
    final metadataChips = _buildMetadataChips(context);
    final updateBanner = _buildUpdateBanner(context);
    final theme = Theme.of(context);
    final hasPermissions = bot.permissions.isNotEmpty;

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mediaHeight = MediaQuery.of(context).size.height;
          final availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : mediaHeight;
          final consolePanelHeight = math.max(availableHeight * 0.4, 260.0);
          final historyPanelHeight = math.max(availableHeight * 0.25, 220.0);

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: availableHeight),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bot.botName,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bot.description.isNotEmpty
                          ? bot.description
                          : 'Nessuna descrizione disponibile.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    if (!_canUseBackend) ...[
                      _buildBackendBanner(context),
                      const SizedBox(height: 12),
                    ],
                    if (metadataChips != null) ...[
                      metadataChips,
                      const SizedBox(height: 12),
                    ],
                    _buildMetadataDetails(context),
                    const SizedBox(height: 12),
                    if (_isStatusLoading) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                    ],
                    if (!_isStatusLoading && updateBanner != null) ...[
                      updateBanner,
                      const SizedBox(height: 12),
                    ] else if (!_isStatusLoading && _isDownloaded && !_hasUpdateAvailable) ...[
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Bot installato all\'ultima versione disponibile.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildPrimaryActions(context),
                    const SizedBox(height: 20),
                    _buildPermissionsSection(context),
                    if (hasPermissions) const SizedBox(height: 12),
                    _buildCompatBadges(context),
                    const SizedBox(height: 20),
                    _buildExecutionControls(context),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    if (_startStatus != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _startStatus!,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (_activeProcessId != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Processo attivo: $_activeProcessId',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Ultimo exit code: ${_lastExitCode?.toString() ?? 'n/d'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (kIsWeb && !_shouldUseBrowserRunner) ...[
                      const SizedBox(height: 12),
                      Text(
                        _primaryBot.compat.browserReason ??
                            'Questo bot non è compatibile con il runner browser.',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildConsolePanel(consolePanelHeight),
                    const SizedBox(height: 20),
                    _buildHistoryPanel(historyPanelHeight, theme),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget? _buildMetadataChips(BuildContext context) {
    final bot = _primaryBot;
    final List<Widget> chips = [];

    if (bot.version.isNotEmpty) {
      chips.add(
        Chip(
          avatar: const Icon(Icons.tag, size: 16),
          label: Text('v${bot.version}'),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    if (bot.author?.isNotEmpty == true) {
      chips.add(
        Chip(
          avatar: const Icon(Icons.person_outline, size: 16),
          label: Text(bot.author!),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    for (final tag in bot.tags) {
      if (tag.isEmpty) continue;
      chips.add(
        Chip(
          label: Text('#$tag'),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    if (chips.isEmpty) {
      return null;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: chips,
    );
  }

  Widget _buildMetadataDetails(BuildContext context) {
    final bot = _primaryBot;
    final installed = _installedBot;
    final List<Widget> details = [];

    details.add(_metadataLine(context, 'Linguaggio', bot.language));

    final availableVersion = bot.version.isNotEmpty ? bot.version : 'n/d';
    details.add(
      _metadataLine(context, 'Versione disponibile', availableVersion),
    );

    if (installed != null) {
      final installedVersion =
          installed.version.isNotEmpty ? installed.version : 'n/d';
      details.add(
        _metadataLine(context, 'Versione installata', installedVersion),
      );
    }

    if (bot.author?.isNotEmpty == true) {
      details.add(_metadataLine(context, 'Autore', bot.author!));
    }

    if (bot.startCommand.isNotEmpty) {
      details.add(
        _metadataLine(context, 'Comando di avvio', bot.startCommand),
      );
    }

    if (details.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < details.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          details[i],
        ],
      ],
    );
  }

  Widget _metadataLine(BuildContext context, String label, String value) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium;
    final labelStyle = baseStyle?.copyWith(fontWeight: FontWeight.w600);
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: '$label: ', style: labelStyle),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Widget _buildConsolePanel(double targetHeight) {
    final height = math.max(220.0, targetHeight);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 220.0, maxHeight: height),
      child: SizedBox(
        height: height,
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
    );
  }

  Widget _buildHistoryPanel(double targetHeight, ThemeData theme) {
    final height = math.max(200.0, targetHeight);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 200.0, maxHeight: height),
      child: SizedBox(
        height: height,
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
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Aggiorna',
                      onPressed:
                          (!_canUseBackend || _isLoadingLogs) ? null : _loadLogs,
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
    );
  }

  Widget? _buildUpdateBanner(BuildContext context) {
    if (!_hasUpdateAvailable || _remoteBot == null || _installedBot == null) {
      return null;
    }

    final remote = _remoteBot!;
    final installed = _installedBot!;
    final remoteVersion = remote.version.isNotEmpty
        ? remote.version
        : (remote.archiveSha256 ?? 'n/d');
    final installedVersion = installed.version.isNotEmpty
        ? installed.version
        : (installed.archiveSha256 ?? 'n/d');

    final theme = Theme.of(context);
    final onContainerColor = theme.colorScheme.onSecondaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.system_update_alt, color: onContainerColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Aggiornamento disponibile: versione $remoteVersion (installata $installedVersion).',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onContainerColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActions(BuildContext context) {
    final bool hasDownloadService =
        _canUseBackend && _botDownloadService != null;
    final bool enableDownload = hasDownloadService &&
        !_isDownloadingBot &&
        !_isDeletingBot &&
        (!_isDownloaded || _hasUpdateAvailable);
    final bool showSpinner = _isDownloadingBot;
    final Widget downloadIcon = showSpinner
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(_hasUpdateAvailable ? Icons.system_update_alt : Icons.download);
    final String downloadLabel = showSpinner
        ? 'Download in corso...'
        : _hasUpdateAvailable
            ? 'Aggiorna'
            : _isDownloaded
                ? 'Scaricato'
                : 'Scarica';
    final bool showDelete = _isDownloaded && hasDownloadService;
    final bool deleteSpinner = _isDeletingBot;
    final Widget deleteIcon = deleteSpinner
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.delete);
    final String deleteLabel =
        deleteSpinner ? 'Eliminazione...' : 'Elimina';
    final bool isExecutionBusy =
        _isRunning || _isTerminating || _activeProcessId != null;
    final bool canRequestExecution =
        _hasRunnableArtifacts && _canExecuteBot && !isExecutionBusy;
    final bool shouldShowExecutionTooltip =
        !_hasRunnableArtifacts || !_canExecuteBot;
    final String? executionTooltip =
        shouldShowExecutionTooltip ? _executionDisabledReason : null;

    Widget executeButton = ElevatedButton.icon(
      key: _runButtonKey,
      onPressed: canRequestExecution ? _requestExecution : null,
      icon: const Icon(Icons.play_arrow),
      label: Text(_isRunning
          ? 'Esecuzione in corso...'
          : _isTerminating
              ? 'Terminazione in corso...'
              : _activeProcessId != null
                  ? 'Processo attivo'
                  : 'Esegui'),
    );

    if (shouldShowExecutionTooltip && executionTooltip != null) {
      executeButton = Tooltip(
        message: executionTooltip,
        waitDuration: const Duration(milliseconds: 500),
        child: executeButton,
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElevatedButton.icon(
          onPressed: enableDownload ? _handleDownloadOrUpdate : null,
          icon: downloadIcon,
          label: Text(downloadLabel),
        ),
        OutlinedButton.icon(
          onPressed: _canOpenFolderAction ? _openBotFolder : null,
          icon: const Icon(Icons.folder_open),
          label: const Text('Apri cartella'),
        ),
        executeButton,
        if (showDelete)
          ElevatedButton.icon(
            onPressed: deleteSpinner ? null : _confirmAndDeleteBot,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            icon: deleteIcon,
            label: Text(deleteLabel),
          ),
      ],
    );
  }

  Widget _buildExecutionControls(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: (_isTerminating || _activeProcessId == null)
                    ? null
                    : _stopBot,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop'),
              ),
              ElevatedButton.icon(
                onPressed: (_isTerminating || _activeProcessId == null)
                    ? null
                    : _killBot,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                icon: const Icon(Icons.cancel_presentation_outlined),
                label: const Text('Kill'),
              ),
              OutlinedButton(
                onPressed: _entries.isEmpty && _error == null ? null : _clearLog,
                child: const Text('Pulisci log'),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
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
          ],
        ),
      ],
    );
  }

  Widget _buildPermissionsSection(BuildContext context) {
    final permissions = _primaryBot.permissions;
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
    final compat = _primaryBot.compat;
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
    if (!_canUseBackend) {
      return Center(
        child: Text(
          'Storico disponibile solo con un backend configurato (--dart-define=API_BASE_URL=<url>).',
        ),
      );
    }

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
