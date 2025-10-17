import 'package:flutter/material.dart';
import '../../models/bot.dart';

class BotCard extends StatelessWidget {
  final Bot bot;
  final VoidCallback onTap;

  const BotCard({super.key, required this.bot, required this.onTap});

  List<Widget> _buildStatusChips(BuildContext context) {
    final compat = bot.compat;
    final List<Widget> chips = [];

    if (compat.desktopStatus == 'compatible') {
      chips.add(_statusChip(
        context,
        label: 'Compatibile',
        color: Colors.green.shade600,
        icon: Icons.check_circle_outline,
      ));
    } else if (compat.desktopStatus == 'missing-runner') {
      final missing = compat.missingDesktopRuntimes.join(', ');
      final label = missing.isEmpty
          ? 'Runner mancante'
          : 'Runner mancante: $missing';
      chips.add(_statusChip(
        context,
        label: label,
        color: Colors.orange.shade700,
        icon: Icons.warning_amber_rounded,
      ));
    }

    if (compat.browserStatus == 'unsupported') {
      chips.add(_statusChip(
        context,
        label: 'Non supportato nel browser',
        color: Colors.blueGrey.shade600,
        icon: Icons.block,
      ));
    }

    return chips;
  }

  Widget _statusChip(BuildContext context,
      {required String label, required Color color, required IconData icon}) {
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      backgroundColor: color.withOpacity(0.12),
      labelStyle: Theme.of(context)
          .textTheme
          .labelMedium
          ?.copyWith(color: color, fontWeight: FontWeight.w600),
      side: BorderSide(color: color.withOpacity(0.4)),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chips = _buildStatusChips(context);
    final List<Widget> metadataChips = [];

    if (bot.version.isNotEmpty) {
      metadataChips.add(
        Chip(
          avatar: const Icon(Icons.tag, size: 16),
          label: Text('v${bot.version}'),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    if (bot.author != null && bot.author!.isNotEmpty) {
      metadataChips.add(
        Chip(
          avatar: const Icon(Icons.person, size: 16),
          label: Text(bot.author!),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    metadataChips.addAll(bot.tags.map((tag) => Chip(
          label: Text('#$tag'),
          visualDensity: VisualDensity.compact,
        )));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text(bot.botName),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bot.description),
            if (metadataChips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: metadataChips,
              ),
            ],
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: chips,
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
