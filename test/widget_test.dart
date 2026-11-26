import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipfetch/app/klipfetch_app.dart';
import 'package:klipfetch/models/app_settings.dart';
import 'package:klipfetch/models/download_models.dart';
import 'package:klipfetch/models/media_platform.dart';
import 'package:klipfetch/models/media_probe.dart';
import 'package:klipfetch/services/android_platform_service.dart';
import 'package:klipfetch/services/queue_repository.dart';
import 'package:klipfetch/services/rust_core_service.dart';
import 'package:klipfetch/services/settings_repository.dart';
import 'package:klipfetch/services/ytdlp_service.dart';
import 'package:klipfetch/state/providers.dart';

class _WidgetFakeNativeEngine implements NativeEngineClient {
  @override
  Future<void> init({String? dataDir}) async {}

  @override
  MediaPlatform detectPlatform(String url) => detectMediaPlatform(url);

  @override
  Future<MediaProbeResult> probe(String url) async {
    return MediaProbeResult(
      platform: detectMediaPlatform(url),
      engine: DownloadEngine.rustCore,
      title: 'IG Sample',
      author: 'ig_user',
      mediaType: 'video',
      qualities: const [
        MediaFormatOption(
          formatId: 'best',
          label: 'best',
          width: 1080,
          height: 1920,
          format: 'mp4',
          url: 'https://cdn.example.com/ig.mp4',
        ),
      ],
    );
  }

  @override
  Future<DownloadOutcome> download(
    DownloadRequest request, {
    void Function(DownloadProgressEvent event)? onProgress,
  }) async {
    return DownloadOutcome(
      taskId: request.taskId,
      engine: DownloadEngine.rustCore,
      outputPath: '${request.outputDir}/ig.mp4',
    );
  }

  @override
  Future<bool> cancel(String taskId) async => true;

  @override
  Future<String> saveNetscapeCookies(String domain, String content) async =>
      '/tmp/cookies.txt';

  @override
  Future<void> clearDomainCookies(String domain) async {}
}

class _WidgetFakeYtDlpEngine implements YtDlpEngineClient {
  @override
  Future<String?> init() async => '2026.11.01';

  @override
  Future<String?> getVersion() async => '2026.11.01';

  @override
  Future<String?> updateYtDlp({String channel = 'stable'}) async => 'DONE';

  @override
  Future<MediaProbeResult> probe(String url, {String? cookiesPath}) async {
    return MediaProbeResult(
      platform: MediaPlatform.youtube,
      engine: DownloadEngine.ytDlp,
      title: 'KlipFetch Demo Video',
      author: 'OpenSelena',
      durationSeconds: 95,
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
        MediaFormatOption(
          formatId: 'bv*[height<=720]+ba',
          label: '720p',
          width: 1280,
          height: 720,
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
    return DownloadOutcome(
      taskId: request.taskId,
      engine: DownloadEngine.ytDlp,
      outputPath: '${request.outputDir}/yt.mp4',
      fileSizeBytes: 5120,
    );
  }

  @override
  Future<bool> cancel(String taskId) async => true;
}

class _WidgetFakeAndroidPlatform implements AndroidPlatformClient {
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
  }) async {}

  @override
  Future<void> updateForegroundDownload({
    required String taskId,
    required String title,
    required int progress,
    required int activeCount,
    String? statusText,
  }) async {}

  @override
  Future<void> stopForegroundDownload() async {}

  @override
  Future<ExportedMediaFile?> exportToMediaStore({
    required String stagedFilePath,
    required String platform,
  }) async {
    return const ExportedMediaFile(
      uri: 'content://media/external/downloads/1',
      displayPath: 'Downloads/KlipFetch/YouTube/yt.mp4',
      fileName: 'yt.mp4',
      sizeBytes: 5120,
    );
  }

  @override
  Future<bool> openFile(String uriOrPath) async => true;

  @override
  Future<bool> shareFile(String uriOrPath) async => true;

  @override
  Future<bool> requestNotificationPermission() async => true;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('klipfetch_widget_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget buildTestApp({
    required InMemorySettingsStorage settingsStorage,
    required InMemoryQueueStorage queueStorage,
  }) {
    return ProviderScope(
      overrides: [
        rustCoreServiceProvider.overrideWithValue(_WidgetFakeNativeEngine()),
        ytDlpServiceProvider.overrideWithValue(_WidgetFakeYtDlpEngine()),
        androidPlatformProvider.overrideWithValue(_WidgetFakeAndroidPlatform()),
        queueStorageProvider.overrideWithValue(queueStorage),
        settingsStorageProvider.overrideWithValue(settingsStorage),
        stagingDirProvider.overrideWithValue(() async => tempDir.path),
        ensureDirExistsProvider.overrideWithValue((_) async {}),
        retryDelayProvider.overrideWithValue((_) => Duration.zero),
      ],
      child: const KlipFetchApp(skipPlatformBootstrap: true),
    );
  }

  testWidgets('probes YouTube URL, enqueues download, and shows completed item in History', (tester) async {
    final settingsStorage = InMemorySettingsStorage();
    final queueStorage = InMemoryQueueStorage();
    await tester.pumpWidget(
      buildTestApp(
        settingsStorage: settingsStorage,
        queueStorage: queueStorage,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KlipFetch'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('home_url_input')),
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('home_fetch_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_preview_card')), findsOneWidget);
    expect(find.text('KlipFetch Demo Video'), findsOneWidget);
    expect(find.text('1080p (mp4)'), findsOneWidget);
    expect(find.text('720p (mp4)'), findsOneWidget);

    final downloadButton = find.byKey(const Key('home_download_button'));
    await tester.ensureVisible(downloadButton);
    await tester.pumpAndSettle();
    await tester.tap(downloadButton);
    await tester.pumpAndSettle();

    expect(find.text('View Queue'), findsOneWidget);
    await tester.tap(find.text('View Queue'));
    await tester.pumpAndSettle();

    expect(find.text('History (1)'), findsOneWidget);
    await tester.tap(find.text('History (1)'));
    await tester.pumpAndSettle();

    expect(find.text('KlipFetch Demo Video'), findsOneWidget);
    expect(find.text('Downloads/KlipFetch/YouTube/yt.mp4'), findsOneWidget);
  });

  testWidgets('blocks unsupported URLs and persists Settings changes', (tester) async {
    final settingsStorage = InMemorySettingsStorage();
    final queueStorage = InMemoryQueueStorage();
    await tester.pumpWidget(
      buildTestApp(
        settingsStorage: settingsStorage,
        queueStorage: queueStorage,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('home_url_input')),
      'https://x.com/rustlang/status/123',
    );
    await tester.pump();

    expect(
      find.text('Only TikTok, Instagram, and YouTube are supported.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Light'));
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('2160p'));
    await tester.tap(find.text('2160p'));
    await tester.pumpAndSettle();

    final saved = await settingsStorage.load();
    expect(saved.themeMode, AppThemeMode.light);
    expect(saved.defaultQuality, '2160p');
  });
}
