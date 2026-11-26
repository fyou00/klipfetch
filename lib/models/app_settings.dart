import 'package:flutter/material.dart';

enum AppThemeMode {
  system,
  dark,
  light;

  ThemeMode toFlutterThemeMode() {
    switch (this) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.light:
        return ThemeMode.light;
    }
  }

  String get label {
    switch (this) {
      case AppThemeMode.system:
        return 'System';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.light:
        return 'Light';
    }
  }

  static AppThemeMode fromName(String? value) {
    switch (value) {
      case 'dark':
        return AppThemeMode.dark;
      case 'light':
        return AppThemeMode.light;
      default:
        return AppThemeMode.system;
    }
  }
}

class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.defaultQuality = '1080p',
    this.defaultAudioFormat = 'm4a',
    this.maxConcurrentDownloads = 2,
    this.autoRetry = true,
    this.updateChannel = 'stable',
  });

  final AppThemeMode themeMode;
  final String defaultQuality;
  final String defaultAudioFormat;
  final int maxConcurrentDownloads;
  final bool autoRetry;
  final String updateChannel;

  static const supportedQualities = ['2160p', '1440p', '1080p', '720p', 'best'];
  static const supportedAudioFormats = ['m4a', 'mp3', 'opus'];
  static const supportedUpdateChannels = ['stable', 'nightly'];

  AppSettings copyWith({
    AppThemeMode? themeMode,
    String? defaultQuality,
    String? defaultAudioFormat,
    int? maxConcurrentDownloads,
    bool? autoRetry,
    String? updateChannel,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      defaultAudioFormat: defaultAudioFormat ?? this.defaultAudioFormat,
      maxConcurrentDownloads:
          (maxConcurrentDownloads ?? this.maxConcurrentDownloads).clamp(1, 3),
      autoRetry: autoRetry ?? this.autoRetry,
      updateChannel: updateChannel ?? this.updateChannel,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'defaultQuality': defaultQuality,
        'defaultAudioFormat': defaultAudioFormat,
        'maxConcurrentDownloads': maxConcurrentDownloads,
        'autoRetry': autoRetry,
        'updateChannel': updateChannel,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final quality = json['defaultQuality'] as String?;
    final audio = json['defaultAudioFormat'] as String?;
    final channel = json['updateChannel'] as String?;
    final concurrency = (json['maxConcurrentDownloads'] as num?)?.toInt() ?? 2;

    return AppSettings(
      themeMode: json.containsKey('themeMode')
          ? AppThemeMode.fromName(json['themeMode'] as String?)
          : AppThemeMode.dark,
      defaultQuality: supportedQualities.contains(quality) ? quality! : '1080p',
      defaultAudioFormat:
          supportedAudioFormats.contains(audio) ? audio! : 'm4a',
      maxConcurrentDownloads: concurrency.clamp(1, 3),
      autoRetry: (json['autoRetry'] as bool?) ?? true,
      updateChannel:
          supportedUpdateChannels.contains(channel) ? channel! : 'stable',
    );
  }
}
