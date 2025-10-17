import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/bot.dart';

class BotDetailView extends StatefulWidget {
  const BotDetailView({super.key, required this.bot, this.baseUrl = 'http://localhost:8080'});

  final Bot bot;
  final String baseUrl;

  @override
  State<BotDetailView> createState() => _BotDetailViewState();
}

class _BotDetailViewState extends State<BotDetailView> {
  final ScrollController _scrollController = ScrollController();
  final List<_ConsoleEntry> _entries = [];

  http.Client? _client;
  StreamSubscription<String>? _subscription;
  bool _autoScroll = true;
  bool _isRunning = false;
  String _buffer = '';
  String? _error;

  @override
  void dispose() {
    _stopExecution();
    _scrollController.dispose();
    super.dispose();
  }

  void _startExecution() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bot.botName),
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
          ],
        ),
      ),
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
