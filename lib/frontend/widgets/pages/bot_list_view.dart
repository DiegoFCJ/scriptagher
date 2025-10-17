import 'package:flutter/material.dart';

import '../../models/bot.dart';
import '../../services/bot_get_service.dart';
import '../components/bot_card_component.dart';
import '../components/search_component.dart';
import 'bot_detail_view.dart';

class BotList extends StatefulWidget {
  @override
  State<BotList> createState() => _BotListState();
}

class _BotListState extends State<BotList> {
  final BotGetService _botGetService = BotGetService();
  final TextEditingController _searchController = TextEditingController();

  late Future<void> _loadFuture;

  Map<String, List<Bot>> _remoteBots = {};
  List<Bot> _localBots = [];

  Map<String, List<Bot>> _filteredRemoteBots = {};
  List<Bot> _filteredLocalBots = [];

  List<String> _availableLanguages = [];
  List<String> _availableTags = [];
  List<String> _availableAuthors = [];
  List<String> _availableVersions = [];

  BotFilters _filters = const BotFilters();

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadBots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBots() async {
    final remote = await _botGetService.fetchBots();
    final local = await _botGetService.fetchLocalBotsFlat();

    if (!mounted) return;

    final allBots = [
      ...remote.values.expand((bots) => bots),
      ...local,
    ];

    final languages = _sortedUnique(allBots.map((bot) => bot.language));
    final tags = _sortedUnique(allBots.expand((bot) => bot.tags));
    final authors = _sortedUnique(
        allBots.map((bot) => bot.author).where((author) => author.isNotEmpty));
    final versions = _sortedUnique(allBots
        .map((bot) => bot.version)
        .where((version) => version.isNotEmpty));

    final sanitizedFilters = _filters.copyWith(
      language: _sanitizeSelection(_filters.language, languages),
      tag: _sanitizeSelection(_filters.tag, tags),
      author: _sanitizeSelection(_filters.author, authors),
      version: _sanitizeSelection(_filters.version, versions),
    );

    setState(() {
      _remoteBots = remote;
      _localBots = local;
      _availableLanguages = languages;
      _availableTags = tags;
      _availableAuthors = authors;
      _availableVersions = versions;
      _filters = sanitizedFilters;
    });

    _applyFilters();
  }

  List<String> _sortedUnique(Iterable<String> values) {
    final Map<String, String> normalized = {};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final lower = trimmed.toLowerCase();
      normalized.putIfAbsent(lower, () => trimmed);
    }
    final list = normalized.values.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  String? _sanitizeSelection(String? current, List<String> options) {
    if (current == null) return null;
    for (final option in options) {
      if (option.toLowerCase() == current.toLowerCase()) {
        return option;
      }
    }
    return null;
  }

  void _applyFilters() {
    if (!mounted) return;
    final updatedFilters =
        _filters.copyWith(query: _searchController.text.trim());

    setState(() {
      _filters = updatedFilters;
      _filteredRemoteBots =
          _botGetService.filterGroupedBots(_remoteBots, updatedFilters);
      _filteredLocalBots =
          _botGetService.filterBots(_localBots, updatedFilters);
    });
  }

  Future<void> _refreshBots() {
    final future = _loadBots();
    setState(() {
      _loadFuture = future;
    });
    return future;
  }

  void _resetAllFilters() {
    _searchController.clear();
    _filters = const BotFilters();
    _applyFilters();
  }

  void _onSearchCleared() {
    _applyFilters();
  }

  void _updateLanguageFilter(String? language) {
    _filters = _filters.copyWith(language: language);
    _applyFilters();
  }

  void _updateTagFilter(String? tag) {
    _filters = _filters.copyWith(tag: tag);
    _applyFilters();
  }

  void _updateAuthorFilter(String? author) {
    _filters = _filters.copyWith(author: author);
    _applyFilters();
  }

  void _updateVersionFilter(String? version) {
    _filters = _filters.copyWith(version: version);
    _applyFilters();
  }

  int _countRemoteFilteredBots() {
    return _filteredRemoteBots.values
        .fold(0, (total, bots) => total + bots.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lista dei Bot')),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Errore durante il caricamento dei bot: '
                    '${snapshot.error}'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshBots,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SearchView(
                        controller: _searchController,
                        onChanged: (_) => _applyFilters(),
                        onClear: _onSearchCleared,
                        hintText: 'Cerca per nome, descrizione, tag...',
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          _buildFilterDropdown(
                            label: 'Lingua',
                            value: _filters.language,
                            options: _availableLanguages,
                            onChanged: _updateLanguageFilter,
                          ),
                          _buildFilterDropdown(
                            label: 'Tag',
                            value: _filters.tag,
                            options: _availableTags,
                            onChanged: _updateTagFilter,
                          ),
                          _buildFilterDropdown(
                            label: 'Autore',
                            value: _filters.author,
                            options: _availableAuthors,
                            onChanged: _updateAuthorFilter,
                          ),
                          _buildFilterDropdown(
                            label: 'Versione',
                            value: _filters.version,
                            options: _availableVersions,
                            onChanged: _updateVersionFilter,
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _resetAllFilters,
                          icon: const Icon(Icons.filter_alt_off),
                          label: const Text('Reset filtri'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLocalSection(),
                      const SizedBox(height: 24),
                      _buildRemoteSection(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
      child: DropdownButtonFormField<String?>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Tutte')),
          ...options
              .map((option) => DropdownMenuItem<String?>(
                    value: option,
                    child: Text(option),
                  ))
              .toList(),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildLocalSection() {
    if (_filteredLocalBots.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Local Bots (0)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          _buildEmptyTile(
              'Nessun bot locale trovato con i filtri selezionati.'),
        ],
      );
    }

    return ExpansionTile(
      title: Text('Local Bots (${_filteredLocalBots.length})'),
      children: _filteredLocalBots.map(_buildBotTile).toList(),
    );
  }

  Widget _buildRemoteSection() {
    if (_filteredRemoteBots.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remote Bots (0)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          _buildEmptyTile(
              'Nessun bot remoto trovato con i filtri selezionati.'),
        ],
      );
    }

    return ExpansionTile(
      title: Text('Remote Bots (${_countRemoteFilteredBots()})'),
      children: _filteredRemoteBots.entries.map((entry) {
        final language = entry.key;
        final bots = entry.value;

        return ExpansionTile(
          title: Text('$language (${bots.length})'),
          children: bots.map(_buildBotTile).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildBotTile(Bot bot) {
    return BotCard(
      bot: bot,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BotDetailView(bot: bot),
          ),
        );
      },
    );
  }

  Widget _buildEmptyTile(String message) {
    return ListTile(
      title: Text(message),
      dense: true,
    );
  }
}
