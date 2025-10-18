import 'package:flutter/material.dart';

class MarketplacePage extends StatelessWidget {
  const MarketplacePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marketplace in arrivo',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Stiamo preparando uno spazio dedicato dove scoprire, installare e gestire '
                    'nuovi bot per Scriptagher. Torna presto per vedere le ultime novità!',
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 0,
                    color: Colors.blueGrey.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.lightbulb_outline, color: Colors.blueGrey),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Hai idee o suggerimenti? Condividili con il team per aiutare a '
                              'modellare il marketplace ideale per la community.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
