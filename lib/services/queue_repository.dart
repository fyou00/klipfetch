import '../models/media_platform.dart';
import '../models/media_probe.dart';
import '../models/queue_item.dart';
import '../src/rust/api/queue.dart' as rust_queue;

abstract interface class QueueStorage {
  Future<QueueItem> enqueue({
    required String url,
    required MediaPlatform platform,
    required String title,
    required DownloadEngine engine,
    String? formatSelector,
    String? qualityLabel,
    bool audioOnly = false,
    String? audioFormat,
    String? mergeOutputFormat,
    bool downloadSubtitles = false,
    bool embedSubtitles = true,
    String? subtitleLangs,
    List<String> sponsorBlockCategories = const [],
  });

  Future<List<QueueItem>> list();

  Future<bool> updateStatus({
    required String id,
    required DownloadPhase phase,
    String? outputPath,
    String? errorMessage,
  });

  Future<bool> delete(String id);
}

class RustSqliteQueueStorage implements QueueStorage {
  @override
  Future<QueueItem> enqueue({
    required String url,
    required MediaPlatform platform,
    required String title,
    required DownloadEngine engine,
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
    final record = await rust_queue.enqueueTask(
      url: url,
      platform: platform.name,
      title: title,
      engine: engine == DownloadEngine.rustCore ? 'rust_core' : 'yt_dlp',
    );
    return _fromRecord(
      record,
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
  }

  @override
  Future<List<QueueItem>> list() async {
    final records = await rust_queue.listTasks();
    return records.map(_fromRecord).toList(growable: false);
  }

  @override
  Future<bool> updateStatus({
    required String id,
    required DownloadPhase phase,
    String? outputPath,
    String? errorMessage,
  }) {
    return rust_queue.updateTaskStatus(
      id: id,
      status: _toRustStatus(phase),
      outputPath: outputPath,
      errorMessage: errorMessage,
    );
  }

  @override
  Future<bool> delete(String id) {
    return rust_queue.deleteTask(id: id);
  }

  static QueueItem _fromRecord(
    rust_queue.QueueTaskRecord record, {
    String? formatSelector,
    String? qualityLabel,
    bool audioOnly = false,
    String? audioFormat,
    String? mergeOutputFormat,
    bool downloadSubtitles = false,
    bool embedSubtitles = true,
    String? subtitleLangs,
    List<String> sponsorBlockCategories = const [],
  }) {
    return QueueItem(
      id: record.id,
      url: record.url,
      platform: _parsePlatform(record.platform),
      title: record.title,
      engine: record.engine == 'rust_core'
          ? DownloadEngine.rustCore
          : DownloadEngine.ytDlp,
      phase: _fromRustStatus(record.status),
      createdAtMs: record.createdAt.toInt(),
      updatedAtMs: record.updatedAt.toInt(),
      progress: record.status == rust_queue.QueueTaskStatus.completed
          ? 100.0
          : 0.0,
      formatSelector: formatSelector,
      qualityLabel: qualityLabel,
      audioOnly: audioOnly,
      audioFormat: audioFormat,
      mergeOutputFormat: mergeOutputFormat,
      downloadSubtitles: downloadSubtitles,
      embedSubtitles: embedSubtitles,
      subtitleLangs: subtitleLangs,
      sponsorBlockCategories: sponsorBlockCategories,
      outputPath: record.outputPath,
      errorMessage: record.errorMessage,
    );
  }

  static MediaPlatform _parsePlatform(String raw) {
    switch (raw.toLowerCase()) {
      case 'tiktok':
        return MediaPlatform.tiktok;
      case 'instagram':
        return MediaPlatform.instagram;
      case 'youtube':
        return MediaPlatform.youtube;
      default:
        return MediaPlatform.unsupported;
    }
  }

  static DownloadPhase _fromRustStatus(rust_queue.QueueTaskStatus status) {
    switch (status) {
      case rust_queue.QueueTaskStatus.queued:
        return DownloadPhase.queued;
      case rust_queue.QueueTaskStatus.downloading:
        return DownloadPhase.downloading;
      case rust_queue.QueueTaskStatus.paused:
        return DownloadPhase.paused;
      case rust_queue.QueueTaskStatus.completed:
        return DownloadPhase.completed;
      case rust_queue.QueueTaskStatus.failed:
        return DownloadPhase.failed;
      case rust_queue.QueueTaskStatus.cancelled:
        return DownloadPhase.cancelled;
    }
  }

  static rust_queue.QueueTaskStatus _toRustStatus(DownloadPhase phase) {
    switch (phase) {
      case DownloadPhase.queued:
      case DownloadPhase.connecting:
        return rust_queue.QueueTaskStatus.queued;
      case DownloadPhase.downloading:
      case DownloadPhase.muxing:
      case DownloadPhase.saving:
        return rust_queue.QueueTaskStatus.downloading;
      case DownloadPhase.paused:
        return rust_queue.QueueTaskStatus.paused;
      case DownloadPhase.completed:
        return rust_queue.QueueTaskStatus.completed;
      case DownloadPhase.failed:
        return rust_queue.QueueTaskStatus.failed;
      case DownloadPhase.cancelled:
        return rust_queue.QueueTaskStatus.cancelled;
    }
  }
}

class InMemoryQueueStorage implements QueueStorage {
  final List<QueueItem> _items = [];
  int _counter = 0;

  @override
  Future<QueueItem> enqueue({
    required String url,
    required MediaPlatform platform,
    required String title,
    required DownloadEngine engine,
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
    _counter++;
    final now = DateTime.now().millisecondsSinceEpoch;
    final item = QueueItem(
      id: 'task_$_counter',
      url: url,
      platform: platform,
      title: title,
      engine: engine,
      phase: DownloadPhase.queued,
      createdAtMs: now,
      updatedAtMs: now,
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
    _items.insert(0, item);
    return item;
  }

  @override
  Future<List<QueueItem>> list() async => List.unmodifiable(_items);

  @override
  Future<bool> updateStatus({
    required String id,
    required DownloadPhase phase,
    String? outputPath,
    String? errorMessage,
  }) async {
    final index = _items.indexWhere((element) => element.id == id);
    if (index < 0) return false;
    _items[index] = _items[index].copyWith(
      phase: phase,
      outputPath: outputPath,
      errorMessage: errorMessage,
      clearError: errorMessage == null,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    return true;
  }

  @override
  Future<bool> delete(String id) async {
    final before = _items.length;
    _items.removeWhere((element) => element.id == id);
    return _items.length < before;
  }
}
