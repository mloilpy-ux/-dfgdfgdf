import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class LoggerProvider extends ChangeNotifier {
  late Box<List<String>> _box = Hive.box('logs');
  List<String> logs = [];

  LoggerProvider() {
    logs = _box.get('logs', defaultValue: <String>[]).reversed.toList();
  }

  void addLog(String msg) {
    logs.insert(0, '${DateTime.now()}: $msg');
    if (logs.length > 100) logs = logs.sublist(0, 100);
    _box.put('logs', logs.reversed.toList());
    notifyListeners();
  }
}
