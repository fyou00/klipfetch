import 'package:path_provider/path_provider.dart';

import '../models/download_models.dart';
import '../models/media_platform.dart';
import '../models/media_probe.dart';
import '../src/rust/api/core.dart' as rust_core;
import '../src/rust/api/queue.dart' as rust_queue;
import '../src/rust/frb_generated.dart';

class CookieDomainStatusInfo {
  const CookieDomainStatusInfo({
    required this.domain,
    required this.hasCookies,
    required this.cookieCount,
    required this.hasAuthCookie,
    this.updatedAtMs,
  });

  final String domain;
  final bool hasCookies;
  final int cookieCount;
  final bool hasAuthCookie;
  final int? updatedAtMs;
}

abstract interface class NativeEngineClient {
  Future<void> init({String? dataDir});
  MediaPlatform detectPlatform(String url);
  Future<MediaProbeResult> probe(String url);
  Future<DownloadOutcome> download(
    DownloadRequest request, {
    void Function(DownloadProgressEvent event)? onProgress,
  });
  Future<bool> cancel(String taskId);
  Future<String> saveNetscapeCookies(String domain, String netscapeContent);
  Future<void> clearDomainCookies(String domain);
  Future<CookieDomainStatusInfo> getCookieDomainStatus(String domain);
  Future<String?> getSharedCookiesPath();
}

class RustCoreService implements NativeEngineClient {
  bool _initialized = false;

  @override
  Future<void> init({String? dataDir}) async {
    if (!_initialized) {
      await RustLib.init();
      _initialized = true;
    }
    final resolvedDir =
        dataDir ?? (await getApplicationSupportDirectory()).path;
    await rust_core.initCore(dataDir: resolvedDir);
  }

  @override
  MediaPlatform detectPlatform(String url) {
    if (_initialized) {
      final detected = rust_core.detectPlatform(url: url);
      switch (detected) {
        case rust_core.SupportedPlatform.tikTok:
          return MediaPlatform.tiktok;
        case rust_core.SupportedPlatform.instagram:
          return MediaPlatform.instagram;
        case rust_core.SupportedPlatform.youTube:
          return MediaPlatform.youtube;
        case rust_core.SupportedPlatform.unsupported:
          return MediaPlatform.unsupported;
      }
    }
    return detectMediaPlatform(url);
  }

  @override
  Future<MediaProbeResult> probe(String url) async {
    final info = await rust_core.probeNativeMedia(url: url);
    final platform = detectMediaPlatform(url);
    return MediaProbeResult(
      platform: platform,
      engine: DownloadEngine.rustCore,
      title: info.title,
      author: info.author,
      durationSeconds: info.durationSeconds,
      thumbnailUrl: info.thumbnailUrl,
      mediaType: info.mediaType,
      qualities: info.qualities
          .map(
            (q) => MediaFormatOption(
              formatId: q.label,
              label: q.label,
              width: q.width,
              height: q.height,
              format: q.format,
              url: q.url,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<DownloadOutcome> download(
    DownloadRequest request, {
    void Function(DownloadProgressEvent event)? onProgress,
  }) async {
    String? finalOutputPath;
    int? finalSizeBytes;

    try {
      await for (final event in rust_core.downloadNativeMedia(
        taskId: request.taskId,
        url: request.url,
        outputDir: request.outputDir,
        quality: request.quality,
        audioOnly: request.audioOnly,
      )) {
        if (event.outputPath != null) {
          finalOutputPath = event.outputPath;
        }
        if (event.totalBytes != null) {
          finalSizeBytes = event.totalBytes!.toInt();
        }
        onProgress?.call(
          DownloadProgressEvent(
            taskId: request.taskId,
            engine: DownloadEngine.rustCore,
            percent: event.percent,
            downloadedBytes: event.downloadedBytes?.toInt(),
            totalBytes: event.totalBytes?.toInt(),
            speedBps: event.speedBps,
            etaSeconds: event.etaSeconds?.toInt(),
            phase: event.phase,
          ),
        );
      }
    } catch (e) {
      if (e.toString().toLowerCase().contains('download cancelled')) {
        throw DownloadCancelledException(request.taskId);
      }
      rethrow;
    }

    return DownloadOutcome(
      taskId: request.taskId,
      engine: DownloadEngine.rustCore,
      outputPath: finalOutputPath,
      fileSizeBytes: finalSizeBytes,
    );
  }

  @override
  Future<bool> cancel(String taskId) async {
    return rust_core.cancelNativeDownload(taskId: taskId);
  }

  @override
  Future<String> saveNetscapeCookies(String domain, String netscapeContent) {
    return rust_core.saveNetscapeCookies(
      domain: domain,
      netscapeContent: netscapeContent,
    );
  }

  @override
  Future<void> clearDomainCookies(String domain) {
    return rust_core.clearDomainCookies(domain: domain);
  }

  @override
  Future<CookieDomainStatusInfo> getCookieDomainStatus(String domain) async {
    final status = await rust_core.getCookieDomainStatus(domain: domain);
    return CookieDomainStatusInfo(
      domain: status.domain,
      hasCookies: status.hasCookies,
      cookieCount: status.cookieCount,
      hasAuthCookie: status.hasAuthCookie,
      updatedAtMs: status.updatedAtMs?.toInt(),
    );
  }

  @override
  Future<String?> getSharedCookiesPath() {
    return rust_core.getSharedCookiesPath();
  }

  Future<rust_queue.QueueTaskRecord> enqueueTask({
    required String url,
    required String platform,
    required String title,
    required DownloadEngine engine,
  }) {
    return rust_queue.enqueueTask(
      url: url,
      platform: platform,
      title: title,
      engine: engine == DownloadEngine.rustCore ? 'rust_core' : 'yt_dlp',
    );
  }

  Future<List<rust_queue.QueueTaskRecord>> listQueueTasks() {
    return rust_queue.listTasks();
  }
}
