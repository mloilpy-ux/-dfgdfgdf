import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  bool _showNsfw = false;
  bool _initialized = false;

  bool get showNsfw => _showNsfw;
  bool get initialized => _initialized;

  SettingsProvider() {
    // БАГ ИСПРАВЛЕН: асинхронная инициализация через microtask
    // вместо прямого вызова, чтобы конструктор не был async
    Future.microtask(() => _init());
  }

  Future<void> init() async {
    await _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _showNsfw = prefs.getBool('showNsfw') ?? false;
    _initialized = true;
    notifyListeners();
  }
