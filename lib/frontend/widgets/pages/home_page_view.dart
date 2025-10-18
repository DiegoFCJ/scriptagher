import 'package:flutter/material.dart';
import '../../models/bot_navigation.dart';
import '../components/call_to_action_banner.dart';
import '../components/feature_grid_section.dart';
import '../components/gradient_hero_section.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _openBots(BuildContext context, BotCategory category) {
    Navigator.pushNamed(
      context,
      '/bots',
      arguments: BotListArguments(initialCategory: category),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.pushNamed(context, '/settings');
  }

  void _openTutorial(BuildContext context) {
    Navigator.pushNamed(context, '/tutorial');
  }

  List<FeatureGridItem> _buildFeatureItems(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return [
      FeatureGridItem(
        icon: Icons.download_rounded,
        title: 'Scaricati',
        description:
            'Consulta i bot già installati, organizzati per linguaggio e tag.',
        accentColor: accent,
        onTap: () => _openBots(context, BotCategory.downloaded),
      ),
      FeatureGridItem(
        icon: Icons.cloud_rounded,
        title: 'Online',
        description:
            'Scopri le ultime novità dal marketplace remoto e installa nuovi bot.',
        accentColor: const Color(0xFF5AC8FA),
        onTap: () => _openBots(context, BotCategory.online),
      ),
      FeatureGridItem(
        icon: Icons.folder_rounded,
        title: 'Locali',
        description:
            'Gestisci i bot presenti sul filesystem con strumenti di import rapido.',
        accentColor: const Color(0xFFFFB74D),
        onTap: () => _openBots(context, BotCategory.local),
      ),
      FeatureGridItem(
        icon: Icons.settings_rounded,
        title: 'Impostazioni',
        description:
            'Personalizza preferenze, telemetria e comportamento dell’applicazione.',
        accentColor: const Color(0xFF7E57C2),
        onTap: () => _openSettings(context),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1100;
        final isTablet = constraints.maxWidth >= 720 && constraints.maxWidth < 1100;
        final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);
        final horizontalPadding = isDesktop
            ? 120.0
            : isTablet
                ? 64.0
                : 24.0;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  isDesktop ? 64 : 32,
                  horizontalPadding,
                  28,
                ),
                sliver: SliverToBoxAdapter(
                  child: GradientHeroSection(
                    eyebrow: 'Scriptagher',
                    title: 'Automatizza i tuoi workflow in sicurezza',
                    subtitle:
                        'Organizza, installa e monitora bot Python pronti all’uso da un’unica dashboard.'
                        ' Il nuovo design offre un’esperienza coerente su desktop e web.',
                    icon: Icons.smart_toy_rounded,
                    primaryAction: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: () => _openBots(context, BotCategory.online),
                      icon: const Icon(Icons.explore_rounded),
                      label: const Text('Esplora i bot online'),
                    ),
                    secondaryAction: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                      onPressed: () => _openTutorial(context),
                      icon: const Icon(Icons.school_rounded),
                      label: const Text('Impara a crearne uno'),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 12,
                ),
                sliver: FeatureGridSection(
                  items: _buildFeatureItems(context),
                  crossAxisCount: crossAxisCount,
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  32,
                  horizontalPadding,
                  isDesktop ? 64 : 32,
                ),
                sliver: SliverToBoxAdapter(
                  child: CallToActionBanner(
                    title: 'Pubblica il tuo primo bot in pochi minuti',
                    subtitle:
                        'Segui il tutorial guidato per preparare l’ambiente, definire il manifesto Bot.json '
                        'e distribuire in sicurezza automazioni riutilizzabili.',
                    icon: Icons.rocket_launch_rounded,
                    primaryAction: FilledButton.icon(
                      onPressed: () => _openTutorial(context),
                      icon: const Icon(Icons.play_circle_fill_rounded),
                      label: const Text('Avvia il tutorial'),
                    ),
                    secondaryAction: OutlinedButton.icon(
                      onPressed: () => _openBots(context, BotCategory.local),
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Gestisci bot locali'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
