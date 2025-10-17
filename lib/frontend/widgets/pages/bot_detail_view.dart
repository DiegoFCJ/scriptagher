import 'package:flutter/material.dart';
import '../../models/bot.dart';
import '../../services/bot_get_service.dart';
import 'package:scriptagher/shared/constants/permissions.dart';

class BotDetailView extends StatefulWidget {
  final Bot bot;

  BotDetailView({required this.bot});

  @override
  State<BotDetailView> createState() => _BotDetailViewState();
}

class _BotDetailViewState extends State<BotDetailView> {
  final BotGetService _botService = BotGetService();

  Bot get bot => widget.bot;

  Future<void> _promptAndExecute(BuildContext context) async {
    final theme = Theme.of(context);
    final permissions = bot.permissions;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Autorizzazioni richieste'),
          content: permissions.isEmpty
              ? const Text('Questo bot non richiede permessi aggiuntivi.')
              : SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: permissions
                        .map(
                          (permission) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.security),
                            title: Text(permission, style: theme.textTheme.titleMedium),
                            subtitle: Text(
                                BotPermissions.descriptions[permission] ??
                                    'Permesso personalizzato'),
                          ),
                        )
                        .toList(),
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Concedi e avvia'),
            ),
          ],
        );
      },
    );

    if (accepted != true) {
      return;
    }

    try {
      await _botService.executeBot(bot, permissions);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Esecuzione avviata per ${bot.botName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }

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
              style: Theme.of(context).textTheme.headlineMedium,  // Cambiato headline5 in headlineMedium
            ),
            SizedBox(height: 10),
            Text(
              'Descrizione: ${bot.description}',
              style: Theme.of(context).textTheme.bodyLarge,  // Cambiato bodyText1 in bodyLarge
            ),
            SizedBox(height: 20),
            if (bot.permissions.isNotEmpty) ...[
              Text(
                'Permessi richiesti:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              ...bot.permissions.map(
                (permission) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      const Icon(Icons.security, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          BotPermissions.descriptions[permission] ?? permission,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _promptAndExecute(context),
              child: Text('Esegui Bot'),
            ),
          ],
        ),
      ),
    );
  }
}