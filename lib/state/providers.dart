import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';
import '../models/auth_models.dart';
import '../models/download_models.dart';
import '../models/media_platform.dart';
import '../models/media_probe.dart';
import '../models/queue_item.dart';
import '../services/android_platform_service.dart';
import '../services/cookie_service.dart';
import '../services/queue_repository.dart';
import '../services/rust_core_service.dart';
import '../services/settings_repository.dart';
import '../services/url_extractor.dart';
import '../services/url_router_service.dart';
import '../services/ytdlp_service.dart';

final rustCoreServiceProvider = Provider<NativeEngineClient>((ref) {
  return RustCoreService();
});

final ytDlpServiceProvider = Provider<YtDlpEngineClient>((ref) {
  return YtDlpService();
});

final urlRouterProvider = Provider<UrlRouterService>((ref) {
  return UrlRouterService(
    nativeEngine: ref.watch(rustCoreServiceProvider),
    ytDlpEngine: ref.watch(ytDlpServiceProvider),
  );
});

final androidPlatformProvider = Provider<AndroidPlatformClient>((ref) {
  return AndroidPlatformService();
});

final cookieAuthServiceProvider = Provider<CookieAuthService>((ref) {
  return CookieAuthService(
    nativeEngine: ref.watch(rustCoreServiceProvider),
    androidPlatform: ref.watch(androidPlatformProvider),
  );
});

final cookieStatusesProvider = NotifierProvider<CookieStatusesNotifier,
    Map<MediaPlatform, CookieSessionStatus>>(
  CookieStatusesNotifier.new,
);

class CookieStatusesNotifier
    extends Notifier<Map<MediaPlatform, CookieSessionStatus>> {
  @override
  Map<MediaPlatform, CookieSessionStatus> build() {
    return {
      for (final config in AuthPlatformConfig.all)
        config.platform: CookieSessionStatus(
          platform: config.platform,
          domain: config.domain,
        ),
    };
  }

  Future<void> refresh() async {
    final statuses =
        await ref.read(cookieAuthServiceProvider).loadAllStatuses();
    state = statuses;
  }

  Future<CookieSessionStatus?> signIn(MediaPlatform platform) async {
    final status =
        await ref.read(cookieAuthServiceProvider).signInWithBrowser(platform);
    if (status != null) {
      state = {...state, platform: status};
    }
    return status;
  }

  Future<CookieSessionStatus> importNetscape(
    MediaPlatform platform,
    String rawContent,
  ) async {
    final status = await ref
        .read(cookieAuthServiceProvider)
        .importNetscapeCookies(platform, rawContent);
    state = {...state, platform: status};
    return status;
  }

  Future<SessionTestResult> testSession(MediaPlatform platform) async {
    final result =
        await ref.read(cookieAuthServiceProvider).testSession(platform);
    await refresh();
    return result;
  }

  Future<void> clear(MediaPlatform platform) async {
    final status =
        await ref.read(cookieAuthServiceProvider).clearCookies(platform);
    state = {...state, platform: status};
  }
}

final queueStorageProvider = Provider<QueueStorage>((ref) {
  return RustSqliteQueueStorage();
});

final settingsStorageProvider = Provider<SettingsStorage>((ref) {
  return FileSettingsRepository();
});

final stagingDirProvider = Provider<Future<String> Function()>((ref) {
  return () async {
    final cache = await getTemporaryDirectory();
    final staging = Directory('${cache.path}/staging');
    await staging.create(recursive: true);
    return staging.path;
  };
});

final ensureDirExistsProvider = Provider<Future<void> Function(String path)>((ref) {
  return (path) async {
    await Directory(path).create(recursive: true);
  };
});

final retryDelayProvider = Provider<Duration Function(int attempt)>((ref) {
  return (attempt) => Duration(seconds: 2 * attempt);
});

final selectedTabProvider = NotifierProvider<SelectedTabNotifier, int>(
  SelectedTabNotifier.new,
);

class SelectedTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) {
    state = index.clamp(0, 2);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  Future<void> load() async {
    final loaded = await ref.read(settingsStorageProvider).load();
    state = loaded;
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await _update(state.copyWith(themeMode: mode));
  }

  Future<void> setDefaultQuality(String quality) async {
    await _update(state.copyWith(defaultQuality: quality));
  }

