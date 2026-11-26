import '../models/download_models.dart';
import '../models/media_platform.dart';
import '../models/media_probe.dart';
import 'rust_core_service.dart';
import 'ytdlp_service.dart';

bool isInstagramStoryUrl(String rawUrl) {
  final parsed = Uri.tryParse(rawUrl.trim());
  if (parsed == null) return false;
  if (detectMediaPlatform(rawUrl) != MediaPlatform.instagram) return false;
  return parsed.path.toLowerCase().startsWith('/stories/');
}

/// Routes TikTok, Instagram, and YouTube requests across KlipFetch's Dual-Engine
/// architecture:
/// - YouTube -> [YtDlpEngineClient] (`youtubedl-android` + QuickJS-NG + FFmpeg)
/// - TikTok & Instagram -> [NativeEngineClient] (`libreget-core` Rust FFI) first,
///   with automatic fallback to [YtDlpEngineClient].
class UrlRouterService {
  const UrlRouterService({
    required this.nativeEngine,
    required this.ytDlpEngine,
  });

  final NativeEngineClient nativeEngine;
  final YtDlpEngineClient ytDlpEngine;

  MediaPlatform classifyUrl(String url) {
    return detectMediaPlatform(url);
  }

  Future<MediaProbeResult> probe(
    String url, {
    String? cookiesPath,
    bool allowPlaylist = false,
  }) async {
    final platform = classifyUrl(url);
    switch (platform) {
      case MediaPlatform.unsupported:
        throw UnsupportedPlatformException(url);
      case MediaPlatform.youtube:
        return ytDlpEngine.probe(
          url,
          cookiesPath: cookiesPath,
          allowPlaylist: allowPlaylist,
        );
      case MediaPlatform.instagram:
        if (isInstagramStoryUrl(url)) {
          return ytDlpEngine.probe(url, cookiesPath: cookiesPath);
        }
        return _probeNativeWithFallback(url, cookiesPath: cookiesPath);
      case MediaPlatform.tiktok:
        return _probeNativeWithFallback(url, cookiesPath: cookiesPath);
    }
  }

  Future<MediaProbeResult> _probeNativeWithFallback(
    String url, {
    String? cookiesPath,
  }) async {
    try {
      return await nativeEngine.probe(url);
    } catch (err) {
      final fallback = await ytDlpEngine.probe(
        url,
        cookiesPath: cookiesPath,
      );
      return fallback.copyWith(
        usedFallback: true,
        fallbackReason: err.toString(),
      );
    }
  }

  Future<DownloadOutcome> download(
    DownloadRequest request, {
    void Function(DownloadProgressEvent event)? onProgress,
  }) async {
    final platform = classifyUrl(request.url);
    switch (platform) {
      case MediaPlatform.unsupported:
        throw UnsupportedPlatformException(request.url);
      case MediaPlatform.youtube:
        return ytDlpEngine.download(request, onProgress: onProgress);
      case MediaPlatform.instagram:
        if (isInstagramStoryUrl(request.url) ||
            request.audioOnly ||
            request.downloadSubtitles) {
          return ytDlpEngine.download(request, onProgress: onProgress);
        }
        return _downloadNativeWithFallback(request, onProgress: onProgress);
      case MediaPlatform.tiktok:
        if (request.downloadSubtitles) {
          return ytDlpEngine.download(request, onProgress: onProgress);
        }
        return _downloadNativeWithFallback(request, onProgress: onProgress);
    }
  }

  Future<DownloadOutcome> _downloadNativeWithFallback(
    DownloadRequest request, {
    void Function(DownloadProgressEvent event)? onProgress,
  }) async {
    try {
      return await nativeEngine.download(request, onProgress: onProgress);
    } on DownloadCancelledException {
      rethrow;
    } catch (err) {
      final fallback = await ytDlpEngine.download(
        request,
        onProgress: onProgress,
      );
      return fallback.copyWith(
        usedFallback: true,
        fallbackReason: err.toString(),
      );
    }
  }
}
