import 'package:flutter/material.dart';
import '../../models/bot.dart';

class BotCard extends StatelessWidget {
  final Bot bot;
  final VoidCallback onTap;

  BotCard({required this.bot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text(bot.botName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(bot.description),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _buildCompatChips(context),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  List<Widget> _buildCompatChips(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[];

    final desktop = bot.compat.desktop;
    if (desktop != null) {
      final missing = desktop.missingRunners;
      if (missing.isEmpty) {
        chips.add(Chip(
          label: const Text('Compatibile'),
          backgroundColor: theme.colorScheme.primaryContainer,
          labelStyle: TextStyle(color: theme.colorScheme.onPrimaryContainer),
        ));
      } else {
        chips.add(Chip(
          label: Text('Runner mancante: ${missing.join(', ')}'),
          backgroundColor: theme.colorScheme.errorContainer,
          labelStyle: TextStyle(color: theme.colorScheme.onErrorContainer),
        ));
      }
    }

    final browser = bot.compat.browser;
    if (browser != null && !browser.supported) {
      chips.add(Chip(
        label: const Text('Non supportato nel browser'),
        backgroundColor: theme.colorScheme.surfaceVariant,
      ));
    } else if (browser != null && browser.supported) {
      chips.add(Chip(
        label: const Text('Compatibile nel browser'),
        backgroundColor: theme.colorScheme.secondaryContainer,
        labelStyle: TextStyle(color: theme.colorScheme.onSecondaryContainer),
      ));
    }

    if (chips.isEmpty) {
      chips.add(Chip(
        label: const Text('Compatibilità non dichiarata'),
        backgroundColor: theme.colorScheme.surfaceVariant,
      ));
    }

    return chips;
  }
}