  Future<void> setDefaultAudioFormat(String audioFormat) async {
    await _update(state.copyWith(defaultAudioFormat: audioFormat));
  }

  Future<void> setMaxConcurrentDownloads(int count) async {
    await _update(state.copyWith(maxConcurrentDownloads: count));
  }

  Future<void> setAutoRetry(bool enabled) async {
    await _update(state.copyWith(autoRetry: enabled));
  }

  Future<void> setUpdateChannel(String channel) async {
    await _update(state.copyWith(updateChannel: channel));
  }

  Future<void> setDefaultVideoContainer(String container) async {
    await _update(state.copyWith(defaultVideoContainer: container));
  }

  Future<void> setDownloadSubtitles(bool enabled) async {
    await _update(state.copyWith(downloadSubtitles: enabled));
  }

  Future<void> setEmbedSubtitles(bool enabled) async {
    await _update(state.copyWith(embedSubtitles: enabled));
  }

  Future<void> setSubtitleLanguages(String langs) async {
    final cleaned = langs.trim().isEmpty ? 'en,id' : langs.trim();
    await _update(state.copyWith(subtitleLanguages: cleaned));
  }

  Future<void> setSponsorBlockEnabled(bool enabled) async {
    await _update(state.copyWith(sponsorBlockEnabled: enabled));
  }

  Future<void> setTiktokSlideshowIncludeAudio(bool enabled) async {
    await _update(state.copyWith(tiktokSlideshowIncludeAudio: enabled));
  }

  Future<void> _update(AppSettings next) async {
    state = next;
    await ref.read(settingsStorageProvider).save(next);
  }
}

class HomeProbeState {
  const HomeProbeState({
    this.inputUrl = '',
    this.detectedPlatform = MediaPlatform.unsupported,
    this.isProbing = false,
    this.errorMessage,
    this.probeResult,
    this.selectedFormat,
    this.audioOnly = false,
    this.selectedAudioFormat = 'm4a',
    this.videoContainer = 'mp4',
    this.downloadSubtitles = false,
    this.embedSubtitles = true,
    this.sponsorBlockEnabled = false,
    this.tiktokSlideshowIncludeAudio = true,
    this.selectedPlaylistIndices = const {},
  });

  final String inputUrl;
  final MediaPlatform detectedPlatform;
  final bool isProbing;
  final String? errorMessage;
  final MediaProbeResult? probeResult;
  final MediaFormatOption? selectedFormat;
  final bool audioOnly;
  final String selectedAudioFormat;
  final String videoContainer;
  final bool downloadSubtitles;
  final bool embedSubtitles;
  final bool sponsorBlockEnabled;
  final bool tiktokSlideshowIncludeAudio;
  final Set<int> selectedPlaylistIndices;

  HomeProbeState copyWith({
    String? inputUrl,
    MediaPlatform? detectedPlatform,
    bool? isProbing,
    String? errorMessage,
    bool clearError = false,
    MediaProbeResult? probeResult,
    bool clearProbe = false,
    MediaFormatOption? selectedFormat,
    bool clearFormat = false,
    bool? audioOnly,
    String? selectedAudioFormat,
    String? videoContainer,
    bool? downloadSubtitles,
    bool? embedSubtitles,
    bool? sponsorBlockEnabled,
    bool? tiktokSlideshowIncludeAudio,
    Set<int>? selectedPlaylistIndices,
  }) {
    return HomeProbeState(
      inputUrl: inputUrl ?? this.inputUrl,
      detectedPlatform: detectedPlatform ?? this.detectedPlatform,
      isProbing: isProbing ?? this.isProbing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      probeResult: clearProbe ? null : (probeResult ?? this.probeResult),
      selectedFormat:
          clearFormat ? null : (selectedFormat ?? this.selectedFormat),
      audioOnly: audioOnly ?? this.audioOnly,
      selectedAudioFormat: selectedAudioFormat ?? this.selectedAudioFormat,
      videoContainer: videoContainer ?? this.videoContainer,
      downloadSubtitles: downloadSubtitles ?? this.downloadSubtitles,
      embedSubtitles: embedSubtitles ?? this.embedSubtitles,
      sponsorBlockEnabled: sponsorBlockEnabled ?? this.sponsorBlockEnabled,
      tiktokSlideshowIncludeAudio:
          tiktokSlideshowIncludeAudio ?? this.tiktokSlideshowIncludeAudio,
      selectedPlaylistIndices:
          selectedPlaylistIndices ?? this.selectedPlaylistIndices,
    );
  }
}

