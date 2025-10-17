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
          children: [
            Text(bot.description),
            if (bot.author.isNotEmpty || bot.version.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  [
                    if (bot.author.isNotEmpty) 'Autore: ${bot.author}',
                    if (bot.version.isNotEmpty) 'Versione: ${bot.version}',
                  ].join(' • '),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            if (bot.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Wrap(
                  spacing: 4,
                  runSpacing: -8,
                  children: bot.tags
                      .map((tag) => Chip(
                            label: Text(tag),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}