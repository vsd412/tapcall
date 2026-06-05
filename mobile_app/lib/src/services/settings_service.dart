import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple persistent settings storage (expandable later).
/// Stores preferred SCREEN width/height (user-entered or auto-detected).
class SettingsService {
  static const _keyWidth = 'ui.screen.width';
  static const _keyHeight = 'ui.screen.height';

  /// Persist the user's intended screen size (not the current Flutter window size).
  Future<void> saveScreenSize(Size size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyWidth, size.width);
    await prefs.setDouble(_keyHeight, size.height);
  }

  /// Returns the stored screen size the user configured, or null if absent.
  Future<Size?> loadScreenSize() async {
    final prefs = await SharedPreferences.getInstance();
    final w = prefs.getDouble(_keyWidth);
    final h = prefs.getDouble(_keyHeight);
    if (w != null && h != null && w > 100 && h > 100) {
      return Size(w, h);
    }
    return null;
  }

  Future<bool> hasCustomScreenSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyWidth) && prefs.containsKey(_keyHeight);
  }

  Future<void> clearScreenSize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyWidth);
    await prefs.remove(_keyHeight);
  }
}
