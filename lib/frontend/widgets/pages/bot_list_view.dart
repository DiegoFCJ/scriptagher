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

  @override
  void initState() {
    super.initState();
    _remoteBots = BotGetService.fetchBots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lista dei Bot'),
      ),
      body: FutureBuilder<Map<String, List<Bot>>>(
        future: _remoteBots,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Nessun bot trovato.'));
          } else {
            final groupedBots = snapshot.data!;
            return ListView(
              children: [
                ExpansionTile(
                  title: Text('Remote Bots'),
                  children: groupedBots.entries.map((entry) {
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
                                builder: (context) => BotDetailView(bot: bot),
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
          }
        },
      ),
    );
  }
}