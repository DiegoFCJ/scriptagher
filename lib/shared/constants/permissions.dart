class BotPermissions {
  BotPermissions._();

  static const String filesystem = 'filesystem';
  static const String network = 'network';
  static const String process = 'process';

  static const Set<String> allowed = {
    filesystem,
    network,
    process,
  };

  static const Map<String, String> descriptions = {
    filesystem: 'Accesso al file system locale',
    network: 'Accesso alla rete',
    process: 'Esecuzione di processi locali',
  };
}
