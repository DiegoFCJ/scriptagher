import 'package:flutter/material.dart';
import 'package:scriptagher/shared/services/telemetry_service.dart';

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
            Text(
              'Privacy e telemetria',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
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
