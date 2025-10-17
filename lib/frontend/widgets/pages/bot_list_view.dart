import 'package:flutter/material.dart';
import '../../models/bot.dart';
import '../../models/bot_navigation.dart';
import '../../services/bot_get_service.dart';
import '../components/bot_card_component.dart';
import '../components/search_component.dart';
import 'bot_detail_view.dart';

class BotList extends StatefulWidget {
  final BotGetService? botGetService;

  const BotList({Key? key, this.botGetService}) : super(key: key);

  @override
  State<BotList> createState() => _BotListState();
}

class _BotListState extends State<BotList> with SingleTickerProviderStateMixin {
  late final BotGetService _botGetService;

  late final Map<BotCategory, Future<Map<String, List<Bot>>>> _categoryFutures;
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  BotCategory _selectedCategory = BotCategory.online;
  bool _argumentsHandled = false;

  String _searchQuery = '';
  String? _languageFilter;
  String? _authorFilter;
  String? _versionFilter;
  final Set<String> _selectedTags = <String>{};

  @override
  void initState() {
    super.initState();
    _botGetService = widget.botGetService ?? BotGetService();
    _categoryFutures = {
      BotCategory.downloaded: _botGetService.fetchDownloadedBots(),
      BotCategory.online: _botGetService.fetchOnlineBots(),
      BotCategory.local: _botGetService.fetchLocalBots(),
    };
    _tabController = TabController(
      length: BotCategory.values.length,
      vsync: this,
      initialIndex: _selectedCategory.index,
    );
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedCategory = BotCategory.values[_tabController.index];
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentsHandled) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is BotListArguments) {
      setState(() {
        _selectedCategory = args.initialCategory;
        _tabController.index = _selectedCategory.index;
      });
    }
    _argumentsHandled = true;
  }

  String _labelForCategory(BotCategory category) {
    switch (category) {
      case BotCategory.downloaded:
        return 'Scaricati';
      case BotCategory.online:
        return 'Online';
      case BotCategory.local:
        return 'Locali';
    }
  }

  String _emptyMessageForCategory(BotCategory category) {
    switch (category) {
      case BotCategory.downloaded:
        return 'Nessun bot scaricato trovato.';
      case BotCategory.online:
        return 'Nessun bot disponibile online al momento.';
      case BotCategory.local:
        return 'Nessun bot locale trovato.';
    }
  }

  bool get _hasActiveFilters {
    return _searchQuery.trim().isNotEmpty ||
        (_languageFilter != null && _languageFilter!.trim().isNotEmpty) ||
        (_authorFilter != null && _authorFilter!.trim().isNotEmpty) ||
        (_versionFilter != null && _versionFilter!.trim().isNotEmpty) ||
        _selectedTags.isNotEmpty;
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _languageFilter = null;
      _authorFilter = null;
      _versionFilter = null;
      _selectedTags.clear();
      _searchController.clear();
    });
  }

  Set<String> _collectTags(Map<String, List<Bot>> data) {
    return data.values.expand((bots) => bots).expand((bot) => bot.tags).toSet();
  }

  Set<String> _collectAuthors(Map<String, List<Bot>> data) {
    return data.values
        .expand((bots) => bots)
        .map((bot) => bot.author)
        .whereType<String>()
        .toSet();
  }

  Set<String> _collectVersions(Map<String, List<Bot>> data) {
    return data.values
        .expand((bots) => bots)
        .map((bot) => bot.version)
        .whereType<String>()
        .toSet();
  }

  Widget _buildCategoryView(BotCategory category) {
    return FutureBuilder<Map<String, List<Bot>>>(
      future: _categoryFutures[category],
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Errore nel caricamento: ${snapshot.error}'),
          );
        }

        final data = snapshot.data ?? {};
        final languages = data.keys.toSet();
        final authors = _collectAuthors(data);
        final versions = _collectVersions(data);
        final tags = _collectTags(data);

        final currentLanguage =
            (_languageFilter != null && languages.contains(_languageFilter))
                ? _languageFilter
                : null;
        final currentAuthor =
            (_authorFilter != null && authors.contains(_authorFilter))
                ? _authorFilter
                : null;
        final currentVersion =
            (_versionFilter != null && versions.contains(_versionFilter))
                ? _versionFilter
                : null;
        final selectedTags =
            _selectedTags.where((tag) => tags.contains(tag)).toSet();

        final filter = BotFilter(
          query: _searchQuery,
          language: currentLanguage,
          author: currentAuthor,
          version: currentVersion,
          tags: selectedTags,
        );
        final filteredData = _botGetService.filterGroupedBots(
          data,
          filter.isEmpty ? null : filter,
        );

        final hasOriginalBots = data.values.any((bots) => bots.isNotEmpty);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SearchView(
                controller: _searchController,
                hintText: 'Cerca per nome, descrizione, tag o autore',
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                onClear: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterControls(
                    languages: languages,
                    authors: authors,
                    versions: versions,
                    tags: tags,
                    currentLanguage: currentLanguage,
                    currentAuthor: currentAuthor,
                    currentVersion: currentVersion,
                  ),
                  if (_hasActiveFilters)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.filter_alt_off),
                        label: const Text('Reset filtri'),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildFilteredList(
                category,
                filteredData,
                hasOriginalBots,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilteredList(
    BotCategory category,
    Map<String, List<Bot>> filteredData,
    bool hasOriginalBots,
  ) {
    if (!hasOriginalBots) {
      return Center(child: Text(_emptyMessageForCategory(category)));
    }

    if (filteredData.isEmpty) {
      return const Center(
        child: Text('Nessun bot corrisponde ai filtri correnti.'),
      );
    }

    final entries = filteredData.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: entries.map((entry) {
        final language = entry.key;
        final bots = entry.value;
        return ExpansionTile(
          title: Text(language),
          children: bots
              .map(
                (bot) => BotCard(
                  bot: bot,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BotDetailView(bot: bot),
                      ),
                    );
                  },
                ),
              )
              .toList(),
        );
      }).toList(),
    );
  }

  Widget _buildFilterControls({
    required Set<String> languages,
    required Set<String> authors,
    required Set<String> versions,
    required Set<String> tags,
    required String? currentLanguage,
    required String? currentAuthor,
    required String? currentVersion,
  }) {
    final theme = Theme.of(context);
    final widgets = <Widget>[
      _buildDropdownFilter(
        label: 'Lingua',
        options: languages,
        currentValue: currentLanguage,
        onChanged: (value) {
          setState(() {
            _languageFilter = value;
          });
        },
      ),
    ];

    if (authors.isNotEmpty) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        _buildDropdownFilter(
          label: 'Autore',
          options: authors,
          currentValue: currentAuthor,
          onChanged: (value) {
            setState(() {
              _authorFilter = value;
            });
          },
        ),
      );
    }

    if (versions.isNotEmpty) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        _buildDropdownFilter(
          label: 'Versione',
          options: versions,
          currentValue: currentVersion,
          onChanged: (value) {
            setState(() {
              _versionFilter = value;
            });
          },
        ),
      );
    }

    if (tags.isNotEmpty) {
      final sortedTags = tags.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      widgets.add(const SizedBox(height: 16));
      widgets.add(Text('Tag', style: theme.textTheme.titleSmall));
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: sortedTags.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return FilterChip(
              label: Text(tag),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTags.add(tag);
                  } else {
                    _selectedTags.remove(tag);
                  }
                });
              },
            );
          }).toList(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required Set<String> options,
    required String? currentValue,
    required ValueChanged<String?> onChanged,
  }) {
    final sortedOptions = options.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final items = [
      const DropdownMenuItem<String?>(value: null, child: Text('Tutte')),
      ...sortedOptions.map(
        (option) =>
            DropdownMenuItem<String?>(value: option, child: Text(option)),
      ),
    ];

    return DropdownButtonFormField<String?>(
      value: currentValue,
      items: items,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Bot'),
        bottom: TabBar(
          controller: _tabController,
          tabs: BotCategory.values
              .map((category) => Tab(text: _labelForCategory(category)))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children:
            BotCategory.values.map(_buildCategoryView).toList(growable: false),
      ),
    );
  }
}
