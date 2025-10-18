class LogWriter {
  LogWriter(String todayDate);

  Future<void> write(String logMessage, String component) async {
    // No-op on the web to avoid using dart:io APIs.
  }
}
