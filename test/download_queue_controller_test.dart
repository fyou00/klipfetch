import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipfetch/models/app_settings.dart';
import 'package:klipfetch/models/auth_models.dart';
import 'package:klipfetch/models/download_models.dart';
import 'package:klipfetch/models/media_platform.dart';
import 'package:klipfetch/models/media_probe.dart';
import 'package:klipfetch/models/queue_item.dart';
import 'package:klipfetch/services/android_platform_service.dart';
import 'package:klipfetch/services/queue_repository.dart';
import 'package:klipfetch/services/rust_core_service.dart';
import 'package:klipfetch/services/settings_repository.dart';
import 'package:klipfetch/services/ytdlp_service.dart';
import 'package:klipfetch/state/providers.dart';

class _TestNativeEngine implements NativeEngineClient {
  int downloadCalls = 0;
  final Set<String> cancelledIds = {};
  String? sharedCookiesPath;
  Future<DownloadOutcome> Function(DownloadRequest request)? onDownload;

  @override
  Future<void> init({String? dataDir}) async {}

  @override
  MediaPlatform detectPlatform(String url) => detectMediaPlatform(url);

  @override
  Future<MediaProbeResult> probe(String url) async {
    return MediaProbeResult(
      platform: detectMediaPlatform(url),
      engine: DownloadEngine.rustCore,
      title: 'Native Video',
      author: 'creator',
      mediaType: 'video',
      qualities: const [
        MediaFormatOption(
          formatId: 'best',
          label: 'best',
          width: 1080,
          height: 1920,
          format: 'mp4',
          url: 'https://cdn.example.com/v.mp4',
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
    if (onDownload != null) {
      return onDownload!(request);
    }
    onProgress?.call(
      DownloadProgressEvent(
        taskId: request.taskId,
        engine: DownloadEngine.rustCore,
        percent: 50,
        phase: 'downloading',
      ),
    );
    return DownloadOutcome(
      taskId: request.taskId,
      engine: DownloadEngine.rustCore,
      outputPath: '${request.outputDir}/native.mp4',
      fileSizeBytes: 2048,
    );
  }

  @override
  Future<bool> cancel(String taskId) async {
    cancelledIds.add(taskId);
    return true;
  }

  @override
  Future<String> saveNetscapeCookies(String domain, String content) async =>
      '/tmp/cookies.txt';

  @override
  Future<void> clearDomainCookies(String domain) async {}

  @override
  Future<CookieDomainStatusInfo> getCookieDomainStatus(String domain) async =>
      CookieDomainStatusInfo(
        domain: domain,
        hasCookies: sharedCookiesPath != null,
        cookieCount: sharedCookiesPath != null ? 2 : 0,
        hasAuthCookie: sharedCookiesPath != null,
      );

  @override
  Future<String?> getSharedCookiesPath() async => sharedCookiesPath;
}

class _TestYtDlpEngine implements YtDlpEngineClient {
  int downloadCalls = 0;
  int activeCount = 0;
  int maxObservedConcurrent = 0;
  DownloadRequest? lastRequest;
  Future<DownloadOutcome> Function(
    DownloadRequest request,
    void Function(DownloadProgressEvent event)? onProgress,
  )? onDownload;

  @override
  Future<String?> init() async => '2026.11.01';

  @override
  Future<String?> getVersion() async => '2026.11.01';

  @override
  Future<String?> updateYtDlp({String channel = 'stable'}) async => 'DONE';

  @override
  Future<MediaProbeResult> probe(
    String url, {
    String? cookiesPath,
    bool allowPlaylist = false,
  }) async {
    return MediaProbeResult(
      platform: detectMediaPlatform(url),
      engine: DownloadEngine.ytDlp,
      title: 'YT Sample',
      author: 'yt_creator',
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
    lastRequest = request;
    activeCount++;
    if (activeCount > maxObservedConcurrent) {
      maxObservedConcurrent = activeCount;
    }
    try {
      if (onDownload != null) {
        return await onDownload!(request, onProgress);
      }
      onProgress?.call(
        DownloadProgressEvent(
          taskId: request.taskId,
          engine: DownloadEngine.ytDlp,
          percent: 60,
          phase: 'downloading',
        ),
      );
      return DownloadOutcome(
        taskId: request.taskId,
        engine: DownloadEngine.ytDlp,
        outputPath: '${request.outputDir}/yt_video.mp4',
        fileSizeBytes: 4096,
      );
    } finally {
      activeCount--;
    }
  }

  @override
  Future<bool> cancel(String taskId) async => true;
}

class _FakeAndroidPlatform implements AndroidPlatformClient {
  int startFgCalls = 0;
  int updateFgCalls = 0;
  int stopFgCalls = 0;
  int exportCalls = 0;
  int batchExportCalls = 0;
  BatchExportedMedia? nextBatchExport;

  @override
  Future<String?> getInitialSharedText() async => null;

  @override
  Stream<String> get sharedTextStream => const Stream.empty();

  @override
  Stream<String> get notificationCancelStream => const Stream.empty();

  @override
  Future<void> startForegroundDownload({
    required String taskId,
    required String title,
    required int progress,
    required int activeCount,
    String? statusText,
  }) async {
    startFgCalls++;
  }

  @override
  Future<void> updateForegroundDownload({
    required String taskId,
    required String title,
    required int progress,
    required int activeCount,
    String? statusText,
  }) async {
    updateFgCalls++;
  }

  @override
  Future<void> stopForegroundDownload() async {
    stopFgCalls++;
  }

  @override
  Future<ExportedMediaFile?> exportToMediaStore({
    required String stagedFilePath,
    required String platform,
  }) async {
    exportCalls++;
    final folder = switch (platform) {
      'tiktok' => 'TikTok',
      'instagram' => 'Instagram',
      _ => 'YouTube',
    };
    return ExportedMediaFile(
      uri: 'content://media/external/downloads/100',
      displayPath: 'Downloads/KlipFetch/$folder/final.mp4',
      fileName: 'final.mp4',
      sizeBytes: 8192,
    );
  }

  @override
  Future<BatchExportedMedia?> exportStagingDirectory({
    required String stagingDirPath,
    required String platform,
  }) async {
    batchExportCalls++;
    return nextBatchExport;
  }

  @override
  Future<AuthBrowserCapture> openAuthBrowser({
    required String platform,
    required String loginUrl,
    required List<String> cookieUrls,
    required List<String> authCookieNames,
  }) async {
    return const AuthBrowserCapture(cancelled: true);
  }

  @override
  Future<bool> clearWebViewCookies({
    List<String> cookieUrls = const [],
    bool clearAll = false,
  }) async =>
      true;

  @override
  Future<bool> openFile(String uriOrPath) async => true;

  @override
  Future<bool> shareFile(String uriOrPath) async => true;

  @override
  Future<bool> requestNotificationPermission() async => true;
}

Future<void> _pumpUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late Directory tempDir;
  late _TestNativeEngine native;
  late _TestYtDlpEngine ytdlp;
  late _FakeAndroidPlatform android;
  late InMemoryQueueStorage queueStorage;
  late InMemorySettingsStorage settingsStorage;

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        rustCoreServiceProvider.overrideWithValue(native),
        ytDlpServiceProvider.overrideWithValue(ytdlp),
        androidPlatformProvider.overrideWithValue(android),
        queueStorageProvider.overrideWithValue(queueStorage),
        settingsStorageProvider.overrideWithValue(settingsStorage),
        stagingDirProvider.overrideWithValue(() async => tempDir.path),
        retryDelayProvider.overrideWithValue((_) => Duration.zero),
      ],
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('klipfetch_q_test_');
    native = _TestNativeEngine();
    ytdlp = _TestYtDlpEngine();
    android = _FakeAndroidPlatform();
    queueStorage = InMemoryQueueStorage();
    settingsStorage = InMemorySettingsStorage();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('enqueues, starts Foreground Service, exports to MediaStore, and stops Foreground Service', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    final notifier = container.read(downloadQueueProvider.notifier);
    final created = await notifier.enqueueDownload(
      url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      platform: MediaPlatform.youtube,
      title: 'Test YouTube Video',
      preferredEngine: DownloadEngine.ytDlp,
      qualityLabel: '1080p',
    );

    await _pumpUntil(() {
      final items = container.read(downloadQueueProvider);
      return items.isNotEmpty && items.first.phase == DownloadPhase.completed;
    });

    final done = container.read(downloadQueueProvider).first;
    expect(done.id, created.id);
    expect(done.outputPath, 'Downloads/KlipFetch/YouTube/final.mp4');
    expect(done.contentUri, 'content://media/external/downloads/100');
    expect(done.totalBytes, 8192);
    expect(android.startFgCalls, 1);
    expect(android.exportCalls, 1);
    expect(android.stopFgCalls, greaterThanOrEqualTo(1));
  });

  test('respects maxConcurrentDownloads limit', () async {
    await settingsStorage.save(const AppSettings(maxConcurrentDownloads: 1));
    final firstCompleter = Completer<DownloadOutcome>();
    var firstStarted = false;

    ytdlp.onDownload = (req, _) async {
      if (!firstStarted) {
        firstStarted = true;
        return firstCompleter.future;
      }
      return DownloadOutcome(
        taskId: req.taskId,
        engine: DownloadEngine.ytDlp,
        outputPath: '${req.outputDir}/second.mp4',
      );
    };

    final container = createContainer();
    addTearDown(container.dispose);
    await container.read(settingsProvider.notifier).load();

    final notifier = container.read(downloadQueueProvider.notifier);
    final t1 = await notifier.enqueueDownload(
      url: 'https://www.youtube.com/watch?v=one',
      platform: MediaPlatform.youtube,
      title: 'First',
      preferredEngine: DownloadEngine.ytDlp,
    );
    final t2 = await notifier.enqueueDownload(
      url: 'https://www.youtube.com/watch?v=two',
      platform: MediaPlatform.youtube,
      title: 'Second',
      preferredEngine: DownloadEngine.ytDlp,
    );

    await _pumpUntil(() => firstStarted);
    final itemsWhileBlocked = container.read(downloadQueueProvider);
    final secondWhileBlocked =
        itemsWhileBlocked.firstWhere((e) => e.id == t2.id);
    expect(secondWhileBlocked.phase, DownloadPhase.queued);
    expect(ytdlp.maxObservedConcurrent, 1);

    firstCompleter.complete(
      DownloadOutcome(
        taskId: t1.id,
        engine: DownloadEngine.ytDlp,
        outputPath: '${tempDir.path}/${t1.id}/first.mp4',
      ),
    );

    await _pumpUntil(() {
      final items = container.read(downloadQueueProvider);
      return items.every((e) => e.phase == DownloadPhase.completed);
    });
    expect(ytdlp.maxObservedConcurrent, 1);
    expect(ytdlp.downloadCalls, 2);
  });

  test('retries transient failures and records retryCount when autoRetry is enabled', () async {
    await settingsStorage.save(const AppSettings(autoRetry: true));
    var attempts = 0;
    ytdlp.onDownload = (req, _) async {
      attempts++;
      if (attempts == 1) {
        throw StateError('Temporary network timeout');
      }
      return DownloadOutcome(
        taskId: req.taskId,
        engine: DownloadEngine.ytDlp,
        outputPath: '${req.outputDir}/recovered.mp4',
      );
    };

    final container = createContainer();
    addTearDown(container.dispose);
    await container.read(settingsProvider.notifier).load();

    await container.read(downloadQueueProvider.notifier).enqueueDownload(
          url: 'https://www.youtube.com/watch?v=retry',
          platform: MediaPlatform.youtube,
          title: 'Retry Video',
          preferredEngine: DownloadEngine.ytDlp,
        );

    await _pumpUntil(() {
      final items = container.read(downloadQueueProvider);
      return items.isNotEmpty && items.first.phase == DownloadPhase.completed;
    });

    final item = container.read(downloadQueueProvider).first;
    expect(attempts, 2);
    expect(item.retryCount, 1);
    expect(item.phase, DownloadPhase.completed);
  });

  test('marks cancelled without retrying when user cancels active download', () async {
    final gate = Completer<DownloadOutcome>();
    native.onDownload = (req) => gate.future;

    final container = createContainer();
    addTearDown(container.dispose);

    final notifier = container.read(downloadQueueProvider.notifier);
    final task = await notifier.enqueueDownload(
      url: 'https://www.instagram.com/reel/Cxyz123/',
      platform: MediaPlatform.instagram,
      title: 'IG Reel',
      preferredEngine: DownloadEngine.rustCore,
    );

    await _pumpUntil(() => native.downloadCalls == 1);
    await notifier.cancelTask(task.id);
    gate.completeError(DownloadCancelledException(task.id));

    await _pumpUntil(() {
      final item = container.read(downloadQueueProvider).first;
      return item.phase == DownloadPhase.cancelled;
    });

    expect(ytdlp.downloadCalls, 0);
    expect(android.stopFgCalls, greaterThanOrEqualTo(1));
  });

  test('recovers interrupted downloading tasks on loadPersistedQueue', () async {
    final interrupted = await queueStorage.enqueue(
      url: 'https://www.tiktok.com/@user/video/123',
      platform: MediaPlatform.tiktok,
      title: 'Interrupted TikTok',
      engine: DownloadEngine.rustCore,
    );
    await queueStorage.updateStatus(
      id: interrupted.id,
      phase: DownloadPhase.downloading,
    );

    final container = createContainer();
    addTearDown(container.dispose);
    await container.read(downloadQueueProvider.notifier).loadPersistedQueue();

    await _pumpUntil(() {
      final items = container.read(downloadQueueProvider);
      return items.isNotEmpty && items.first.phase == DownloadPhase.completed;
    });

    final recovered = container.read(downloadQueueProvider).first;
    expect(recovered.id, interrupted.id);
    expect(recovered.outputPath, 'Downloads/KlipFetch/TikTok/final.mp4');
  });

  test('exports multi-file directory via MediaStore and preserves exportedCount', () async {
    android.nextBatchExport = const BatchExportedMedia(
      primaryUri: 'content://media/external/downloads/201',
      primaryDisplayPath: 'Downloads/KlipFetch/Instagram/post_1.mp4',
      fileName: 'post_1.mp4',
      totalSizeBytes: 24576,
      exportedCount: 3,
      displayPaths: [
        'Downloads/KlipFetch/Instagram/post_1.mp4',
        'Downloads/KlipFetch/Instagram/post_2.jpg',
        'Downloads/KlipFetch/Instagram/post_3.jpg',
      ],
    );

    final container = createContainer();
    addTearDown(container.dispose);

    await container.read(downloadQueueProvider.notifier).enqueueDownload(
          url: 'https://www.instagram.com/p/CAROUSEL1/',
          platform: MediaPlatform.instagram,
          title: 'IG Carousel',
          preferredEngine: DownloadEngine.rustCore,
        );

    await _pumpUntil(() {
      final items = container.read(downloadQueueProvider);
      return items.isNotEmpty && items.first.phase == DownloadPhase.completed;
    });

    final done = container.read(downloadQueueProvider).first;
    expect(done.exportedCount, 3);
    expect(done.outputPath, 'Downloads/KlipFetch/Instagram/post_1.mp4');
    expect(done.totalBytes, 24576);
    expect(android.batchExportCalls, 1);
    expect(android.exportCalls, 0);
  });

  test('propagates shared cookiesPath, MKV container, subtitles, and SponsorBlock options', () async {
    native.sharedCookiesPath = '/data/cookies/cookies.txt';
    final container = createContainer();
    addTearDown(container.dispose);

    await container.read(downloadQueueProvider.notifier).enqueueDownload(
          url: 'https://www.youtube.com/watch?v=substest',
          platform: MediaPlatform.youtube,
          title: 'YT With Subs',
          preferredEngine: DownloadEngine.ytDlp,
          formatSelector: 'bv*[height<=1440]+ba/b[height<=1440]/b',
          qualityLabel: '1440p',
          mergeOutputFormat: 'mkv',
          downloadSubtitles: true,
          embedSubtitles: true,
          subtitleLangs: 'en,id',
          sponsorBlockCategories: const ['sponsor', 'selfpromo'],
        );

    await _pumpUntil(() {
      final items = container.read(downloadQueueProvider);
      return items.isNotEmpty && items.first.phase == DownloadPhase.completed;
    });

    final req = ytdlp.lastRequest!;
    expect(req.cookiesPath, '/data/cookies/cookies.txt');
    expect(req.mergeOutputFormat, 'mkv');
    expect(req.downloadSubtitles, isTrue);
    expect(req.embedSubtitles, isTrue);
    expect(req.subtitleLangs, 'en,id');
    expect(req.sponsorBlockCategories, ['sponsor', 'selfpromo']);
  });

  test('enqueues selected playlist items and downloads all within concurrency limit', () async {
    await settingsStorage.save(const AppSettings(maxConcurrentDownloads: 2));
    final container = createContainer();
    addTearDown(container.dispose);
    await container.read(settingsProvider.notifier).load();

    final created = await container
        .read(downloadQueueProvider.notifier)
        .enqueuePlaylistSelection(
          entries: const [
            PlaylistEntry(
              index: 1,
              id: 'ep1',
              title: 'Episode 1',
              url: 'https://www.youtube.com/watch?v=ep1',
            ),
            PlaylistEntry(
              index: 2,
              id: 'ep2',
              title: 'Episode 2',
              url: 'https://www.youtube.com/watch?v=ep2',
            ),
          ],
          preferredEngine: DownloadEngine.ytDlp,
          qualityLabel: '1080p',
          mergeOutputFormat: 'mp4',
        );

    expect(created.length, 2);

    await _pumpUntil(() {
      final items = container.read(downloadQueueProvider);
      return items.length == 2 &&
          items.every((e) => e.phase == DownloadPhase.completed);
    });

    expect(ytdlp.downloadCalls, 2);
    expect(ytdlp.maxObservedConcurrent, lessThanOrEqualTo(2));
  });
}
