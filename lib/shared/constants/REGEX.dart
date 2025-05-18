class REGEX {
  // ============================================================================
  // REGEX FOR HANDLING LOG FILES
  // ============================================================================

  // Regex to handle .log files with a date in the name (e.g.,
  // example.log.2024-12-02)
  static const String LOG_WITH_DATE = r'.*\.log\.\d{4}-\d{2}-\d{2}$';

  // Regex to handle .gz files with a date in the name (e.g.,
  // example.log.2024-12-02.gz)
  static const String LOG_GZ_WITH_DATE = r'.*\.log\.\d{4}-\d{2}-\d{2}\.gz$';

  // Regex to handle .gz files with a date and a number in the name (e.g.,
  // example.log.2024-12-02-12345.gz)
  static const String LOG_GZ_WITH_DATE_AND_NUMBER =
      r'.*\.log\.\d{4}-\d{2}-\d{2}-\d+\..gz$';

  // ============================================================================
  // DATE FORMATS
  // ============================================================================

  static const String DATE =
      "yyyy-MM-dd"; // Simple date format (year-month-day)
  static const String DATET_OFORM =
      "yyyy-MM-dd_HH-mm-ss"; // Date format with time
  // (year-month-day_hour-minute-second)
  static const String DATET_FORM =
      "yyyy-MM-dd | HH:mm:ss,SSS"; // Date format with time and milliseconds
  // (year-month-day |
  // hour:minute:second,milliseconds)

  // ============================================================================
  // REGEX FOR EXTRACTION FROM FILE NAMES
  // ============================================================================

  // Regex to extract the date from the file name (e.g., 2024-12-02)
  static const String DATE_COMP = r'\d{4}-\d{2}-\d{2}';

  // Regex to match a file name that contains a date in the format yyyy-MM-dd
  static const String DATE_PATTERN = r'.*' + DATE_COMP + r'.*';

  // ============================================================================
  // REGEX FOR EXTRACTING MACHINE NUMBER
  // ============================================================================

  // Regex to extract the machine number from the file name (e.g., v12345)
  static const String MACHINE_NUMBER_PATTERN = r'v\d{5}';
}