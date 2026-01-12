import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  bool _showNsfw = false;
  bool _initialized = false;

  bool get showNsfw => _showNsfw;
  bool get initialized => _initialized;

  SettingsProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _showNsfw = prefs.getBool('showNsfw') ?? false;
    _initialized = true;
    notifyListeners();
  }

  Future<void> toggleNsfw() async {
    _showNsfw = !_showNsfw;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showNsfw', _showNsfw);
    notifyListeners();
  }
}
