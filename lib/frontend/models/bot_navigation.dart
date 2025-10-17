enum BotCategory { downloaded, online, local }

class BotListArguments {
  final BotCategory initialCategory;

  const BotListArguments({required this.initialCategory});
}
