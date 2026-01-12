import 'package:flutter/foundation.dart';
import '../services/logger_service.dart';

class LoggerProvider with ChangeNotifier {
  final LoggerService _logger = LoggerService.instance;

  List<String> get logs => _logger.logs;

  void clearLogs() {
    _logger.clear();
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }
}
