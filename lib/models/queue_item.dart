import 'media_platform.dart';
import 'media_probe.dart';

enum DownloadPhase {
  queued,
  connecting,
  downloading,
  muxing,
  saving,
  completed,
  failed,
  cancelled,
  paused;

  String get label {
    switch (this) {
      case DownloadPhase.queued:
        return 'Queued';
      case DownloadPhase.connecting:
        return 'Connecting';
      case DownloadPhase.downloading:
        return 'Downloading';
      case DownloadPhase.muxing:
        return 'Muxing';
      case DownloadPhase.saving:
        return 'Saving to Downloads';
      case DownloadPhase.completed:
        return 'Completed';
      case DownloadPhase.failed:
        return 'Failed';
      case DownloadPhase.cancelled:
        return 'Cancelled';
      case DownloadPhase.paused:
        return 'Paused';
    }
  }
}

class QueueItem {
  const QueueItem({
    required this.id,
    required this.url,
    required this.platform,
    required this.title,
    required this.engine,
    required this.phase,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.progress = 0.0,
    this.downloadedBytes,
    this.totalBytes,
    this.speedBps,
    this.etaSeconds,
    this.formatSelector,
    this.qualityLabel,
    this.audioOnly = false,
    this.audioFormat,
    this.mergeOutputFormat,
    this.downloadSubtitles = false,
    this.embedSubtitles = true,
    this.subtitleLangs,
    this.sponsorBlockCategories = const [],
    this.usedFallback = false,
    this.outputPath,
    this.contentUri,
    this.exportedCount = 1,
    this.errorMessage,
    this.retryCount = 0,
  });

  final String id;
  final String url;
  final MediaPlatform platform;
  final String title;
  final DownloadEngine engine;
  final DownloadPhase phase;
  final int createdAtMs;
  final int updatedAtMs;
  final double progress;
  final int? downloadedBytes;
  final int? totalBytes;
  final double? speedBps;
  final int? etaSeconds;
  final String? formatSelector;
  final String? qualityLabel;
  final bool audioOnly;
  final String? audioFormat;
  final String? mergeOutputFormat;
  final bool downloadSubtitles;
  final bool embedSubtitles;
  final String? subtitleLangs;
  final List<String> sponsorBlockCategories;
  final bool usedFallback;
  final String? outputPath;
  final String? contentUri;
  final int exportedCount;
  final String? errorMessage;
  final int retryCount;

  bool get isActive =>
      phase == DownloadPhase.queued ||
      phase == DownloadPhase.connecting ||
      phase == DownloadPhase.downloading ||
      phase == DownloadPhase.muxing ||
      phase == DownloadPhase.saving;

  bool get isFinished =>
      phase == DownloadPhase.completed ||
      phase == DownloadPhase.failed ||
      phase == DownloadPhase.cancelled;

  QueueItem copyWith({
    DownloadEngine? engine,
    DownloadPhase? phase,
    int? updatedAtMs,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    double? speedBps,
    int? etaSeconds,
    bool? usedFallback,
    String? outputPath,
    String? contentUri,
    int? exportedCount,
    String? errorMessage,
    bool clearError = false,
    int? retryCount,
  }) {
    return QueueItem(
      id: id,
      url: url,
      platform: platform,
      title: title,
      engine: engine ?? this.engine,
      phase: phase ?? this.phase,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      speedBps: speedBps ?? this.speedBps,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      formatSelector: formatSelector,
      qualityLabel: qualityLabel,
      audioOnly: audioOnly,
      audioFormat: audioFormat,
      mergeOutputFormat: mergeOutputFormat,
      downloadSubtitles: downloadSubtitles,
      embedSubtitles: embedSubtitles,
      subtitleLangs: subtitleLangs,
      sponsorBlockCategories: sponsorBlockCategories,
      usedFallback: usedFallback ?? this.usedFallback,
      outputPath: outputPath ?? this.outputPath,
      contentUri: contentUri ?? this.contentUri,
      exportedCount: exportedCount ?? this.exportedCount,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
