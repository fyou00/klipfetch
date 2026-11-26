import 'package:flutter_test/flutter_test.dart';
import 'package:klipfetch/models/download_models.dart';
import 'package:klipfetch/models/media_platform.dart';
import 'package:klipfetch/models/media_probe.dart';
import 'package:klipfetch/services/rust_core_service.dart';
import 'package:klipfetch/services/url_router_service.dart';
import 'package:klipfetch/services/ytdlp_service.dart';

class _FakeNativeEngine implements NativeEngineClient {
  int probeCalls = 0;
  int downloadCalls = 0;
  Object? probeError;
  Object? downloadError;

  @override
  Future<void> init({String? dataDir}) async {}

  @override
  MediaPlatform detectPlatform(String url) => detectMediaPlatform(url);

  @override
  Future<MediaProbeResult> probe(String url) async {
    probeCalls++;
    if (probeError != null) throw probeError!;
    return MediaProbeResult(
      platform: detectMediaPlatform(url),
      engine: DownloadEngine.rustCore,
      title: 'Native Probe Title',
      author: 'native_author',
      mediaType: 'video',
      qualities: const [
        MediaFormatOption(
          formatId: 'best',
          label: 'best',
          width: 1080,
          height: 1920,
          format: 'mp4',
          url: 'https://cdn.example.com/video.mp4',
        ),
      ],
    );
  }

  @override
  Future<DownloadOutcome> download(
    DownloadRequest request, {
    void Function(DownloadProgressEvent event)? onProgress,
  }) async {
    downloadCalls++;
    if (downloadError != null) throw downloadError!;
    return DownloadOutcome(
      taskId: request.taskId,
      engine: DownloadEngine.rustCore,
      outputPath: '${request.outputDir}/native.mp4',
      fileSizeBytes: 1024,
    );
  }

  @override
  Future<bool> cancel(String taskId) async => true;

  @override
  Future<String> saveNetscapeCookies(String domain, String netscapeContent) async =>
      '/tmp/cookies.txt';

  @override
  Future<void> clearDomainCookies(String domain) async {}
}

class _FakeYtDlpEngine implements YtDlpEngineClient {
  int probeCalls = 0;
  int downloadCalls = 0;

  @override
  Future<String?> init() async => '2026.11.01';

  @override
  Future<String?> getVersion() async => '2026.11.01';

  @override
  Future<String?> updateYtDlp({String channel = 'stable'}) async => 'DONE';

