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

  final BotGetService _botGetService = BotGetService();

  @override
  void initState() {
    super.initState();
    _remoteBots = _botGetService.fetchBots();
    _localBots = _botGetService.fetchLocalBotsFlat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Lista dei Bot')),
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
