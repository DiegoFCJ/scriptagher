import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/bot.dart';
import 'package:scriptagher/shared/custom_logger.dart';

class BotDatabase {
  static final BotDatabase _instance = BotDatabase._internal();
  final CustomLogger logger = CustomLogger();
  Database? _database;

  BotDatabase._internal();

  factory BotDatabase() => _instance;

  /// Ottieni il riferimento al database
  Future<Database> get database async {
    if (_database != null) {
      logger.info('BotDatabase', "Database already initialized.");
      return _database!;
    }

    logger.info('BotDatabase', "Initializing database...");
    _database = await _initDatabase();

    if (_database != null) {
      logger.info('BotDatabase', "Database initialized successfully.");
    } else {
      logger.error('BotDatabase', "Database initialization failed.");
    }

    return _database!;
  }

  /// Inizializza il database con struttura di tabelle e operazioni
  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'bot_database.db');
    logger.info('BotDatabase', "Database path: $path");

    final fileExists = await File(path).exists();
    logger.info(
        'BotDatabase',
        fileExists
            ? "Database file exists."
            : "Database file does NOT exist. Creating a new one...");

    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        logger.info('BotDatabase', "Creating database structure...");
        try {
          await _createBotsTable(db);
          await _createLocalBotsTable(db);
          logger.info('BotDatabase', "Database structure created.");
        } catch (e) {
          logger.error(
              'BotDatabase', 'Error during database table creation: $e');
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        logger.info('BotDatabase',
            "Upgrading database from v$oldVersion to v$newVersion...");
        try {
          if (oldVersion < 2) {
            await _createLocalBotsTable(db);
            logger.info(
                'BotDatabase', "local_bots table created during upgrade.");
          }
          if (oldVersion < 3) {
            await _addSecurityColumns(db);
          }
          // Future upgrade logic here
        } catch (e) {
          logger.error('BotDatabase', 'Error during database upgrade: $e');
        }
      },
    ).then((db) async {
      try {
        // 🛡 Verifica struttura dopo apertura, anche se onCreate/onUpgrade non chiamati
        await _createLocalBotsTable(db); // Sicuro grazie a IF NOT EXISTS
        await _addSecurityColumns(db);
        await _checkDatabaseStructure(db);
      } catch (e) {
        logger.error('BotDatabase', 'Error during structure verification: $e');
      }
      return db;
    });
  }

  /// Crea la tabella bots
  Future<void> _createBotsTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS bots (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          bot_name TEXT NOT NULL,
          description TEXT,
          start_command TEXT,
          source_path TEXT,
          language TEXT NOT NULL,
          permissions TEXT DEFAULT '[]',
          archive_hash TEXT
        );
      ''');
      logger.info('BotDatabase', "Bots table created successfully.");
    } catch (e) {
      logger.error('BotDatabase', "Error creating 'bots' table: $e");
    }
  }

  /// Inserisce un singolo bot o aggiorna se già esistente
  Future<void> insertBot(Bot bot) async {
    final exists = await _botExists(bot.botName, bot.language);

    if (exists) {
      await _updateBot(bot);
    } else {
      final db = await database;
      await db.insert(
        'bots',
        bot.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      logger.info('BotDatabase', 'Bot ${bot.botName} inserted into DB.');
    }
  }

  /// Inserisce una lista di bot (verifica esistenza prima)
  Future<void> insertBots(List<Bot> bots) async {
    for (var bot in bots) {
      await insertBot(bot);
    }
    logger.info('BotDatabase', 'All bots processed.');
  }

  /// Recupera la lista di tutti i bot
  Future<List<Bot>> getAllBots() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query('bots');
      logger.info('BotDatabase', 'Data fetched from database: $maps');
      return List.generate(maps.length, (i) {
        return Bot.fromMap(maps[i]);
      });
    } catch (e) {
      logger.error('BotDatabase', 'Error fetching bots: $e');
      throw Exception('Error during fetching');
    }
  }

  /// Aggiorna il bot esistente
  Future<void> _updateBot(Bot bot) async {
    final db = await database;

    try {
      await db.update(
        'bots',
        bot.toDbMap(),
        where: 'bot_name = ? AND language = ?',
        whereArgs: [bot.botName, bot.language],
      );

      logger.info('BotDatabase', 'Bot ${bot.botName} updated in DB.');
    } catch (e) {
      logger.error('BotDatabase', 'Error during bot update: $e');
    }
  }

  /// Cancella un bot con un ID specifico
  Future<void> deleteBot(int id) async {
    final db = await database;
    await db.delete('bots', where: 'id = ?', whereArgs: [id]);
    logger.info('BotDatabase', 'Bot with id $id deleted.');
  }

  /// Controlla se la tabella 'bots' esiste
  Future<void> checkIfTableExists() async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='bots';");

    if (result.isEmpty) {
      logger.warn('BotDatabase', "Table 'bots' does NOT exist.");
    } else {
      logger.info('BotDatabase', "Table 'bots' exists.");
    }

    final result2 = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='local_bots';");

    if (result2.isEmpty) {
      logger.warn('BotDatabase', "Table 'local_bots' does NOT exist.");
    } else {
      logger.info('BotDatabase', "Table 'local_bots' exists.");
    }
  }

  /// Controlla se il bot è già presente
  Future<bool> _botExists(String botName, String language) async {
    final db = await database;
    final result = await db.query(
      'bots',
      where: 'bot_name = ? AND language = ?',
      whereArgs: [botName, language],
    );

    return result.isNotEmpty;
  }

  /// Controlla la struttura del database
  Future<void> _checkDatabaseStructure(Database db) async {
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='bots';");
    if (tables.isEmpty) {
      logger.error(
          'BotDatabase', "Table 'bots' does NOT exist. Something went wrong.");
    } else {
      logger.info('BotDatabase', "Table 'bots' exists and is ready.");
    }
  }

  Future<void> _addSecurityColumns(Database db) async {
    await _ensureColumn(db, 'bots', 'permissions',
        "ALTER TABLE bots ADD COLUMN permissions TEXT DEFAULT '[]'");
    await _ensureColumn(db, 'bots', 'archive_hash',
        'ALTER TABLE bots ADD COLUMN archive_hash TEXT');
    await _ensureColumn(db, 'local_bots', 'permissions',
        "ALTER TABLE local_bots ADD COLUMN permissions TEXT DEFAULT '[]'");
    await _ensureColumn(db, 'local_bots', 'archive_hash',
        'ALTER TABLE local_bots ADD COLUMN archive_hash TEXT');
  }

  Future<void> _ensureColumn(
      Database db, String table, String column, String alterStatement) async {
    try {
      final result = await db.rawQuery('PRAGMA table_info($table);');
      final exists =
          result.any((row) => (row['name'] as String?) == column);
      if (!exists) {
        await db.execute(alterStatement);
        logger.info('BotDatabase',
            "Column '$column' added to table '$table'.");
      }
    } catch (e) {
      logger.error('BotDatabase',
          "Error ensuring column '$column' on table '$table': $e");
    }
  }

  // --------------------------------------- LOCAL BOTS --------------------------------------- \\
  Future<void> _createLocalBotsTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_bots (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          bot_name TEXT NOT NULL,
          description TEXT,
          start_command TEXT,
          source_path TEXT,
          language TEXT NOT NULL,
          permissions TEXT DEFAULT '[]',
          archive_hash TEXT
        );
      ''');
      logger.info('BotDatabase', "local_bots table created successfully.");
    } catch (e) {
      logger.error('BotDatabase', "Error creating 'local_bots' table: $e");
    }
  }

  // Recupera i bot locali salvati
  Future<List<Bot>> getLocalBots() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('local_bots');
    return List.generate(maps.length, (i) => Bot.fromMap(maps[i]));
  }

  // Controlla se local_bots ha almeno un bot
  Future<bool> hasLocalBots() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM local_bots'),
    );
    return (count ?? 0) > 0;
  }

  // Inserisce o aggiorna lista bot in local_bots
  Future<void> insertLocalBots(List<Bot> bots) async {
    final db = await database;
    final batch = db.batch();
    for (var bot in bots) {
      batch.insert(
        'local_bots',
        bot.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // Cancella tutti i bot locali (se serve)
  Future<void> clearLocalBots() async {
    final db = await database;
    await db.delete('local_bots');
  }

  Future<Bot?> findBotByName(String language, String botName) async {
    final db = await database;

    final result = await db.query(
      'bots',
      where: 'bot_name = ? AND language = ?',
      whereArgs: [botName, language],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return Bot.fromMap(result.first);
    }

    final localResult = await db.query(
      'local_bots',
      where: 'bot_name = ? AND language = ?',
      whereArgs: [botName, language],
      limit: 1,
    );

    if (localResult.isNotEmpty) {
      return Bot.fromMap(localResult.first);
    }

    return null;
  }
}
