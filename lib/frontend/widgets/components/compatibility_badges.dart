import 'package:flutter/material.dart';
import '../../models/bot.dart';

class CompatibilityBadges extends StatelessWidget {
  final Bot bot;
  final bool showHeading;

  const CompatibilityBadges({super.key, required this.bot, this.showHeading = false});

  @override
  Widget build(BuildContext context) {
    final badges = _buildBadges(context);

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    final content = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges,
    );

    if (!showHeading) {
      return content;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compatibilità',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }

  List<Widget> _buildBadges(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = bot.compat?.desktop;
    final browser = bot.compat?.browser;

    final compatibleColor = theme.colorScheme.tertiaryContainer;
    final compatibleTextColor = theme.colorScheme.onTertiaryContainer;
    final warningColor = theme.colorScheme.errorContainer;
    final warningTextColor = theme.colorScheme.onErrorContainer;
    final neutralColor = theme.colorScheme.surfaceVariant;
    final neutralTextColor = theme.colorScheme.onSurfaceVariant;

    final badges = <Widget>[];

    if (desktop?.runnerAvailable == true) {
      badges.add(_statusChip(
        label: 'Compatibile',
        background: compatibleColor,
        foreground: compatibleTextColor,
        icon: Icons.check_circle,
      ));
    } else if (desktop?.runnerAvailable == false) {
      final runnerLabel = desktop?.runner != null
          ? 'Runner mancante (${desktop!.runner})'
          : 'Runner mancante';
      badges.add(_statusChip(
        label: runnerLabel,
        background: warningColor,
        foreground: warningTextColor,
        icon: Icons.warning_amber,
      ));
    }

    if (browser?.supported == false) {
      badges.add(_statusChip(
        label: 'Non supportato nel browser',
        background: neutralColor,
        foreground: neutralTextColor,
        icon: Icons.block,
      ));
    }

    return badges;
  }

  Widget _statusChip({
    required String label,
    required Color background,
    required Color foreground,
    required IconData icon,
  }) {
    return Chip(
      avatar: Icon(icon, size: 18, color: foreground),
      label: Text(label, style: TextStyle(color: foreground)),
      backgroundColor: background,
      shape: const StadiumBorder(),
    );
  }
}
