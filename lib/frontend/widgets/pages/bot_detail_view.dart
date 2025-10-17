import 'package:flutter/material.dart';

import '../../models/bot.dart';
import '../../services/bot_execution_service.dart';

class BotDetailView extends StatefulWidget {
  final Bot bot;

  const BotDetailView({super.key, required this.bot});

  @override
  State<BotDetailView> createState() => _BotDetailViewState();
}

class _BotDetailViewState extends State<BotDetailView> {
  final BotExecutionService _executionService = BotExecutionService();
  int? _exitCode;
  String? _errorMessage;
  bool _isProcessing = false;

  Future<void> _handleAction(Future<int?> Function() action) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final exitCode = await action();
      setState(() {
        _exitCode = exitCode;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
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
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium, // Cambiato headline5 in headlineMedium
            ),
            const SizedBox(height: 10),
            Text(
              'Descrizione: ${bot.description}',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge, // Cambiato bodyText1 in bodyLarge
            ),
            const SizedBox(height: 20),
            Text(
              'Codice di uscita: ${_exitCode ?? 'non disponibile'}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Esegui bot: ${bot.botName}')),
                      );
                    },
                    child: const Text('Esegui Bot'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _handleAction(() =>
                        _executionService.stopBot(bot.language, bot.botName)),
                    child: const Text('Stop'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.errorContainer,
                    ),
                    onPressed: () => _handleAction(() =>
                        _executionService.killBot(bot.language, bot.botName)),
                    child: const Text('Kill'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
