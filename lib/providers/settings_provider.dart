import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class SettingsProvider with ChangeNotifier {
  static const String _boxName = 'settings';
  late Box _box;

  bool _showNsfw = false;
  bool _initialized = false;

  bool get showNsfw => _showNsfw;
  bool get initialized => _initialized;

  SettingsProvider() {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox(_boxName);
    _showNsfw = _box.get('showNsfw', defaultValue: false);
    _initialized = true;
    notifyListeners();
  }

  Future<void> toggleNsfw() async {
    _showNsfw = !_showNsfw;
    await _box.put('showNsfw', _showNsfw);
    notifyListeners();
  }
}
