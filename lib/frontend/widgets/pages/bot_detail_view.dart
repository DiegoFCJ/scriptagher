import 'package:flutter/material.dart';
import '../../models/bot.dart';

class BotDetailView extends StatelessWidget {
  final Bot bot;

  BotDetailView({required this.bot});

  @override
  Widget build(BuildContext context) {
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
            SizedBox(height: 10),
            Text(
              'Descrizione: ${bot.description}',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge, // Cambiato bodyText1 in bodyLarge
            ),
            SizedBox(height: 20),
            Text(
              'Linguaggio: ${bot.language}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 12),
            SelectableText(
              'Start command: ${bot.startCommand}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontFamily: 'monospace'),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Azione quando si vuole eseguire l'operazione sul bot
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Esegui bot: ${bot.botName}')),
                );
              },
              child: Text('Esegui Bot'),
            ),
            SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/create-bot'),
              icon: const Icon(Icons.school_outlined),
              label: const Text('Impara a creare un nuovo bot'),
            ),
          ],
        ),
      ),
    );
  }
}