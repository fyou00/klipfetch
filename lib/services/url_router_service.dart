import '../models/download_models.dart';
import '../models/media_platform.dart';
import '../models/media_probe.dart';
import 'rust_core_service.dart';
import 'ytdlp_service.dart';

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
  }) async {
    final platform = classifyUrl(url);
    switch (platform) {
      case MediaPlatform.unsupported:
        throw UnsupportedPlatformException(url);
      case MediaPlatform.youtube:
        return ytDlpEngine.probe(url, cookiesPath: cookiesPath);
      case MediaPlatform.tiktok:
      case MediaPlatform.instagram:
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
      case MediaPlatform.tiktok:
      case MediaPlatform.instagram:
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
}
