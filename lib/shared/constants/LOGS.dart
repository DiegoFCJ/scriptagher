class LOGS {
  // ============================================================================
  // GENERAL LOGGING MESSAGES
  // ============================================================================
  static const String LOG_DIRECTORY_CREATED = "Log directory already existed.";
  static const String INFO_LOG_DIR_CREATED = "Directory di log creata: ";
  static const String INFO_FILE_CREATED = "File creato: ";
  static const String ERROR_LOG_DIR_CREATION_FAILED =
      "Errore nella creazione della directory di log: ";
  static const String ERROR_FILE_CREATION_FAILED =
      "Errore nella creazione del file: ";

  // Log format pattern
  static const String LOG_FORMAT =
      "| %s | %s | %-10d | %-5s | %-30s | %-3d | %-30s | %s |";

  // Log levels
  static const String DEBUG_LEVEL = "DEBUG";
  static const String INFO_LEVEL = "INFO";
  static const String WARN_LEVEL = "WARN";
  static const String ERROR_LEVEL = "ERROR";
  static const String TEST_LEVEL = "TEST";

  // ============================================================================
  // PATHS AND UTILITIES
  // ============================================================================
  static const String PATH_UTILS = "Utils per il Percorso";

  // ============================================================================
  // APPLICATION TYPES
  // ============================================================================
  static const String MAIN_APP = "MainApp";
  static const String SPRING_APP = "SpringApp";

  // ============================================================================
  // CONTROLLERS
  // ============================================================================
  static const String BOT_CONTROLLER = "BotController";
  static const String HEADER_BAR_CONTROLLER = "HeaderBarController";
  static const String MAIN_VIEW_CONTROLLER = "MainViewController";
  static const String TAB_PANE_CONTROLLER = "TabPaneController";
  static const String LEFT_PANE_CONTROLLER = "LeftPaneController";

  // ============================================================================
  // SERVICES
  // ============================================================================
  static const String MAXIMIZE_SERVICE = "MaximizeService";
  static const String TAB_PANE_SERVICE = "TabPaneService";
  static const String BOT_SERVICE = "BotService";
  static const String EXECUTION_SERVICE = "ExecutionService";
  static const String BOT_MENU_SERVICE = "BotMenuService";
  static const String BOT_DOWNLOAD_SERVICE = "BotDownloadService";

  // ============================================================================
  // OTHER COMPONENTS
  // ============================================================================
  static const String ICON_UPDATE = "IconUpdate";
  static const String STAGE_MANAGER = "StageManager";
  static const String ICN_HOVER_EFFECT = "IconHoverEffect";
  static const String IMAGE_PROCESSING = "ImageProcessing";
  static const String REQUEST_LOG = "RequestLog";

  // ============================================================================
  // FXML FILES
  // ============================================================================
  static const String MAIN = "MainView";
  static const String HEAD = "HeaderBar";
  static const String TABPANE = "TabPane";
  static const String LEFTPANE = "LeftPane";
  static const String MAIN_FXML = "/fxml/$MAIN.fxml";
  static const String PATH_HEAD = "/fxml/$HEAD.fxml";
  static const String PATH_TABPANE = "/fxml/$TABPANE.fxml";
  static const String PATH_LEFTPANE = "/fxml/$LEFTPANE.fxml";

  // ============================================================================
  // ERROR LOG MESSAGES
  // ============================================================================
  static const String ERROR_BOT_EXECUTION = "Error executing bot: %s";
  static const String ERROR_FETCHING_BOTS = "Error fetching bots: %s";
  static const String ERROR_DOWNLOAD = "Failed to download file: %s";
  static const String ERROR_PERMISSIONS =
      "Failed to set write permissions for: %s";
  static const String ERROR_EXECUTING_BOT = "Error executing bot: %s";
  static const String FXML_LOADING_ERROR = "Error loading FXML components: ";
  static const String INITIALIZATION_ERROR =
      "Error during initialization of MainViewController: ";
  static const String DASHBOARD_STRETCH_ERROR =
      "Error in dashboard stretch configuration.";
  static const String FETCH_BOTS_ERROR = "Error occurred while fetching bots: ";
  static const String ICON_LOADING_ERROR = "Error loading icons: ";
  static const String DOWNLOAD_ERROR = "Error during bot download: ";
  static const String ERR_DWNL_BOT = "Error while downloading the bot: ";
  static const String ERR_BTO_DWNLD = "Error during bot download: ";
  static const String IMAGE_PROCESSING_ERROR =
      "Error during image processing: ";
  static const String API_FAILURE = "Failed to fetch bots. HTTP Status: ";
  static const String API_EMPTY_RESPONSE = "API returned no bot data.";
  static const String STAGE_NOT_INITIALIZED = "Stage not initialized!";
  static const String SCENE_NOT_INITIALIZED =
      "La scena non è stata inizializzata";

  // ============================================================================
  // SUCCESS LOG MESSAGES
  // ============================================================================
  static const String BOT_UPLOADED = "Bot uploaded successfully: %s";
  static const String DASHBOARD_STRETCH_CONFIGURED =
      "Dashboard stretch configured successfully.";
  static const String API_SUCCESS = "Received successful response from API.";
  static const String BOTS_MAPPED = "Successfully mapped ";
  static const String DOWNLOAD_SUCCESS = "Bot downloaded successfully: ";
  static const String IMAGE_PROCESSING_SUCCESS =
      "Image processing completed successfully: ";
  static const String DOWNLOAD_COMPLETE = "Download completed: %s";
  static const String EXTRACT_COMPLETE = "Extraction complete: %s";
  static const String BOT_EXECUTION_COMPLETED = "Bot execution completed: %s";
  static const String TUTORIAL_TAB_SETUP = "Tutorial tab setup complete.";
  static const String TOGGLE_TUTORIAL_TAB_SETUP =
      "Toggle tutorial tab setup complete.";
  static const String WINDOW_DRAGGED = "Window dragged";
  static const String ANIMATION_STARTED = "Animation started for component: %s";
  static const String FXML_COMPONENT_LOADED = "FXML component loaded: %s";
  static const String NEW_TAB_CREATED = "Created and selected new tab: ";
  static const String NEW_TAB_ADDED = "New tab added: ";
  static const String STAGE_SET = "Stage set: ";
  static const String STAGE_MINIMIZED = "Stage minimized.";
  static const String SCENE_SET = "Scene impostata: ";
  static const String TUT_START = "Tutorial started";

  // ============================================================================
  // INFO LOG MESSAGES
  // ============================================================================
  static const String DOWNLOAD_START = "Starting download of bot: %s/%s";
  static const String EXTRACT_START = "Extracting ZIP file: %s";
  static const String STARTING_EXECUTION = "Starting execution of bot: %s";
  static const String CONTROLLER_SETUP =
      "Setting up controllers for components.";
  static const String TAB_EXISTS =
      "Tab already exists. Selecting existing tab: ";
  static const String BUTTON_CLICKED = "Button clicked: %s";
  static const String DASHBOARD_TOGGLE = "Toggling dashboard panel visibility";
  static const String TUTORIAL_SHOWN = "Tutorial tab is now visible.";
  static const String TUTORIAL_HIDDEN = "Tutorial tab hidden.";
  static const String SENDING_API_REQUEST = "Sending GET request to API: ";
  static const String TAB_CREATION_ATTEMPT =
      "Trying to create or select tab for: ";
  static const String APPLYING_STYLE = "Applying styles to node: ";
  static const String REMOVING_STYLE = "Removing styles from node: ";
  static const String INIT_TAB_PANE = "Initializing TabPaneController...";
  static const String INIT_MAIN_CONTR = "Initializing MainViewController...";
  static const String WINDOW_FULL_SCREEN =
      "Window is in full screen, set restore icon.";
  static const String WINDOW_NOT_FULL_SCREEN =
      "Window is not in full screen, set maximize icon.";
  static const String WINDOW_MAXIMIZED = "Window is maximized.";
  static const String MAXIMIZE_BUTTON_UPDATED =
      "Maximize button graphic updated.";
  static const String NULL_STAGE_SET = "Attempt to set a null stage.";
  static const String NULL_STAGE_MINIMIZE = "Attempt to minimize a null stage.";
  static const String NULL_STAGE_MAXIMIZE = "Attempt to maximize a null stage.";
  static const String NODE_STYLE = "Current style of ";
  static const String BOT_NOT_FOUND_LOCALLY =
      "Bot not found locally after download: ";
  static const String STAGE_OR_SCENE_NOT_INITIALIZED =
      "Stage or scene is not initialized.";
  static const String DWNLD_SAVED = "Bot downloaded and saved locally: ";
  static const String ICN_HOVER_EFFECT_APPL = "Hover effect applied.";
  static const String ICN_HOVER_EFFECT_REM = "Hover effect removed.";
  static const String MAXIMIZED_STYLE_APPLIED =
      "Maximized styles applied or removed.";
  static const String DWNLD_BTN_DISABLED = "Download button disabled.";
  static const String ICN_UPDTD = "Icon updated to: ";
  static const String DEL_ICN_VIS = "Delete icon visibility set to: ";
  static const String CREATED_DIR = "Created directory for bot: ";
  static const String LEFT_PAN_HIDDEN = "Left panel initially hidden.";
  static const String NULL_SCENE_SET = "Tentativo di impostare una scena nulla";

  static const String serverStart = 'Server avviato con successo:';
  static const String serverError = 'Errore durante l\'avvio del server';
  static const String requestReceived = 'Richiesta ricevuta';


  // ============================================================================
  // Functions for LOG MESSAGES
  // ============================================================================
  static String downloadStart(String language, String botName) =>
      'Starting download of $botName ($language)...';
  static String extractStart(String path) => 'Starting extraction of $path...';
  static String extractComplete(String path) => 'Extraction completed for $path.';
  static String downloadComplete(String botName) => '$botName downloaded successfully.';
  static String errorDownload(String url) => 'Failed to download from $url.';
}