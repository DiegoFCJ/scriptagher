class BotPermissions {
  static const String fileSystem = 'fs';
  static const String network = 'network';

  static const Set<String> allowed = {fileSystem, network};

  static String describe(String permission) {
    switch (permission) {
      case fileSystem:
        return 'Accesso al file system locale';
      case network:
        return 'Accesso alla rete esterna';
      default:
        return permission;
    }
  }
}
