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
    this.defaultVideoContainer = 'mp4',
    this.defaultAudioFormat = 'm4a',
    this.maxConcurrentDownloads = 2,
    this.autoRetry = true,
    this.updateChannel = 'stable',
    this.downloadSubtitles = false,
    this.embedSubtitles = true,
    this.subtitleLanguages = 'en,id',
    this.sponsorBlockEnabled = false,
    this.sponsorBlockCategories = supportedSponsorBlockCategories,
    this.tiktokSlideshowIncludeAudio = true,
  });

  final AppThemeMode themeMode;
  final String defaultQuality;
  final String defaultVideoContainer;
  final String defaultAudioFormat;
  final int maxConcurrentDownloads;
  final bool autoRetry;
  final String updateChannel;
  final bool downloadSubtitles;
  final bool embedSubtitles;
  final String subtitleLanguages;
  final bool sponsorBlockEnabled;
  final List<String> sponsorBlockCategories;
  final bool tiktokSlideshowIncludeAudio;

  static const supportedQualities = [
    '2160p',
    '1440p',
    '1080p',
    '720p',
    '480p',
    'best',
  ];
  static const supportedVideoContainers = ['mp4', 'mkv'];
  static const supportedAudioFormats = ['m4a', 'mp3', 'opus'];
  static const supportedUpdateChannels = ['stable', 'nightly'];
  static const supportedSponsorBlockCategories = [
    'sponsor',
    'selfpromo',
    'interaction',
  ];

  AppSettings copyWith({
    AppThemeMode? themeMode,
    String? defaultQuality,
    String? defaultVideoContainer,
    String? defaultAudioFormat,
    int? maxConcurrentDownloads,
    bool? autoRetry,
    String? updateChannel,
    bool? downloadSubtitles,
    bool? embedSubtitles,
    String? subtitleLanguages,
    bool? sponsorBlockEnabled,
    List<String>? sponsorBlockCategories,
    bool? tiktokSlideshowIncludeAudio,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      defaultVideoContainer:
          defaultVideoContainer ?? this.defaultVideoContainer,
      defaultAudioFormat: defaultAudioFormat ?? this.defaultAudioFormat,
      maxConcurrentDownloads:
          (maxConcurrentDownloads ?? this.maxConcurrentDownloads).clamp(1, 3),
      autoRetry: autoRetry ?? this.autoRetry,
      updateChannel: updateChannel ?? this.updateChannel,
      downloadSubtitles: downloadSubtitles ?? this.downloadSubtitles,
      embedSubtitles: embedSubtitles ?? this.embedSubtitles,
      subtitleLanguages: subtitleLanguages ?? this.subtitleLanguages,
      sponsorBlockEnabled: sponsorBlockEnabled ?? this.sponsorBlockEnabled,
      sponsorBlockCategories:
          sponsorBlockCategories ?? this.sponsorBlockCategories,
      tiktokSlideshowIncludeAudio:
          tiktokSlideshowIncludeAudio ?? this.tiktokSlideshowIncludeAudio,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'defaultQuality': defaultQuality,
        'defaultVideoContainer': defaultVideoContainer,
        'defaultAudioFormat': defaultAudioFormat,
        'maxConcurrentDownloads': maxConcurrentDownloads,
        'autoRetry': autoRetry,
        'updateChannel': updateChannel,
        'downloadSubtitles': downloadSubtitles,
        'embedSubtitles': embedSubtitles,
        'subtitleLanguages': subtitleLanguages,
        'sponsorBlockEnabled': sponsorBlockEnabled,
        'sponsorBlockCategories': sponsorBlockCategories,
        'tiktokSlideshowIncludeAudio': tiktokSlideshowIncludeAudio,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final quality = json['defaultQuality'] as String?;
    final container = json['defaultVideoContainer'] as String?;
    final audio = json['defaultAudioFormat'] as String?;
    final channel = json['updateChannel'] as String?;
    final concurrency = (json['maxConcurrentDownloads'] as num?)?.toInt() ?? 2;
    final rawCategories = json['sponsorBlockCategories'];
    final categories = rawCategories is List
        ? rawCategories.whereType<String>().toList(growable: false)
        : supportedSponsorBlockCategories;

    return AppSettings(
      themeMode: json.containsKey('themeMode')
          ? AppThemeMode.fromName(json['themeMode'] as String?)
          : AppThemeMode.dark,
      defaultQuality: supportedQualities.contains(quality) ? quality! : '1080p',
      defaultVideoContainer: supportedVideoContainers.contains(container)
          ? container!
          : 'mp4',
      defaultAudioFormat:
          supportedAudioFormats.contains(audio) ? audio! : 'm4a',
      maxConcurrentDownloads: concurrency.clamp(1, 3),
      autoRetry: (json['autoRetry'] as bool?) ?? true,
      updateChannel:
          supportedUpdateChannels.contains(channel) ? channel! : 'stable',
      downloadSubtitles: (json['downloadSubtitles'] as bool?) ?? false,
      embedSubtitles: (json['embedSubtitles'] as bool?) ?? true,
      subtitleLanguages:
          (json['subtitleLanguages'] as String?)?.trim().isNotEmpty == true
              ? (json['subtitleLanguages'] as String).trim()
              : 'en,id',
      sponsorBlockEnabled: (json['sponsorBlockEnabled'] as bool?) ?? false,
      sponsorBlockCategories: categories.isEmpty
          ? supportedSponsorBlockCategories
          : categories,
      tiktokSlideshowIncludeAudio:
          (json['tiktokSlideshowIncludeAudio'] as bool?) ?? true,
    );
  }
}
