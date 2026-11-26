import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';

abstract interface class SettingsStorage {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

class FileSettingsRepository implements SettingsStorage {
  Future<File> _settingsFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/klipfetch_settings.json');
  }

  @override
  Future<AppSettings> load() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) {
        return const AppSettings();
      }
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AppSettings.fromJson(decoded);
      }
    } catch (_) {
      // Corrupt or unreadable settings fall back cleanly to defaults.
    }
    return const AppSettings();
  }

  @override
  Future<void> save(AppSettings settings) async {
    final file = await _settingsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(settings.toJson()));
  }
}

class InMemorySettingsStorage implements SettingsStorage {
  AppSettings _settings = const AppSettings();

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
  }
}
