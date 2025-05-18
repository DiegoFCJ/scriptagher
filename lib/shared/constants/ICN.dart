class ICN {
  // ============================================================================
  // BASE PATHS
  // ============================================================================
  static const String RES = "src/main/resources"; // Base resources directory
  static const String ICNS = "/icons/"; // Icons directory
  static const String CLOUD = "/cloud/"; // Cloud-related icons directory

  // ============================================================================
  // ICONS
  // ============================================================================
  // General Icons
  static const String CIRCLE = "icons8-circle-32.png";
  static const String BIN = "icons8-elimina-50.png";
  static const String GRABBING = "icons8-grabbing-tool-48.png";
  static const String GRABBED = "icons8-grabbed-tool-48.png";

  // Cloud-related Icons
  static const String CLOUD_MARK = "icons8-cloud-marcato-50.png";
  static const String CLOUD_LOAD = "icons8-caricamento-dal-cloud-50.gif";
  static const String CLOUD_DWNLD = "icons8-scarica-da-cloud-50.png";
  static const String CLOUD_ERR = "icons8-nuvola-errore-50.png";
  static const String CLOUD_RESTORE = "icons8-ripristino-32.png";

  // ============================================================================
  // ICON PATHS
  // ============================================================================
  // General Icon Paths
  static const String PATH_BIN = "$RES$ICNS$BIN";
  static const String PATH_GRABBING = "$RES$ICNS$GRABBING";
  static const String PATH_GRABBED = "$RES$ICNS$GRABBED";

  // Cloud-related Icon Paths
  static const String PATH_CLOUD_MARK = "$RES$ICNS$CLOUD$CLOUD_MARK";
  static const String PATH_CLOUD_LOAD = "$RES$ICNS$CLOUD$CLOUD_LOAD";
  static const String PATH_CLOUD_DWNLD = "$RES$ICNS$CLOUD$CLOUD_DWNLD";
  static const String PATH_CLOUD_ERROR = "$RES$ICNS$CLOUD$CLOUD_ERR";
}