  @override
  Future<MediaProbeResult> probe(String url, {String? cookiesPath}) async {
    probeCalls++;
    return MediaProbeResult(
      platform: detectMediaPlatform(url),
      engine: DownloadEngine.ytDlp,
      title: 'yt-dlp Probe Title',
      author: 'yt_author',
      mediaType: 'video',
      qualities: const [
        MediaFormatOption(
          formatId: 'bv*[height<=1080]+ba',
          label: '1080p',
          width: 1920,
          height: 1080,
          format: 'mp4',
          url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
      ],
    );
  }

  @override
  Future<DownloadOutcome> download(
    DownloadRequest request, {
    void Function(DownloadProgressEvent event)? onProgress,
  }) async {
    downloadCalls++;
    return DownloadOutcome(
      taskId: request.taskId,
      engine: DownloadEngine.ytDlp,
      outputPath: '${request.outputDir}/ytdlp.mp4',
    );
  }

  @override
  Future<bool> cancel(String taskId) async => true;
}

void main() {
  group('detectMediaPlatform', () {
    test('recognizes TikTok, Instagram, and YouTube URLs', () {
      expect(
        detectMediaPlatform('https://www.tiktok.com/@creator/video/71234567890'),
        MediaPlatform.tiktok,
      );
      expect(
        detectMediaPlatform('https://vm.tiktok.com/ZM8abcdef/'),
        MediaPlatform.tiktok,
      );
      expect(
        detectMediaPlatform('https://www.instagram.com/reel/Cxyz123/'),
        MediaPlatform.instagram,
      );
      expect(
        detectMediaPlatform('https://instagram.com/stories/user/12345/'),
        MediaPlatform.instagram,
      );
      expect(
        detectMediaPlatform('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        MediaPlatform.youtube,
      );
      expect(
        detectMediaPlatform('https://youtu.be/dQw4w9WgXcQ'),
        MediaPlatform.youtube,
      );
      expect(
        detectMediaPlatform('https://m.youtube.com/shorts/abc123'),
        MediaPlatform.youtube,
      );
    });

    test('rejects out-of-scope domains and invalid strings', () {
      expect(
        detectMediaPlatform('https://x.com/rustlang/status/123'),
        MediaPlatform.unsupported,
      );
      expect(
        detectMediaPlatform('https://www.bilibili.com/video/BV1xx411c7mD'),
        MediaPlatform.unsupported,
      );
      expect(
        detectMediaPlatform('https://www.udemy.com/course/rust/'),
        MediaPlatform.unsupported,
      );
      expect(
        detectMediaPlatform('not a url'),
        MediaPlatform.unsupported,
      );
    });
  });

  group('UrlRouterService', () {
    late _FakeNativeEngine native;
    late _FakeYtDlpEngine ytdlp;
    late UrlRouterService router;

    setUp(() {
      native = _FakeNativeEngine();
      ytdlp = _FakeYtDlpEngine();
      router = UrlRouterService(nativeEngine: native, ytDlpEngine: ytdlp);
    });

    test('routes YouTube directly to yt-dlp without invoking Rust core', () async {
      const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      final probe = await router.probe(url);
      final outcome = await router.download(
        const DownloadRequest(
          taskId: 'yt-1',
          url: url,
          outputDir: '/tmp/out',
        ),
      );

      expect(probe.engine, DownloadEngine.ytDlp);
      expect(probe.usedFallback, isFalse);
      expect(outcome.engine, DownloadEngine.ytDlp);
      expect(native.probeCalls, 0);
      expect(native.downloadCalls, 0);
      expect(ytdlp.probeCalls, 1);
      expect(ytdlp.downloadCalls, 1);
    });

    test('routes TikTok and Instagram to Rust core primary on success', () async {
      const url = 'https://www.instagram.com/reel/Cxyz123/';
      final probe = await router.probe(url);
      final outcome = await router.download(
        const DownloadRequest(
          taskId: 'ig-1',
          url: url,
          outputDir: '/tmp/out',
        ),
      );

      expect(probe.engine, DownloadEngine.rustCore);
      expect(probe.usedFallback, isFalse);
      expect(outcome.engine, DownloadEngine.rustCore);
      expect(outcome.usedFallback, isFalse);
      expect(native.probeCalls, 1);
      expect(native.downloadCalls, 1);
      expect(ytdlp.probeCalls, 0);
      expect(ytdlp.downloadCalls, 0);
    });

    test('falls back automatically to yt-dlp when Rust native extraction fails', () async {
      const url = 'https://www.tiktok.com/@creator/video/71234567890';
      native.probeError = StateError('FALLBACK_YTDLP: native scraper blocked');
      native.downloadError = StateError('FALLBACK_YTDLP: CDN returned HTML');

      final probe = await router.probe(url);
      final outcome = await router.download(
        const DownloadRequest(
          taskId: 'tt-1',
          url: url,
          outputDir: '/tmp/out',
        ),
      );

      expect(probe.engine, DownloadEngine.ytDlp);
      expect(probe.usedFallback, isTrue);
      expect(probe.fallbackReason, contains('FALLBACK_YTDLP'));
      expect(outcome.engine, DownloadEngine.ytDlp);
      expect(outcome.usedFallback, isTrue);
      expect(native.probeCalls, 1);
      expect(ytdlp.probeCalls, 1);
      expect(native.downloadCalls, 1);
      expect(ytdlp.downloadCalls, 1);
    });

    test('does not fall back when download is explicitly cancelled', () async {
      const url = 'https://www.tiktok.com/@creator/video/71234567890';
      native.downloadError = const DownloadCancelledException('tt-cancel');

      await expectLater(
        router.download(
          const DownloadRequest(
            taskId: 'tt-cancel',
            url: url,
            outputDir: '/tmp/out',
          ),
        ),
        throwsA(isA<DownloadCancelledException>()),
      );
      expect(ytdlp.downloadCalls, 0);
    });

    test('throws UnsupportedPlatformException for out-of-scope URLs', () async {
      await expectLater(
        router.probe('https://x.com/user/status/1'),
        throwsA(isA<UnsupportedPlatformException>()),
      );
      expect(native.probeCalls, 0);
      expect(ytdlp.probeCalls, 0);
    });
  });

  group('YtDlpService.parseYtDlpInfoJson', () {
    test('extracts sorted unique resolution options from yt-dlp JSON', () {
      const sampleJson = '''
      {
        "title": "Sample Video",
        "uploader": "Channel Name",
        "duration": 125.0,
        "thumbnail": "https://i.ytimg.com/vi/abc/maxresdefault.jpg",
        "webpage_url": "https://www.youtube.com/watch?v=abc",
        "formats": [
          {"format_id": "18", "height": 360, "width": 640, "vcodec": "avc1", "ext": "mp4"},
          {"format_id": "140", "height": null, "vcodec": "none", "acodec": "mp4a", "ext": "m4a"},
          {"format_id": "299", "height": 1080, "width": 1920, "vcodec": "avc1", "ext": "mp4"},
          {"format_id": "248", "height": 1080, "width": 1920, "vcodec": "vp9", "ext": "webm"},
          {"format_id": "313", "height": 2160, "width": 3840, "vcodec": "vp9", "ext": "webm"}
        ]
      }
      ''';

      final parsed = YtDlpService.parseYtDlpInfoJson(
        sampleJson,
        MediaPlatform.youtube,
        'https://www.youtube.com/watch?v=abc',
      );

      expect(parsed.title, 'Sample Video');
      expect(parsed.author, 'Channel Name');
      expect(parsed.platform, MediaPlatform.youtube);
      expect(parsed.qualities.map((q) => q.label).toList(), [
        '2160p',
        '1080p',
        '360p',
      ]);
    });
  });
}
