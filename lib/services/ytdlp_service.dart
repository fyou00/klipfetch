import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/download_models.dart';
import '../models/media_platform.dart';
import '../models/media_probe.dart';

abstract interface class YtDlpEngineClient {
  Future<String?> init();
  Future<String?> getVersion();
  Future<String?> updateYtDlp({String channel = 'stable'});
  Future<MediaProbeResult> probe(String url, {String? cookiesPath});
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
  Future<MediaProbeResult> probe(String url, {String? cookiesPath}) async {
    final rawJson = await _methodChannel.invokeMethod<String>('extractInfo', {
      'url': url,
      'cookiesPath': cookiesPath,
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
      await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('download', {
        'taskId': request.taskId,
        'url': request.url,
        'outputTemplate': outputTemplate,
        'formatSelector': request.formatSelector,
        'audioOnly': request.audioOnly,
        'audioFormat': request.audioFormat ?? 'm4a',
        'cookiesPath': request.cookiesPath,
        'extraArgs': request.extraArgs,
      });

      return DownloadOutcome(
        taskId: request.taskId,
        engine: DownloadEngine.ytDlp,
        outputPath: request.outputDir,
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

    return MediaProbeResult(
      platform: platform,
      engine: DownloadEngine.ytDlp,
      title: (title == null || title.isEmpty) ? 'untitled' : title,
      author: uploader,
      durationSeconds: duration,
      thumbnailUrl: thumbnail,
      mediaType: 'video',
      qualities: options,
    );
  }
}
