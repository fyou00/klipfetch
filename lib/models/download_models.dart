import 'media_probe.dart';

class UnsupportedPlatformException implements Exception {
  const UnsupportedPlatformException(this.url);

  final String url;

  @override
  String toString() =>
      'UnsupportedPlatformException: Only TikTok, Instagram, and YouTube URLs are supported (got: $url)';
}

class DownloadCancelledException implements Exception {
  const DownloadCancelledException(this.taskId);

  final String taskId;

  @override
  String toString() => 'DownloadCancelledException: Task $taskId was cancelled';
}

class DownloadRequest {
  const DownloadRequest({
    required this.taskId,
    required this.url,
    required this.outputDir,
    this.outputTemplate,
    this.formatSelector,
    this.quality,
    this.audioOnly = false,
    this.audioFormat,
    this.cookiesPath,
    this.mergeOutputFormat,
    this.downloadSubtitles = false,
    this.embedSubtitles = true,
    this.subtitleLangs,
    this.sponsorBlockCategories = const [],
    this.allowPlaylist = false,
    this.playlistItems,
    this.extraArgs = const [],
  });

  final String taskId;
  final String url;
  final String outputDir;
  final String? outputTemplate;
  final String? formatSelector;
  final String? quality;
  final bool audioOnly;
  final String? audioFormat;
  final String? cookiesPath;
  final String? mergeOutputFormat;
  final bool downloadSubtitles;
  final bool embedSubtitles;
  final String? subtitleLangs;
  final List<String> sponsorBlockCategories;
  final bool allowPlaylist;
  final String? playlistItems;
  final List<String> extraArgs;
}

class DownloadProgressEvent {
  const DownloadProgressEvent({
    required this.taskId,
    required this.engine,
    required this.percent,
    this.downloadedBytes,
    this.totalBytes,
    this.speedBps,
    this.etaSeconds,
    this.phase,
    this.logLine,
  });

  final String taskId;
  final DownloadEngine engine;
  final double percent;
  final int? downloadedBytes;
  final int? totalBytes;
  final double? speedBps;
  final int? etaSeconds;
  final String? phase;
  final String? logLine;
}

class DownloadOutcome {
  const DownloadOutcome({
    required this.taskId,
    required this.engine,
    this.usedFallback = false,
    this.fallbackReason,
    this.outputPath,
    this.outputPaths = const [],
    this.fileSizeBytes,
  });

  final String taskId;
  final DownloadEngine engine;
  final bool usedFallback;
  final String? fallbackReason;
  final String? outputPath;
  final List<String> outputPaths;
  final int? fileSizeBytes;

  DownloadOutcome copyWith({
    DownloadEngine? engine,
    bool? usedFallback,
    String? fallbackReason,
    String? outputPath,
    List<String>? outputPaths,
    int? fileSizeBytes,
  }) {
    return DownloadOutcome(
      taskId: taskId,
      engine: engine ?? this.engine,
      usedFallback: usedFallback ?? this.usedFallback,
      fallbackReason: fallbackReason ?? this.fallbackReason,
      outputPath: outputPath ?? this.outputPath,
      outputPaths: outputPaths ?? this.outputPaths,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }
}
