import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class LoggerProvider extends ChangeNotifier {
  late Box<List<String>> box = Hive.box('logs');
  List<String> logs = [];

  LoggerProvider() {
    final logList = box.get('logs', defaultValue: <String>[]);
    logs = logList != null ? logList.reversed.toList() : [];
  }

  void addLog(String msg) {
    logs.insert(0, '${DateTime.now().toString().substring(0,19)}: $msg');
    if (logs.length > 100) logs.removeLast();
    box.put('logs', logs.reversed.toList());
    notifyListeners();
  }
}
