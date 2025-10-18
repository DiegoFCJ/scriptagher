import 'package:flutter/material.dart';

import '../../models/bot_navigation.dart';
import '../components/app_gradient_background.dart';
import '../components/home_call_to_action_section.dart';
import '../components/home_feature_grid.dart';
import '../components/home_hero_section.dart';

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

  void _openDocs(BuildContext context) {
    Navigator.pushNamed(context, '/tutorial');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewportHeight = MediaQuery.of(context).size.height;
    final precacheExtent = viewportHeight.isFinite && viewportHeight > 0
        ? viewportHeight * 1.5
        : 1200.0;

    final features = [
      HomeFeatureItem(
        title: 'Scaricati',
        description:
            'Consulta i bot installati localmente, aggiorna versioni e monitora gli esiti delle ultime esecuzioni.',
        icon: Icons.download_rounded,
        accentColor: colorScheme.primary,
        onTap: () => _openBots(context, BotCategory.downloaded),
      ),
      HomeFeatureItem(
        title: 'Online',
        description:
            'Esplora il marketplace ufficiale, filtra per linguaggio, tag o permessi e installa nuovi bot.',
        icon: Icons.cloud_rounded,
        accentColor: colorScheme.tertiary,
        onTap: () => _openBots(context, BotCategory.online),
      ),
      HomeFeatureItem(
        title: 'Locali',
        description:
            'Importa cartelle e archivi ZIP, valida Bot.json e prepara un ambiente isolato per l\'esecuzione.',
        icon: Icons.folder_rounded,
        accentColor: colorScheme.secondary,
        onTap: () => _openBots(context, BotCategory.local),
      ),
      HomeFeatureItem(
        title: 'Impostazioni',
        description:
            'Personalizza tema, preferenze di privacy, telemetria e integrazioni con strumenti esterni.',
        icon: Icons.tune_rounded,
        accentColor: colorScheme.errorContainer,
        onTap: () => _openSettings(context),
      ),
    ];

    return Scaffold(
      body: AppGradientBackground(
        padding: EdgeInsets.zero,
        child: CustomScrollView(
          // Precache slivers beyond the first fold so widget tests can access
          // the navigation cards without requiring an explicit scroll.
          cacheExtent: precacheExtent,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              sliver: SliverToBoxAdapter(
                child: HomeHeroSection(
                  onExploreBots: () => _openBots(context, BotCategory.online),
                  onOpenDocs: () => _openDocs(context),
                ),
              ),
            ),
            HomeFeatureGrid(features: features),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              sliver: SliverToBoxAdapter(
                child: HomeCallToActionSection(
                  onPressed: () => _openTutorial(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
