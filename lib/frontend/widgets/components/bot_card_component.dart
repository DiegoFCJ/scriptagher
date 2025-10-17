import 'package:flutter/material.dart';
import '../../models/bot.dart';
import 'compatibility_badges.dart';

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
            if (_hasCompatBadges(bot)) SizedBox(height: 8),
            CompatibilityBadges(bot: bot),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  bool _hasCompatBadges(Bot bot) {
    final desktop = bot.compat?.desktop;
    final browser = bot.compat?.browser;

    final hasDesktopStatus = desktop?.runnerAvailable != null;
    final browserUnsupported = browser?.supported == false;

    return hasDesktopStatus || browserUnsupported;
  }
}
