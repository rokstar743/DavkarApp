import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_settings.dart';

class SettingsService {
  static const String _key = 'user_settings';

  Future<UserSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return UserSettings.empty;
    try {
      return UserSettings.fromJson(jsonDecode(json));
    } catch (_) {
      return UserSettings.empty;
    }
  }

  Future<void> save(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}