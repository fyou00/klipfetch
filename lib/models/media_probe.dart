import 'media_platform.dart';

enum DownloadEngine {
  rustCore,
  ytDlp,
}

class MediaFormatOption {
  const MediaFormatOption({
    required this.formatId,
    required this.label,
    required this.width,
    required this.height,
    required this.format,
    required this.url,
  });

  final String formatId;
  final String label;
  final int width;
  final int height;
  final String format;
  final String url;
}

class MediaProbeResult {
  const MediaProbeResult({
    required this.platform,
    required this.engine,
    required this.title,
    required this.author,
    this.durationSeconds,
    this.thumbnailUrl,
    required this.mediaType,
    required this.qualities,
    this.usedFallback = false,
    this.fallbackReason,
  });

  final MediaPlatform platform;
  final DownloadEngine engine;
  final String title;
  final String author;
  final double? durationSeconds;
  final String? thumbnailUrl;
  final String mediaType;
  final List<MediaFormatOption> qualities;
  final bool usedFallback;
  final String? fallbackReason;

  MediaProbeResult copyWith({
    DownloadEngine? engine,
    bool? usedFallback,
    String? fallbackReason,
  }) {
    return MediaProbeResult(
      platform: platform,
      engine: engine ?? this.engine,
      title: title,
      author: author,
      durationSeconds: durationSeconds,
      thumbnailUrl: thumbnailUrl,
      mediaType: mediaType,
      qualities: qualities,
      usedFallback: usedFallback ?? this.usedFallback,
      fallbackReason: fallbackReason ?? this.fallbackReason,
    );
  }
}
