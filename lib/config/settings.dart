class Settings {
  static String _logString = "";

  static String get getLog => _logString;

  static void log(String message) {
    _logString += "$message\n";
  }
}