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

class PlaylistEntry {
  const PlaylistEntry({
    required this.index,
    required this.id,
    required this.title,
    required this.url,
    this.durationSeconds,
    this.thumbnailUrl,
  });

  final int index;
  final String id;
  final String title;
  final String url;
  final double? durationSeconds;
  final String? thumbnailUrl;
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
    this.playlistEntries = const [],
    this.availableSubtitles = const [],
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
  final List<PlaylistEntry> playlistEntries;
  final List<String> availableSubtitles;
  final bool usedFallback;
  final String? fallbackReason;

  bool get isPlaylist =>
      mediaType == 'playlist' && playlistEntries.isNotEmpty;

  bool get isCarousel =>
      mediaType == 'carousel' ||
      (mediaType == 'photo' && photoSlideCount > 1);

  bool get hasSlideshowAudio =>
      qualities.any((q) => q.label == 'slideshow_audio');

  int get photoSlideCount =>
      qualities.where((q) => q.label != 'slideshow_audio').length;

  MediaProbeResult copyWith({
    DownloadEngine? engine,
    bool? usedFallback,
    String? fallbackReason,
    List<PlaylistEntry>? playlistEntries,
    List<String>? availableSubtitles,
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
      playlistEntries: playlistEntries ?? this.playlistEntries,
      availableSubtitles: availableSubtitles ?? this.availableSubtitles,
      usedFallback: usedFallback ?? this.usedFallback,
      fallbackReason: fallbackReason ?? this.fallbackReason,
    );
  }
}
