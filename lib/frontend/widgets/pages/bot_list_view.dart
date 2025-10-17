import 'package:flutter/material.dart';
import '../../models/bot.dart';
import '../../services/bot_get_service.dart';
import '../components/bot_card_component.dart';
import 'bot_detail_view.dart';

class BotList extends StatefulWidget {
  @override
  _BotListState createState() => _BotListState();
}

class _BotListState extends State<BotList> {
  late Future<Map<String, List<Bot>>> _remoteBots;
  late Future<List<Bot>> _localBots;
  bool _isRefreshing = false;

  final BotGetService _botGetService = BotGetService();

  @override
  void initState() {
    super.initState();
    _remoteBots = _botGetService.fetchBots();
    _localBots = _botGetService.fetchLocalBotsFlat();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    final remoteFuture = _botGetService.fetchBots(forceRefresh: forceRefresh);
    final localFuture = _botGetService.fetchLocalBotsFlat();

    setState(() {
      _remoteBots = remoteFuture;
      _localBots = localFuture;
      _isRefreshing = forceRefresh;
    });

    if (forceRefresh) {
      try {
        await Future.wait([remoteFuture, localFuture]);
      } finally {
        if (mounted) {
          setState(() {
            _isRefreshing = false;
          });
        }
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadData(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lista dei Bot'),
        actions: [
          if (_isRefreshing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.refresh),
              tooltip: 'Aggiorna',
              onPressed: _handleRefresh,
            ),
        ],
      ),
      body: FutureBuilder<Map<String, List<Bot>>>(
        future: _remoteBots,
        builder: (context, remoteSnapshot) {
          return FutureBuilder<List<Bot>>(
            future: _localBots,
            builder: (context, localSnapshot) {
              if (remoteSnapshot.connectionState == ConnectionState.waiting ||
                  localSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (remoteSnapshot.hasError) {
                return Center(
                    child: Text('Errore remoto: ${remoteSnapshot.error}'));
              }

              if (localSnapshot.hasError) {
                return Center(
                    child: Text('Errore locale: ${localSnapshot.error}'));
              }

              final remoteData = remoteSnapshot.data ?? {};
              final localData = localSnapshot.data ?? [];

              return ListView(
                children: [
                  ExpansionTile(
                    title: Text('Local Bots'),
                    children: localData.map((bot) {
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
                    }).toList(),
                  ),
                  ExpansionTile(
                    title: Text('Remote Bots'),
                    children: remoteData.entries.map((entry) {
                      final language = entry.key;
                      final bots = entry.value;

                      return ExpansionTile(
                        title: Text(language),
                        children: bots.map((bot) {
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
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
