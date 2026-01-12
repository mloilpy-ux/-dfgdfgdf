import 'package:logger/logger.dart';

class LoggerService {
  static final LoggerService instance = LoggerService._init();
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
    ),
  );

  final List<LogEntry> _logs = [];
  
  LoggerService._init();

  void log(String message, {bool isError = false}) {
    final entry = LogEntry(
      message: message,
      timestamp: DateTime.now(),
      isError: isError,
    );
    
    _logs.add(entry);
    
    if (isError) {
      _logger.e(message);
    } else {
      _logger.i(message);
    }
  }

  List<LogEntry> getLogs() => List.unmodifiable(_logs);
  
  void clearLogs() => _logs.clear();
}

class LogEntry {
  final String message;
  final DateTime timestamp;
  final bool isError;

  LogEntry({
    required this.message,
    required this.timestamp,
    this.isError = false,
  });
}
