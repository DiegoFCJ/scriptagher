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
        subtitle: Text(bot.description),
        onTap: onTap,
        trailing: bot.isBrowserCompatible
            ? const Icon(Icons.web, color: Colors.green)
            : const Icon(Icons.desktop_windows, color: Colors.grey),
      ),
    );
  }
}