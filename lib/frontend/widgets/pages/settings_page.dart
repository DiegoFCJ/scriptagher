import 'package:flutter/material.dart';
import 'package:scriptagher/shared/services/telemetry_service.dart';
import 'package:scriptagher/shared/theme/theme_controller.dart';

import '../components/app_gradient_background.dart';

class SettingsPage extends StatelessWidget {
  final TelemetryService telemetryService;

  const SettingsPage({super.key, required this.telemetryService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
      ),
      body: AppGradientBackground(
        applyTopSafeArea: false,
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(title: 'Aspetto e accessibilità'),
              const SizedBox(height: 12),
              const _ThemeSelector(),
              const SizedBox(height: 32),
              _SectionTitle(title: 'Privacy e telemetria'),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.secondaryContainer,
                      colorScheme.secondaryContainer.withOpacity(0.75),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.secondary.withOpacity(0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: telemetryService.telemetryEnabled,
                    builder: (context, enabled, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Abilita telemetria anonima',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
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
                        activeColor: colorScheme.secondary,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'I dati inviati includono esclusivamente informazioni aggregate (come lingua del bot, tipo di errore e hash '
                'anonimi), senza alcun identificativo personale.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();

  String _labelFor(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return 'Chiaro';
      case AppTheme.dark:
        return 'Scuro';
      case AppTheme.highContrast:
        return 'Alto contrasto';
    }
  }

  IconData _iconFor(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return Icons.light_mode_rounded;
      case AppTheme.dark:
        return Icons.dark_mode_rounded;
      case AppTheme.highContrast:
        return Icons.invert_colors_on_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController();

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final currentTheme = themeController.currentTheme;
        final colorScheme = Theme.of(context).colorScheme;
        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tema applicazione',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: themeController.availableThemes.map((theme) {
                    final selected = theme == currentTheme;
                    final labelStyle =
                        Theme.of(context).textTheme.labelLarge ??
                            const TextStyle();
                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _iconFor(theme),
                            size: 18,
                            color: selected
                                ? colorScheme.onPrimary
                                : colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _labelFor(theme),
                            style: labelStyle.copyWith(
                              color: selected
                                  ? colorScheme.onPrimary
                                  : colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      selected: selected,
                      onSelected: (isSelected) {
                        if (!isSelected || theme == currentTheme) {
                          return;
                        }
                        themeController.setTheme(theme);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Tema impostato su ${_labelFor(theme)}',
                            ),
                          ),
                        );
                      },
                      selectedColor: colorScheme.primary,
                      checkmarkColor: colorScheme.onPrimary,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Scegli tra modalità chiara, scura o ad alto contrasto per migliorare la leggibilità.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .headlineMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}
