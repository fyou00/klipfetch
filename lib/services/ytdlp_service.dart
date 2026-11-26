import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/download_models.dart';
import '../models/media_platform.dart';
import '../models/media_probe.dart';

bool isYouTubePlaylistUrl(String rawUrl) {
  final parsed = Uri.tryParse(rawUrl.trim());
  if (parsed == null) return false;
  if (detectMediaPlatform(rawUrl) != MediaPlatform.youtube) return false;
  final listId = parsed.queryParameters['list']?.trim() ?? '';
  if (listId.isEmpty) return false;
  final path = parsed.path.toLowerCase();
  return path.contains('playlist') || !path.contains('/watch');
}

abstract interface class YtDlpEngineClient {
  Future<String?> init();
  Future<String?> getVersion();
  Future<String?> updateYtDlp({String channel = 'stable'});
  Future<MediaProbeResult> probe(
    String url, {
    String? cookiesPath,
    bool allowPlaylist = false,
  });
  Future<DownloadOutcome> download(
    DownloadRequest request, {
    void Function(DownloadProgressEvent event)? onProgress,
  });
  Future<bool> cancel(String taskId);
}

class YtDlpService implements YtDlpEngineClient {
  YtDlpService({
    MethodChannel? methodChannel,
    EventChannel? progressChannel,
  })  : _methodChannel =
            methodChannel ?? const MethodChannel(_methodChannelName),
        _progressChannel =
            progressChannel ?? const EventChannel(_progressChannelName);

  static const _methodChannelName = 'io.github.fyou00.klipfetch/ytdlp';
  static const _progressChannelName =
      'io.github.fyou00.klipfetch/ytdlp_progress';

  final MethodChannel _methodChannel;
  final EventChannel _progressChannel;

  @override
  Future<String?> init() {
    return _methodChannel.invokeMethod<String>('init');
  }

  @override
  Future<String?> getVersion() {
    return _methodChannel.invokeMethod<String>('getVersion');
  }

  @override
  Future<String?> updateYtDlp({String channel = 'stable'}) {
    return _methodChannel.invokeMethod<String>('updateYtDlp', {
      'channel': channel,
    });
  }

  @override
  Future<MediaProbeResult> probe(
    String url, {
    String? cookiesPath,
    bool allowPlaylist = false,
  }) async {
    final rawJson = await _methodChannel.invokeMethod<String>('extractInfo', {
      'url': url,
      'cookiesPath': cookiesPath,
      'allowPlaylist': allowPlaylist,
    });
    if (rawJson == null || rawJson.trim().isEmpty) {
      throw StateError('yt-dlp returned empty metadata JSON for $url');
    }
    return parseYtDlpInfoJson(rawJson, detectMediaPlatform(url), url);
  }

