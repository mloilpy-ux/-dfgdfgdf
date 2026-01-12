class LoggerService {
  static final LoggerService instance = LoggerService._init();
  final List<String> _logs = [];

  LoggerService._init();

  void log(String message, {bool isError = false}) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message';
    _logs.add(logMessage);
    
    if (isError) {
      print('🔴 $logMessage');
    } else {
      print('🟢 $logMessage');
    }
  }

  List<String> get logs => List.unmodifiable(_logs);

  void clear() {
    _logs.clear();
  }
}
