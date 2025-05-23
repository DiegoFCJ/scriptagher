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

    // Controlla se il file esiste
    final fileExists = await File(path).exists();
    logger.info(
        'BotDatabase',
        fileExists
            ? "Database file exists."
            : "Database file does NOT exist. Creating a new one...");

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        logger.info('BotDatabase', "Creating database structure...");
        try {
          await _createBotsTable(db);
          logger.info('BotDatabase', "Database structure created.");
        } catch (e) {
          logger.error('BotDatabase', 'Error during database table creation: $e');
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        logger.info('BotDatabase', "Upgrading database from $oldVersion to $newVersion...");
        // Implementa aggiornamenti futuri del database qui
      },
    ).then((db) async {
      // Controlla la struttura dopo l'inizializzazione
      await _checkDatabaseStructure(db);
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
          language TEXT NOT NULL
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
        bot.toMap(),
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
        bot.toMap(),
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
      logger.error('BotDatabase', "Table 'bots' does NOT exist. Something went wrong.");
    } else {
      logger.info('BotDatabase', "Table 'bots' exists and is ready.");
    }
  }
}