  @override
  Future<DownloadOutcome> download(
    DownloadRequest request, {
    void Function(DownloadProgressEvent event)? onProgress,
  }) async {
    final subscription =
        _progressChannel.receiveBroadcastStream().listen((dynamic raw) {
      if (raw is! Map) return;
      if (raw['taskId'] != request.taskId) return;
      onProgress?.call(
        DownloadProgressEvent(
          taskId: request.taskId,
          engine: DownloadEngine.ytDlp,
          percent: (raw['percent'] as num?)?.toDouble() ?? 0.0,
          etaSeconds: (raw['etaSeconds'] as num?)?.toInt(),
          phase: raw['phase'] as String?,
          logLine: raw['logLine'] as String?,
        ),
      );
    });

    final outputTemplate = request.outputTemplate ??
        '${request.outputDir}/%(title).120B [%(id)s].%(ext)s';

    try {
      final result =
          await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('download', {
        'taskId': request.taskId,
        'url': request.url,
        'outputTemplate': outputTemplate,
        'formatSelector': request.formatSelector,
        'audioOnly': request.audioOnly,
        'audioFormat': request.audioFormat ?? 'm4a',
        'cookiesPath': request.cookiesPath,
        'allowPlaylist': request.allowPlaylist,
        'playlistItems': request.playlistItems,
        'mergeOutputFormat': request.mergeOutputFormat ?? 'mp4',
        'downloadSubtitles': request.downloadSubtitles,
        'embedSubtitles': request.embedSubtitles,
        'subtitleLangs': request.subtitleLangs ?? 'en,id',
        'sponsorBlockCategories': request.sponsorBlockCategories,
        'extraArgs': request.extraArgs,
      });

      final resolvedPath = result?['outputPath'] as String?;
      final rawOutputPaths =
          result?['outputPaths'] as List<dynamic>? ?? const [];
      final outputPaths =
          rawOutputPaths.whereType<String>().toList(growable: false);
      return DownloadOutcome(
        taskId: request.taskId,
        engine: DownloadEngine.ytDlp,
        outputPath: (resolvedPath != null && resolvedPath.isNotEmpty)
            ? resolvedPath
            : request.outputDir,
        outputPaths: outputPaths,
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELLED') {
        throw DownloadCancelledException(request.taskId);
      }
      rethrow;
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<bool> cancel(String taskId) async {
    final result = await _methodChannel.invokeMethod<bool>('cancel', {
      'taskId': taskId,
    });
    return result ?? false;
  }

  static MediaProbeResult parseYtDlpInfoJson(
    String rawJson,
    MediaPlatform platform,
    String sourceUrl,
  ) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object from yt-dlp');
    }

    final title = (decoded['title'] as String?)?.trim();
    final uploader = (decoded['uploader'] as String?) ??
        (decoded['channel'] as String?) ??
        (decoded['uploader_id'] as String?) ??
        '';
    final duration = (decoded['duration'] as num?)?.toDouble();
    final thumbnail = decoded['thumbnail'] as String?;

    if (decoded['_type'] == 'playlist') {
      final rawEntries = decoded['entries'] as List<dynamic>? ?? const [];
      final entries = <PlaylistEntry>[];
      for (var i = 0; i < rawEntries.length; i++) {
        final item = rawEntries[i];
        if (item is! Map<String, dynamic>) continue;
        final id = (item['id'] as String?) ?? '${i + 1}';
        final rawTitle = (item['title'] as String?)?.trim();
        final entryTitle =
            (rawTitle != null && rawTitle.isNotEmpty) ? rawTitle : 'Video ${i + 1}';
        final rawUrl = (item['webpage_url'] as String?) ??
            (item['url'] as String?) ??
            '';
        final resolvedUrl = rawUrl.startsWith('http')
            ? rawUrl
            : 'https://www.youtube.com/watch?v=$id';
        entries.add(
          PlaylistEntry(
            index: i + 1,
            id: id,
            title: entryTitle,
            url: resolvedUrl,
            durationSeconds: (item['duration'] as num?)?.toDouble(),
            thumbnailUrl: item['thumbnail'] as String?,
          ),
        );
      }

      if (entries.isNotEmpty) {
        final webpage = (decoded['webpage_url'] as String?) ?? sourceUrl;
        final presetQualities = [2160, 1440, 1080, 720, 480]
            .map(
              (h) => MediaFormatOption(
                formatId: 'bv*[height<=$h]+ba/b[height<=$h]/b',
                label: '${h}p',
                width: 0,
                height: h,
                format: 'mp4',
                url: webpage,
              ),
            )
            .toList(growable: false);
        return MediaProbeResult(
          platform: platform,
          engine: DownloadEngine.ytDlp,
          title: (title == null || title.isEmpty) ? 'YouTube Playlist' : title,
          author: uploader,
          thumbnailUrl: thumbnail ?? entries.first.thumbnailUrl,
          mediaType: 'playlist',
          qualities: presetQualities,
          playlistEntries: List.unmodifiable(entries),
        );
      }
    }

    final formatsRaw = decoded['formats'] as List<dynamic>? ?? const [];

    final seenHeights = <int>{};
    final options = <MediaFormatOption>[];

    for (final entry in formatsRaw) {
      if (entry is! Map<String, dynamic>) continue;
      final vcodec = entry['vcodec'] as String?;
      final height = (entry['height'] as num?)?.toInt() ?? 0;
      final width = (entry['width'] as num?)?.toInt() ?? 0;
      final formatId = (entry['format_id'] as String?) ?? '';
      final ext = (entry['ext'] as String?) ?? 'mp4';

      if (vcodec == 'none' || height <= 0 || !seenHeights.add(height)) {
        continue;
      }

      options.add(
        MediaFormatOption(
          formatId: formatId.isNotEmpty
              ? 'bv*[height<=$height]+ba/b[height<=$height]/b'
              : 'bv*+ba/b',
          label: '${height}p',
          width: width,
          height: height,
          format: ext,
          url: (decoded['webpage_url'] as String?) ?? sourceUrl,
        ),
      );
    }

    options.sort((a, b) => b.height.compareTo(a.height));
    if (options.isEmpty) {
      options.add(
        MediaFormatOption(
          formatId: 'bv*+ba/b',
          label: 'best',
          width: 0,
          height: 0,
          format: 'mp4',
          url: (decoded['webpage_url'] as String?) ?? sourceUrl,
        ),
      );
    }

    final subtitleLangs = <String>{};
    for (final field in const ['subtitles', 'automatic_captions']) {
      final rawMap = decoded[field];
      if (rawMap is Map<String, dynamic>) {
        for (final lang in rawMap.keys) {
          final clean = lang.trim();
          if (clean.isNotEmpty && clean != 'live_chat') {
            subtitleLangs.add(clean);
          }
        }
      }
    }
    final sortedSubtitles = subtitleLangs.toList()..sort();

    return MediaProbeResult(
      platform: platform,
      engine: DownloadEngine.ytDlp,
      title: (title == null || title.isEmpty) ? 'untitled' : title,
      author: uploader,
      durationSeconds: duration,
      thumbnailUrl: thumbnail,
      mediaType: 'video',
      qualities: options,
      availableSubtitles: List.unmodifiable(sortedSubtitles),
    );
  }
}
