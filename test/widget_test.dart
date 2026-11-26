import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipfetch/app/klipfetch_app.dart';
import 'package:klipfetch/models/app_settings.dart';
import 'package:klipfetch/models/auth_models.dart';
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
  final Map<String, String> cookieStore = {};
  bool failNextProbeWithAuthError = false;

  @override
  Future<void> init({String? dataDir}) async {}

  @override
  MediaPlatform detectPlatform(String url) => detectMediaPlatform(url);

  @override
  Future<MediaProbeResult> probe(String url) async {
    if (failNextProbeWithAuthError) {
      failNextProbeWithAuthError = false;
      throw StateError('Login cookies required to access this private post.');
    }

    final platform = detectMediaPlatform(url);
    if (platform == MediaPlatform.tiktok && url.contains('/photo/')) {
      return const MediaProbeResult(
        platform: MediaPlatform.tiktok,
        engine: DownloadEngine.rustCore,
        title: 'TikTok Photo Slideshow',
        author: 'photo_creator',
        mediaType: 'carousel',
        qualities: [
          MediaFormatOption(
            formatId: 'photo_1',
            label: 'photo_1',
            width: 0,
            height: 0,
            format: 'jpg',
            url: 'https://cdn.example.com/slide1.jpg',
          ),
          MediaFormatOption(
            formatId: 'photo_2',
            label: 'photo_2',
            width: 0,
            height: 0,
            format: 'jpg',
            url: 'https://cdn.example.com/slide2.jpg',
          ),
          MediaFormatOption(
            formatId: 'slideshow_audio',
            label: 'slideshow_audio',
            width: 0,
            height: 0,
            format: 'mp3',
            url: 'https://cdn.example.com/music.mp3',
          ),
        ],
      );
    }

    return MediaProbeResult(
      platform: platform,
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
  Future<String> saveNetscapeCookies(String domain, String content) async {
    cookieStore[domain] = content;
    return '/tmp/cookies/cookies.txt';
  }

  @override
  Future<void> clearDomainCookies(String domain) async {
    cookieStore.remove(domain);
  }

  @override
  Future<CookieDomainStatusInfo> getCookieDomainStatus(String domain) async {
    final stored = cookieStore[domain];
    if (stored == null || stored.trim().isEmpty) {
      return CookieDomainStatusInfo(
        domain: domain,
        hasCookies: false,
        cookieCount: 0,
        hasAuthCookie: false,
      );
    }
    final lines = stored
        .split('\n')
        .where((l) => l.trim().isNotEmpty && !l.trim().startsWith('# Netscape'))
        .toList();
    final hasAuth =
        stored.contains('sessionid') || stored.contains('SAPISID');
    return CookieDomainStatusInfo(
      domain: domain,
      hasCookies: lines.isNotEmpty,
      cookieCount: lines.length,
      hasAuthCookie: hasAuth,
      updatedAtMs: 1732600000000,
    );
  }

  @override
  Future<String?> getSharedCookiesPath() async =>
      cookieStore.isEmpty ? null : '/tmp/cookies/cookies.txt';
}

class _WidgetFakeYtDlpEngine implements YtDlpEngineClient {
  bool failNextProbeWithAuthError = false;

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
    if (failNextProbeWithAuthError) {
      failNextProbeWithAuthError = false;
      throw StateError('Login cookies required to access this private post.');
    }

    if (allowPlaylist && url.contains('playlist')) {
      return const MediaProbeResult(
        platform: MediaPlatform.youtube,
        engine: DownloadEngine.ytDlp,
        title: 'Phase 3 Playlist Demo',
        author: 'OpenSelena',
        mediaType: 'playlist',
        qualities: [
          MediaFormatOption(
            formatId: 'bv*[height<=1080]+ba/b[height<=1080]/b',
            label: '1080p',
            width: 1920,
            height: 1080,
            format: 'mp4',
            url: 'https://www.youtube.com/playlist?list=PL3',
          ),
        ],
        playlistEntries: [
          PlaylistEntry(
            index: 1,
            id: 'ep1',
            title: 'Episode One',
            url: 'https://www.youtube.com/watch?v=ep1',
          ),
          PlaylistEntry(
            index: 2,
            id: 'ep2',
            title: 'Episode Two',
            url: 'https://www.youtube.com/watch?v=ep2',
          ),
        ],
      );
    }

    return const MediaProbeResult(
      platform: MediaPlatform.youtube,
      engine: DownloadEngine.ytDlp,
      title: 'KlipFetch Demo Video',
      author: 'OpenSelena',
      durationSeconds: 95,
      mediaType: 'video',
      availableSubtitles: ['en', 'id'],
      qualities: [
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
  Future<BatchExportedMedia?> exportStagingDirectory({
    required String stagingDirPath,
    required String platform,
  }) async =>
      null;

  @override
  Future<AuthBrowserCapture> openAuthBrowser({
    required String platform,
    required String loginUrl,
    required List<String> cookieUrls,
    required List<String> authCookieNames,
  }) async {
    return const AuthBrowserCapture(
      cancelled: false,
      netscapeCookies:
          '# Netscape HTTP Cookie File\n#HttpOnly_.instagram.com\tTRUE\t/\tTRUE\t2147483647\tsessionid\tcaptured_secret\n',
      cookieCount: 1,
      hasAuthCookie: true,
    );
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

void main() {
  late Directory tempDir;
  late _WidgetFakeNativeEngine native;
  late _WidgetFakeYtDlpEngine ytdlp;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('klipfetch_widget_');
    native = _WidgetFakeNativeEngine();
    ytdlp = _WidgetFakeYtDlpEngine();
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
        rustCoreServiceProvider.overrideWithValue(native),
        ytDlpServiceProvider.overrideWithValue(ytdlp),
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

    expect(find.text('System'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(
      find.byKey(const Key('settings_theme_locked_caption')),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Dark'));
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('2160p'));
    await tester.tap(find.text('2160p'));
    await tester.pumpAndSettle();

    final saved = await settingsStorage.load();
    expect(saved.themeMode, AppThemeMode.light);
    expect(saved.defaultQuality, '2160p');
  });

  testWidgets('manages Instagram session cookies via Settings -> Accounts & Cookies', (tester) async {
    final settingsStorage = InMemorySettingsStorage();
    final queueStorage = InMemoryQueueStorage();
    await tester.pumpWidget(
      buildTestApp(
        settingsStorage: settingsStorage,
        queueStorage: queueStorage,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final accountsTile = find.byKey(const Key('settings_accounts_tile'));
    await tester.ensureVisible(accountsTile);
    await tester.pumpAndSettle();
    await tester.tap(accountsTile);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_card_instagram')), findsOneWidget);
    expect(find.byKey(const Key('auth_card_tiktok')), findsOneWidget);
    expect(find.byKey(const Key('auth_card_youtube')), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth_signin_instagram')));
    await tester.pumpAndSettle();
    expect(find.text('Connected'), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth_test_instagram')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Instagram session active'), findsOneWidget);

    final clearBtn = find.byKey(const Key('auth_clear_instagram'));
    await tester.ensureVisible(clearBtn);
    await tester.pumpAndSettle();
    await tester.tap(clearBtn);
    await tester.pumpAndSettle();
    expect(find.text('Connected'), findsNothing);
  });

  testWidgets('renders YouTube playlist picker, subtitles, SponsorBlock, and TikTok slideshow options', (tester) async {
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
      'https://www.youtube.com/playlist?list=PL3',
    );
    await tester.tap(find.byKey(const Key('home_fetch_button')));
    await tester.pumpAndSettle();

    expect(find.text('Playlist (2 videos)'), findsOneWidget);
    expect(find.byKey(const Key('home_subtitles_switch')), findsOneWidget);
    expect(find.byKey(const Key('home_sponsorblock_switch')), findsOneWidget);

    final ep2Tile = find.byKey(const Key('playlist_entry_2'));
    await tester.ensureVisible(ep2Tile);
    await tester.pumpAndSettle();
    await tester.tap(ep2Tile);
    await tester.pumpAndSettle();

    expect(find.text('Download 1 Selected'), findsOneWidget);

    final downloadBtn = find.byKey(const Key('home_download_button'));
    await tester.ensureVisible(downloadBtn);
    await tester.pumpAndSettle();
    await tester.tap(downloadBtn);
    await tester.pumpAndSettle();
    expect(find.text('Queued 1 playlist items'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, 800));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('home_url_input')),
      'https://www.tiktok.com/@creator/photo/712345',
    );
    await tester.tap(find.byKey(const Key('home_fetch_button')));
    await tester.pumpAndSettle();

    expect(find.text('Slideshow (2 photos)'), findsOneWidget);
    final slideshowAudioSwitch =
        find.byKey(const Key('home_tiktok_slideshow_audio_switch'));
    await tester.ensureVisible(slideshowAudioSwitch);
    await tester.pumpAndSettle();
    expect(slideshowAudioSwitch, findsOneWidget);
  });

  testWidgets('offers quick Sign In shortcut when private/auth probe error occurs', (tester) async {
    native.failNextProbeWithAuthError = true;
    ytdlp.failNextProbeWithAuthError = true;
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
      'https://www.instagram.com/p/PRIVATE123/',
    );
    await tester.tap(find.byKey(const Key('home_fetch_button')));
    await tester.pumpAndSettle();

    final authBtn = find.byKey(const Key('home_auth_error_button'));
    await tester.ensureVisible(authBtn);
    await tester.pumpAndSettle();
    expect(authBtn, findsOneWidget);
    await tester.tap(authBtn);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth_card_instagram')), findsOneWidget);
  });
}
