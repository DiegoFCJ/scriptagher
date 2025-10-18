import 'package:flutter/material.dart';
import 'package:scriptagher/shared/services/telemetry_service.dart';

import '../components/gradient_hero_section.dart';

class SettingsPage extends StatelessWidget {
  final TelemetryService telemetryService;

  const SettingsPage({super.key, required this.telemetryService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1100;
        final isTablet = constraints.maxWidth >= 720 && constraints.maxWidth < 1100;
        final horizontalPadding = isDesktop
            ? 120.0
            : isTablet
                ? 72.0
                : 24.0;

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  isDesktop ? 56 : 24,
                  horizontalPadding,
                  24,
                ),
                sliver: SliverToBoxAdapter(
                  child: GradientHeroSection(
                    leading: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.16),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    eyebrow: 'Preferenze',
                    title: 'Controlla privacy e telemetria',
                    subtitle:
                        'Gestisci il consenso all’invio di metriche anonime e personalizza l’esperienza di Scriptagher.',
                    icon: Icons.tune_rounded,
                    primaryAction: FilledButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/tutorial'),
                      icon: const Icon(Icons.help_rounded),
                      label: const Text('Scopri come funzionano i dati'),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 12,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: ValueListenableBuilder<bool>(
                            valueListenable: telemetryService.telemetryEnabled,
                            builder: (context, enabled, _) {
                              return SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Abilita telemetria anonima',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  'Consenti l\'invio di metadati diagnostici anonimizzati per aiutarci a migliorare l\'applicazione.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                value: enabled,
                                onChanged: (value) async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    await telemetryService.setTelemetryEnabled(value);
                                    final message = value
                                        ? 'Telemetria attivata. Grazie per il supporto!'
                                        : 'Telemetria disattivata.';
                                    messenger.showSnackBar(
                                      SnackBar(content: Text(message)),
                                    );
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Si è verificato un errore durante il salvataggio delle preferenze.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'I dati inviati includono esclusivamente informazioni aggregate (come lingua del bot, tipo di errore e hash anonimi), senza alcun identificativo personale.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 48),
                    ],
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
