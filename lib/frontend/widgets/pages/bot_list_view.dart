import 'package:flutter/material.dart';
import '../../models/bot.dart';
import '../../models/bot_navigation.dart';
import '../../services/bot_get_service.dart';
import '../components/bot_card_component.dart';
import 'bot_detail_view.dart';

class BotList extends StatefulWidget {
  const BotList({Key? key}) : super(key: key);

  @override
  State<BotList> createState() => _BotListState();
}

class _BotListState extends State<BotList>
    with SingleTickerProviderStateMixin {
  final BotGetService _botGetService = BotGetService();

  late final Map<BotCategory, Future<Map<String, List<Bot>>>> _categoryFutures;
  late final TabController _tabController;

  BotCategory _selectedCategory = BotCategory.online;
  bool _argumentsHandled = false;

  @override
  void initState() {
    super.initState();
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
        if (data.isEmpty) {
          return Center(child: Text(_emptyMessageForCategory(category)));
        }

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: data.entries.map((entry) {
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
      },
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
