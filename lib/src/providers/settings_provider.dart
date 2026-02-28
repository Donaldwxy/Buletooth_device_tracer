
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  // Private properties
  late SharedPreferences _prefs;
  bool _use6DigitPrecision = false;
  bool _exitOnInactive = false;
  bool _recordOnForeground = true;
  Locale _locale = const Locale('en');

  // Public getters
  bool get use6DigitPrecision => _use6DigitPrecision;
  bool get exitOnInactive => _exitOnInactive;
  bool get recordOnForeground => _recordOnForeground;
  Locale get locale => _locale;

  // Methods to toggle settings
  void togglePrecision() {
    _use6DigitPrecision = !_use6DigitPrecision;
    _saveSettings();
    notifyListeners();
  }

  void toggleExitOnInactive() {
    _exitOnInactive = !_exitOnInactive;
    _saveSettings();
    notifyListeners();
  }

  void toggleRecordOnForeground() {
    _recordOnForeground = !_recordOnForeground;
    _saveSettings();
    notifyListeners();
  }

  void toggleLocale() {
    _locale = _locale.languageCode == 'en' ? const Locale('zh') : const Locale('en');
    _saveSettings();
    notifyListeners();
  }

  // Persistence methods
  Future<void> loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _use6DigitPrecision = _prefs.getBool('use6DigitPrecision') ?? false;
    _exitOnInactive = _prefs.getBool('exitOnInactive') ?? false;
    _recordOnForeground = _prefs.getBool('recordOnForeground') ?? true;
    final languageCode = _prefs.getString('languageCode') ?? 'en';
    _locale = Locale(languageCode);
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    await _prefs.setBool('use6DigitPrecision', _use6DigitPrecision);
    await _prefs.setBool('exitOnInactive', _exitOnInactive);
    await _prefs.setBool('recordOnForeground', _recordOnForeground);
    await _prefs.setString('languageCode', _locale.languageCode);
  }
}