final homeProbeProvider = NotifierProvider<HomeProbeNotifier, HomeProbeState>(
  HomeProbeNotifier.new,
);

class HomeProbeNotifier extends Notifier<HomeProbeState> {
  @override
  HomeProbeState build() {
    final defaults = ref.read(settingsProvider);
    return HomeProbeState(
      selectedAudioFormat: defaults.defaultAudioFormat,
      videoContainer: defaults.defaultVideoContainer,
      downloadSubtitles: defaults.downloadSubtitles,
      embedSubtitles: defaults.embedSubtitles,
      sponsorBlockEnabled: defaults.sponsorBlockEnabled,
      tiktokSlideshowIncludeAudio: defaults.tiktokSlideshowIncludeAudio,
    );
  }

  void updateUrl(String raw) {
    final trimmed = raw.trim();
    final detected = detectMediaPlatform(trimmed);
    final changed = trimmed != state.inputUrl;
    state = state.copyWith(
      inputUrl: trimmed,
      detectedPlatform: detected,
      clearError: true,
      clearProbe: changed,
      clearFormat: changed,
      selectedPlaylistIndices: changed ? const {} : state.selectedPlaylistIndices,
    );
  }

  void setAudioOnly(bool value) {
    state = state.copyWith(audioOnly: value);
  }

  void setAudioFormat(String format) {
    state = state.copyWith(selectedAudioFormat: format);
  }

  void selectFormat(MediaFormatOption option) {
    state = state.copyWith(selectedFormat: option);
  }

  void setVideoContainer(String container) {
    state = state.copyWith(videoContainer: container);
  }

  void setDownloadSubtitles(bool enabled) {
    state = state.copyWith(downloadSubtitles: enabled);
  }

  void setEmbedSubtitles(bool enabled) {
    state = state.copyWith(embedSubtitles: enabled);
  }

  void setSponsorBlockEnabled(bool enabled) {
    state = state.copyWith(sponsorBlockEnabled: enabled);
  }

  void setTiktokSlideshowIncludeAudio(bool enabled) {
    state = state.copyWith(tiktokSlideshowIncludeAudio: enabled);
  }

  void togglePlaylistEntry(int index) {
    final next = {...state.selectedPlaylistIndices};
    if (!next.remove(index)) {
      next.add(index);
    }
    state = state.copyWith(selectedPlaylistIndices: next);
  }

  void selectAllPlaylistEntries() {
    final entries = state.probeResult?.playlistEntries ?? const [];
    state = state.copyWith(
      selectedPlaylistIndices: {for (final entry in entries) entry.index},
    );
  }

  void clearPlaylistSelection() {
    state = state.copyWith(selectedPlaylistIndices: const {});
  }

  void clear() {
    final defaults = ref.read(settingsProvider);
    state = HomeProbeState(
      selectedAudioFormat: defaults.defaultAudioFormat,
      videoContainer: defaults.defaultVideoContainer,
      downloadSubtitles: defaults.downloadSubtitles,
      embedSubtitles: defaults.embedSubtitles,
      sponsorBlockEnabled: defaults.sponsorBlockEnabled,
      tiktokSlideshowIncludeAudio: defaults.tiktokSlideshowIncludeAudio,
    );
  }

  Future<void> probeCurrentUrl() => probeUrl(state.inputUrl);

