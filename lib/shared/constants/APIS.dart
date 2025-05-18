class APIS {
  // ============================================================================
  // GITHUB USER AND PROJECT
  // ============================================================================
  static const String GH_USR = "diegofcj"; // GitHub username
  static const String PROJECT = "scriptagher"; // GitHub project name

  // ============================================================================
  // BASE URLs
  // ============================================================================
  static const String BASE_URL = "https://raw.githubusercontent.com/$GH_USR/$PROJECT/bot-list/bots";
  //https://raw.githubusercontent.com/diegofcj/scriptagher/bot-list/bots/bots.json
  static const String BASE_URL_GH_PAGES = "https://$GH_USR.github.io/$PROJECT/";

  // ============================================================================
  // FILE AND FOLDER NAMES
  // ============================================================================
  static const String BOT_DIR_DATA_REMOTE =
      "data/remote"; // Directory to store data
  static const String BOT_DIR_DATA_LOCAL = "data/local";
  static const String BOT_DIR_UPLOAD = "bots/"; // Directory for bot uploads
  static const String BOT_FILE_CONFIG =
      "Bot.json"; // Bot configuration file name
  static const String ZIP_EXTENSION = ".zip"; // File extension for zip files
  static const String LOCAL_BOTS_FILE = "$BOT_DIR_DATA_LOCAL/local_bots.json";

  // ============================================================================
  // API ENDPOINTS (Bot API)
  // ============================================================================
  static const String BOT_API_BASE_URL =
      "http://localhost:8080"; // Base URL for the bot API
  static const String REQ_MAP_REMOTE = "/api/remote"; // API request map
  static const String REQ_MAP_LOCAL = "/api/local"; // API request map

  // API Endpoints for Bots
  static const String LANG = "/{language}"; // Language parameter
  static const String B_NAME = "/{botName}"; // Bot name parameter
  static const String EXEC = "/execute"; // Execute bot endpoint
  static const String DWNLD = "/download"; // Download bot endpoint
  static const String LOCAL_BOT_LIST = "/local-bots";

  // Combined API Endpoints
  static const String BOT_DWNLD = "$LANG$B_NAME$DWNLD"; // Bot download endpoint
  static const String BOT_EXEC_STREAM =
      "$LANG$B_NAME$EXEC"; // Bot execution stream
  static const String BOT_UPL = "/upload"; // Bot upload endpoint
  static const String BOT_LIST = "/list"; // Bot list endpoint
  static const String BOT_EXEC = "$EXEC$B_NAME"; // Bot execution by name

  // ============================================================================
  // FINAL API ENDPOINTS
  // ============================================================================
  static const String API_BOT_LIST =
      "$BOT_API_BASE_URL$REQ_MAP_REMOTE$BOT_LIST";
  static const String API_BOT_EXEC =
      "$BOT_API_BASE_URL$REQ_MAP_REMOTE$BOT_EXEC_STREAM";
}