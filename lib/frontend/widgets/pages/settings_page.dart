import 'package:flutter/material.dart';
import 'package:scriptagher/shared/services/telemetry_service.dart';
import 'package:scriptagher/shared/theme/theme_controller.dart';

class SettingsPage extends StatelessWidget {
  final TelemetryService telemetryService;

  const SettingsPage({super.key, required this.telemetryService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            _SectionTitle(title: 'Aspetto e accessibilità'),
            const SizedBox(height: 12),
            const _ThemeSelector(),
            const SizedBox(height: 32),
            _SectionTitle(title: 'Privacy e telemetria'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ValueListenableBuilder<bool>(
                  valueListenable: telemetryService.telemetryEnabled,
                  builder: (context, enabled, _) {
                    return SwitchListTile.adaptive(
                      title: const Text('Abilita telemetria anonima'),
                      subtitle: const Text(
                        'Consenti l\'invio di metadati diagnostici anonimizzati per aiutarci a migliorare l\'applicazione.',
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
            const SizedBox(height: 16),
            const Text(
              'I dati inviati includono esclusivamente informazioni aggregate (come lingua del bot, tipo di errore e hash anonimi), senza alcun identificativo personale.',
            ),
          ],
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
        return Icons.light_mode;
      case AppTheme.dark:
        return Icons.dark_mode;
      case AppTheme.highContrast:
        return Icons.invert_colors;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController();

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final currentTheme = themeController.currentTheme;
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    final labelStyle = Theme.of(context).textTheme.labelLarge;
                    final colorScheme = Theme.of(context).colorScheme;
                    return ChoiceChip(
                      showCheckmark: false,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _iconFor(theme),
                            size: 18,
                            color: selected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _labelFor(theme),
                            style: labelStyle?.copyWith(
                              color: selected
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurface,
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
                      backgroundColor: colorScheme.surfaceVariant,
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