  Future<void> probeUrl(String rawUrl) async {
    final url = rawUrl.trim();
    final detected = detectMediaPlatform(url);
    if (url.isEmpty || detected == MediaPlatform.unsupported) {
      state = state.copyWith(
        inputUrl: url,
        detectedPlatform: detected,
        isProbing: false,
        clearProbe: true,
        clearFormat: true,
        selectedPlaylistIndices: const {},
        errorMessage:
            'Only TikTok, Instagram, and YouTube links are supported.',
      );
      return;
    }

    final settings = ref.read(settingsProvider);
    state = state.copyWith(
      inputUrl: url,
      detectedPlatform: detected,
      isProbing: true,
      clearError: true,
      clearProbe: true,
      clearFormat: true,
      selectedPlaylistIndices: const {},
      selectedAudioFormat: settings.defaultAudioFormat,
      videoContainer: settings.defaultVideoContainer,
      downloadSubtitles: settings.downloadSubtitles,
      embedSubtitles: settings.embedSubtitles,
      sponsorBlockEnabled: settings.sponsorBlockEnabled,
      tiktokSlideshowIncludeAudio: settings.tiktokSlideshowIncludeAudio,
    );

    try {
      final cookiesPath =
          await ref.read(cookieAuthServiceProvider).resolveCookiesPath();
      final result = await ref.read(urlRouterProvider).probe(
            url,
            cookiesPath: cookiesPath,
            allowPlaylist: isYouTubePlaylistUrl(url),
          );
      final preferred = pickPreferredFormat(
        result.qualities,
        settings.defaultQuality,
      );
      final initialPlaylistSelection = result.isPlaylist
          ? {for (final entry in result.playlistEntries) entry.index}
          : const <int>{};
      state = state.copyWith(
        isProbing: false,
        probeResult: result,
        selectedFormat: preferred,
        selectedPlaylistIndices: initialPlaylistSelection,
      );
    } catch (e) {
      state = state.copyWith(
        isProbing: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> applySharedText(String rawText) async {
    final extracted = extractSupportedUrlFromText(rawText);
    if (extracted != null) {
      await probeUrl(extracted);
      return true;
    }

    final otherUrl = extractAnyUrlFromText(rawText);
    if (otherUrl != null) {
      state = state.copyWith(
        inputUrl: otherUrl,
        detectedPlatform: MediaPlatform.unsupported,
        clearProbe: true,
        clearFormat: true,
        errorMessage:
            'Only TikTok, Instagram, and YouTube links are supported.',
      );
    }
    return false;
  }

  static MediaFormatOption? pickPreferredFormat(
    List<MediaFormatOption> qualities,
    String preferredQuality,
  ) {
    if (qualities.isEmpty) return null;
    if (preferredQuality == 'best') return qualities.first;

    final targetHeight = int.tryParse(
      preferredQuality.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (targetHeight == null || targetHeight <= 0) {
      return qualities.first;
    }

    for (final option in qualities) {
      if (option.height == targetHeight) return option;
    }

    final underTarget = qualities
        .where((q) => q.height > 0 && q.height <= targetHeight)
        .toList();
    if (underTarget.isNotEmpty) {
      underTarget.sort((a, b) => b.height.compareTo(a.height));
      return underTarget.first;
    }
    return qualities.first;
  }
}

final downloadQueueProvider =
    NotifierProvider<DownloadQueueNotifier, List<QueueItem>>(
  DownloadQueueNotifier.new,
);

class DownloadQueueNotifier extends Notifier<List<QueueItem>> {
  final Set<String> _activeWorkers = <String>{};
  final Set<String> _cancelledIds = <String>{};
  final Map<String, DateTime> _lastFgNotify = <String, DateTime>{};
  bool _disposed = false;

  @override
  List<QueueItem> build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
    });
    return const [];
  }

  Future<void> loadPersistedQueue() async {
    final storage = ref.read(queueStorageProvider);
    final loaded = await storage.list();
    if (_disposed) return;

    final normalized = <QueueItem>[];
    var hasQueuedWork = false;
    for (final item in loaded) {
      if (item.phase == DownloadPhase.downloading ||
          item.phase == DownloadPhase.connecting ||
          item.phase == DownloadPhase.muxing ||
          item.phase == DownloadPhase.saving ||
          item.phase == DownloadPhase.paused) {
        hasQueuedWork = true;
        await storage.updateStatus(id: item.id, phase: DownloadPhase.queued);
        normalized.add(item.copyWith(phase: DownloadPhase.queued, progress: 0));
      } else {
        if (item.phase == DownloadPhase.queued) hasQueuedWork = true;
        normalized.add(item);
      }
    }
    if (_disposed) return;
    state = normalized;
    if (hasQueuedWork) {
      _pumpQueue();
    }
  }

  Future<QueueItem> enqueueDownload({
    required String url,
    required MediaPlatform platform,
    required String title,
    required DownloadEngine preferredEngine,
    String? formatSelector,
    String? qualityLabel,
    bool audioOnly = false,
    String? audioFormat,
    String? mergeOutputFormat,
    bool downloadSubtitles = false,
    bool embedSubtitles = true,
    String? subtitleLangs,
    List<String> sponsorBlockCategories = const [],
  }) async {
    if (platform == MediaPlatform.unsupported) {
      throw UnsupportedPlatformException(url);
    }

    final storage = ref.read(queueStorageProvider);
    final created = await storage.enqueue(
      url: url,
      platform: platform,
      title: title,
      engine: preferredEngine,
      formatSelector: formatSelector,
      qualityLabel: qualityLabel,
      audioOnly: audioOnly,
      audioFormat: audioFormat,
      mergeOutputFormat: mergeOutputFormat,
      downloadSubtitles: downloadSubtitles,
      embedSubtitles: embedSubtitles,
      subtitleLangs: subtitleLangs,
      sponsorBlockCategories: sponsorBlockCategories,
    );
    if (_disposed) return created;

    state = [created, ...state];
    _pumpQueue();
    return created;
  }

  Future<List<QueueItem>> enqueuePlaylistSelection({
    required List<PlaylistEntry> entries,
    required DownloadEngine preferredEngine,
    String? formatSelector,
    String? qualityLabel,
    bool audioOnly = false,
    String? audioFormat,
    String? mergeOutputFormat,
    bool downloadSubtitles = false,
    bool embedSubtitles = true,
    String? subtitleLangs,
    List<String> sponsorBlockCategories = const [],
  }) async {
    final storage = ref.read(queueStorageProvider);
    final createdItems = <QueueItem>[];
    for (final entry in entries) {
      final platform = detectMediaPlatform(entry.url);
      if (platform == MediaPlatform.unsupported) continue;
      final created = await storage.enqueue(
        url: entry.url,
        platform: platform,
        title: entry.title,
        engine: preferredEngine,
        formatSelector: formatSelector,
        qualityLabel: qualityLabel,
        audioOnly: audioOnly,
        audioFormat: audioFormat,
        mergeOutputFormat: mergeOutputFormat,
        downloadSubtitles: downloadSubtitles,
        embedSubtitles: embedSubtitles,
        subtitleLangs: subtitleLangs,
        sponsorBlockCategories: sponsorBlockCategories,
      );
      if (_disposed) return createdItems;
      createdItems.add(created);
    }
    if (createdItems.isNotEmpty) {
      state = [...createdItems.reversed, ...state];
      _pumpQueue();
    }
    return createdItems;
  }

  Future<void> cancelTask(String taskId) async {
    _cancelledIds.add(taskId);
    final index = state.indexWhere((item) => item.id == taskId);
    if (index < 0) return;

    final current = state[index];
    if (current.phase == DownloadPhase.queued ||
        current.phase == DownloadPhase.paused) {
      await _setCancelled(taskId);
      _syncForegroundAfterFinish();
      return;
    }

    if (current.isActive) {
      await ref.read(rustCoreServiceProvider).cancel(taskId);
      await ref.read(ytDlpServiceProvider).cancel(taskId);
      await _setCancelled(taskId);
      _syncForegroundAfterFinish();
    }
  }

  Future<void> retryTask(String taskId) async {
    final index = state.indexWhere((item) => item.id == taskId);
    if (index < 0) return;

    _cancelledIds.remove(taskId);
    await ref.read(queueStorageProvider).updateStatus(
          id: taskId,
          phase: DownloadPhase.queued,
        );
    if (_disposed) return;

    _replaceItem(
      taskId,
      (item) => item.copyWith(
        phase: DownloadPhase.queued,
        progress: 0.0,
        clearError: true,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _pumpQueue();
  }

  Future<void> deleteTask(String taskId) async {
    final existing = state.where((item) => item.id == taskId).firstOrNull;
    if (existing != null && existing.isActive) {
      await cancelTask(taskId);
    }
    await ref.read(queueStorageProvider).delete(taskId);
    if (_disposed) return;
    state = state.where((item) => item.id != taskId).toList(growable: false);
  }

  Future<void> clearFinished() async {
    final finishedIds = state
        .where((item) => item.isFinished)
        .map((item) => item.id)
        .toList();
    final storage = ref.read(queueStorageProvider);
    for (final id in finishedIds) {
      await storage.delete(id);
    }
    if (_disposed) return;
    state = state.where((item) => !item.isFinished).toList(growable: false);
  }

  void _pumpQueue() {
    if (_disposed) return;
    final maxConcurrent = ref.read(settingsProvider).maxConcurrentDownloads;

    while (_activeWorkers.length < maxConcurrent) {
      QueueItem? nextQueued;
      for (var i = state.length - 1; i >= 0; i--) {
        if (state[i].phase == DownloadPhase.queued &&
            !_activeWorkers.contains(state[i].id)) {
          nextQueued = state[i];
          break;
        }
      }
      if (nextQueued == null) break;

      _activeWorkers.add(nextQueued.id);
      _replaceItem(
        nextQueued.id,
        (item) => item.copyWith(
          phase: DownloadPhase.connecting,
          clearError: true,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      unawaited(_executeTask(nextQueued.id));
    }
  }

  Future<void> _executeTask(String taskId) async {
    final router = ref.read(urlRouterProvider);
    final storage = ref.read(queueStorageProvider);
    final platformClient = ref.read(androidPlatformProvider);
    final settings = ref.read(settingsProvider);
    final retryDelay = ref.read(retryDelayProvider);

    try {
      final snapshot = state.where((e) => e.id == taskId).firstOrNull;
      if (snapshot == null || _cancelledIds.contains(taskId)) {
        await _setCancelled(taskId);
        return;
      }

      await storage.updateStatus(id: taskId, phase: DownloadPhase.downloading);
      if (_disposed) return;

      final activeCount = state.where((e) => e.isActive).length.clamp(1, 99);
      await platformClient.startForegroundDownload(
        taskId: taskId,
        title: snapshot.title,
        progress: -1,
        activeCount: activeCount,
        statusText: 'Connecting...',
      );

      final stagingRoot = await ref.read(stagingDirProvider)();
      final taskStagingDir = '$stagingRoot/$taskId';
      await ref.read(ensureDirExistsProvider)(taskStagingDir);
      final cookiesPath =
          await ref.read(cookieAuthServiceProvider).resolveCookiesPath();

      final request = DownloadRequest(
        taskId: taskId,
        url: snapshot.url,
        outputDir: taskStagingDir,
        formatSelector: snapshot.formatSelector,
        quality: snapshot.qualityLabel,
        audioOnly: snapshot.audioOnly,
        audioFormat: snapshot.audioFormat,
        cookiesPath: cookiesPath,
        mergeOutputFormat: snapshot.mergeOutputFormat,
        downloadSubtitles: snapshot.downloadSubtitles,
        embedSubtitles: snapshot.embedSubtitles,
        subtitleLangs: snapshot.subtitleLangs,
        sponsorBlockCategories: snapshot.sponsorBlockCategories,
      );

      final maxAttempts = settings.autoRetry ? 3 : 1;
      DownloadOutcome? outcome;
      Object? lastError;

      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        if (_disposed || _cancelledIds.contains(taskId)) {
          await _setCancelled(taskId);
          return;
        }

        _replaceItem(
          taskId,
          (item) => item.copyWith(
            phase: DownloadPhase.downloading,
            retryCount: attempt - 1,
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );

        try {
          outcome = await router.download(
            request,
            onProgress: (event) => _handleProgress(taskId, event),
          );
          break;
        } on DownloadCancelledException {
          await _setCancelled(taskId);
          return;
        } on UnsupportedPlatformException catch (e) {
          lastError = e;
          break;
        } catch (e) {
          lastError = e;
          if (_cancelledIds.contains(taskId)) {
            await _setCancelled(taskId);
            return;
          }
          if (attempt < maxAttempts) {
            final delay = retryDelay(attempt);
            if (delay > Duration.zero) {
              await Future<void>.delayed(delay);
            }
          }
        }
      }

      if (_disposed) return;
      if (_cancelledIds.contains(taskId)) {
        await _setCancelled(taskId);
        return;
      }

      if (outcome == null) {
        final msg = (lastError ?? 'Download failed').toString();
        await storage.updateStatus(
          id: taskId,
          phase: DownloadPhase.failed,
          errorMessage: msg,
        );
        if (_disposed) return;
        _replaceItem(
          taskId,
          (item) => item.copyWith(
            phase: DownloadPhase.failed,
            errorMessage: msg,
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        return;
      }

      String? finalOutputPath = outcome.outputPath;
      String? contentUri;
      int? finalSize = outcome.fileSizeBytes;
      var exportedCount = 1;

      _replaceItem(
        taskId,
        (item) => item.copyWith(
          phase: DownloadPhase.saving,
          progress: 100.0,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      final batchExported = await platformClient.exportStagingDirectory(
        stagingDirPath: taskStagingDir,
        platform: snapshot.platform.name,
      );
      if (batchExported != null) {
        finalOutputPath = batchExported.primaryDisplayPath;
        contentUri = batchExported.primaryUri;
        if (batchExported.totalSizeBytes > 0) {
          finalSize = batchExported.totalSizeBytes;
        }
        exportedCount = batchExported.exportedCount;
      } else if (finalOutputPath != null &&
          finalOutputPath.isNotEmpty &&
          finalOutputPath != taskStagingDir) {
        final exported = await platformClient.exportToMediaStore(
          stagedFilePath: finalOutputPath,
          platform: snapshot.platform.name,
        );
        if (exported != null) {
          finalOutputPath = exported.displayPath;
          contentUri = exported.uri;
          if (exported.sizeBytes > 0) {
            finalSize = exported.sizeBytes;
          }
        }
      }

      await storage.updateStatus(
        id: taskId,
        phase: DownloadPhase.completed,
        outputPath: finalOutputPath,
      );
      if (_disposed) return;

      _replaceItem(
        taskId,
        (item) => item.copyWith(
          engine: outcome!.engine,
          usedFallback: outcome.usedFallback,
          phase: DownloadPhase.completed,
          progress: 100.0,
          outputPath: finalOutputPath,
          contentUri: contentUri,
          exportedCount: exportedCount,
          totalBytes: finalSize,
          clearError: true,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } finally {
      _activeWorkers.remove(taskId);
      _cancelledIds.remove(taskId);
      _lastFgNotify.remove(taskId);
      if (!_disposed) {
        await _syncForegroundAfterFinish();
        _pumpQueue();
      }
    }
  }

  void _handleProgress(String taskId, DownloadProgressEvent event) {
    if (_disposed || _cancelledIds.contains(taskId)) return;

    final phase = switch (event.phase) {
      'muxing' => DownloadPhase.muxing,
      'saving' => DownloadPhase.saving,
      _ => DownloadPhase.downloading,
    };

    _replaceItem(
      taskId,
      (item) => item.copyWith(
        engine: event.engine,
        phase: phase,
        progress: event.percent.clamp(0.0, 100.0),
        downloadedBytes: event.downloadedBytes,
        totalBytes: event.totalBytes,
        speedBps: event.speedBps,
        etaSeconds: event.etaSeconds,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    final now = DateTime.now();
    final last = _lastFgNotify[taskId];
    if (last == null || now.difference(last).inMilliseconds >= 350) {
      _lastFgNotify[taskId] = now;
      final item = state.where((e) => e.id == taskId).firstOrNull;
      if (item != null) {
        final activeCount = state.where((e) => e.isActive).length.clamp(1, 99);
        final pct = item.progress.round();
        unawaited(
          ref.read(androidPlatformProvider).updateForegroundDownload(
                taskId: taskId,
                title: item.title,
                progress: pct,
                activeCount: activeCount,
                statusText: '${item.phase.label} · $pct%',
              ),
        );
      }
    }
  }

  Future<void> _setCancelled(String taskId) async {
    await ref
        .read(queueStorageProvider)
        .updateStatus(id: taskId, phase: DownloadPhase.cancelled);
    if (_disposed) return;
    _replaceItem(
      taskId,
      (item) => item.copyWith(
        phase: DownloadPhase.cancelled,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> _syncForegroundAfterFinish() async {
    if (_disposed) return;
    final activeItems = state.where((e) => e.isActive).toList();
    final platformClient = ref.read(androidPlatformProvider);
    if (activeItems.isEmpty) {
      await platformClient.stopForegroundDownload();
    } else {
      final first = activeItems.first;
      await platformClient.updateForegroundDownload(
        taskId: first.id,
        title: first.title,
        progress: first.progress.round(),
        activeCount: activeItems.length,
        statusText: '${first.phase.label} · ${first.progress.round()}%',
      );
    }
  }

  void _replaceItem(
    String taskId,
    QueueItem Function(QueueItem current) transform,
  ) {
    final index = state.indexWhere((item) => item.id == taskId);
    if (index < 0) return;
    final copy = [...state];
    copy[index] = transform(copy[index]);
    state = copy;
  }
}
