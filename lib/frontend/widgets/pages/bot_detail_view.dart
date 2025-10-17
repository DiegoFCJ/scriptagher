import 'package:flutter/material.dart';
import '../../models/bot.dart';
import '../../services/bot_execution_service.dart';

class BotDetailView extends StatefulWidget {
  final Bot bot;

  BotDetailView({required this.bot});

  @override
  State<BotDetailView> createState() => _BotDetailViewState();
}

class _BotDetailViewState extends State<BotDetailView> {
  final BotExecutionService _executionService = BotExecutionService();
  bool _isStarting = false;
  String? _statusMessage;

  Future<void> _startBot() async {
    if (_isStarting) return;
    setState(() {
      _isStarting = true;
      _statusMessage = null;
    });

    try {
      final pid = await _executionService.startBot(widget.bot);
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Processo avviato con PID: $pid';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bot avviato (PID: $pid)')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Errore durante l\'avvio: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'avvio: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isStarting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bot = widget.bot;
    return Scaffold(
      appBar: AppBar(
        title: Text(bot.botName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nome: ${bot.botName}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 10),
            Text(
              'Descrizione: ${bot.description}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isStarting ? null : _startBot,
              child: _isStarting
                  ? SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Esegui Bot'),
            ),
            if (_statusMessage != null) ...[
              SizedBox(height: 20),
              Text(
                _statusMessage!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ]
          ],
        ),
      ),
    );
  }
}