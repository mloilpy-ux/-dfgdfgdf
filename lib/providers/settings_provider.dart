import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _showNsfw = true;
  bool _gifOnly = false;
  bool get showNsfw => _showNsfw;
  bool get gifOnly => _gifOnly;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _showNsfw = prefs.getBool('showNsfw') ?? true;
    _gifOnly = prefs.getBool('gifOnly') ?? false;
    notifyListeners();
  }

  void toggleNsfw() {
    _showNsfw = !_showNsfw;
    SharedPreferences.getInstance().then((prefs) => prefs.setBool('showNsfw', _showNsfw));
    notifyListeners();
  }

  void toggleGif() {
    _gifOnly = !_gifOnly;
    SharedPreferences.getInstance().then((prefs) => prefs.setBool('gifOnly', _gifOnly));
    notifyListeners();
  }
}
