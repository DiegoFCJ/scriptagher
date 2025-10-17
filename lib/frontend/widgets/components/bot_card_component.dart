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
        subtitle: Text('${bot.origin} • ${bot.description}'),
        onTap: onTap,
      ),
    );
  }
}