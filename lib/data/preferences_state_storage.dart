import 'package:shared_preferences/shared_preferences.dart';

import '../domain/state_storage.dart';

/// Persists the app snapshot on the device with shared preferences.
///
/// Health data stays on the device. Production builds should move this to
/// encrypted storage before launch; the interface keeps that change local.
class PreferencesStateStorage implements StateStorage {
  PreferencesStateStorage([this._preferences]);

  static const String snapshotKey = 'pillai.state.v2';

  /// Keys written by the prototype before snapshots existed.
  static const String legacyContextKey = 'pillai.assistant_context.v1';
  static const String legacyDisplayModeKey = 'pillai.display_mode';

  SharedPreferencesAsync? _preferences;

  // Created lazily: the plugin is unavailable in widget tests, and a failure
  // here must surface as a failed read/write the store already tolerates.
  SharedPreferencesAsync get _prefs =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<String?> read() => _prefs.getString(snapshotKey);

  @override
  Future<void> write(String snapshot) =>
      _prefs.setString(snapshotKey, snapshot);

  @override
  Future<void> clear() async {
    await _prefs.remove(snapshotKey);
    await _prefs.remove(legacyContextKey);
    await _prefs.remove(legacyDisplayModeKey);
  }
}
