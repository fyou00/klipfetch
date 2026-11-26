import 'dart:async';

import 'package:flutter/services.dart';

class ExportedMediaFile {
  const ExportedMediaFile({
    required this.uri,
    required this.displayPath,
    required this.fileName,
    required this.sizeBytes,
  });

  final String uri;
  final String displayPath;
  final String fileName;
  final int sizeBytes;
}

abstract interface class AndroidPlatformClient {
  Future<String?> getInitialSharedText();
  Stream<String> get sharedTextStream;
  Stream<String> get notificationCancelStream;

  Future<void> startForegroundDownload({
    required String taskId,
    required String title,
    required int progress,
    required int activeCount,
    String? statusText,
  });

  Future<void> updateForegroundDownload({
    required String taskId,
    required String title,
    required int progress,
    required int activeCount,
    String? statusText,
  });

  Future<void> stopForegroundDownload();

  Future<ExportedMediaFile?> exportToMediaStore({
    required String stagedFilePath,
    required String platform,
  });

  Future<bool> openFile(String uriOrPath);
  Future<bool> shareFile(String uriOrPath);
  Future<bool> requestNotificationPermission();
}

class AndroidPlatformService implements AndroidPlatformClient {
  AndroidPlatformService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel =
            methodChannel ?? const MethodChannel(_methodChannelName),
        _eventChannel = eventChannel ?? const EventChannel(_eventChannelName);

  static const _methodChannelName = 'io.github.fyou00.klipfetch/platform';
  static const _eventChannelName =
      'io.github.fyou00.klipfetch/platform_events';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<Map<dynamic, dynamic>>? _rawEvents;

  Stream<Map<dynamic, dynamic>> _events() {
    _rawEvents ??= _eventChannel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .cast<Map<dynamic, dynamic>>()
        .asBroadcastStream();
    return _rawEvents!;
  }

  @override
  Future<String?> getInitialSharedText() async {
    try {
      return await _methodChannel.invokeMethod<String>('getInitialSharedText');
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Stream<String> get sharedTextStream => _events()
      .where((e) => e['type'] == 'shared_text' && e['text'] is String)
      .map((e) => e['text'] as String);

  @override
  Stream<String> get notificationCancelStream => _events()
      .where((e) => e['type'] == 'notification_cancel' && e['taskId'] is String)
      .map((e) => e['taskId'] as String);

  @override
  Future<void> startForegroundDownload({
    required String taskId,
    required String title,
    required int progress,
    required int activeCount,
    String? statusText,
  }) async {
    try {
      await _methodChannel.invokeMethod<bool>('startForegroundDownload', {
        'taskId': taskId,
        'title': title,
        'progress': progress,
        'activeCount': activeCount,
        'statusText': statusText,
      });
    } on MissingPluginException {
      // Non-Android / unit test fallback.
    }
  }

  @override
  Future<void> updateForegroundDownload({
    required String taskId,
    required String title,
    required int progress,
    required int activeCount,
    String? statusText,
  }) async {
    try {
      await _methodChannel.invokeMethod<bool>('updateForegroundDownload', {
        'taskId': taskId,
        'title': title,
        'progress': progress,
        'activeCount': activeCount,
        'statusText': statusText,
      });
    } on MissingPluginException {
      // Non-Android / unit test fallback.
    }
  }

  @override
  Future<void> stopForegroundDownload() async {
    try {
      await _methodChannel.invokeMethod<bool>('stopForegroundDownload');
    } on MissingPluginException {
      // Non-Android / unit test fallback.
    }
  }

  @override
  Future<ExportedMediaFile?> exportToMediaStore({
    required String stagedFilePath,
    required String platform,
  }) async {
    try {
      final result = await _methodChannel
          .invokeMethod<Map<dynamic, dynamic>>('exportToMediaStore', {
        'stagedFilePath': stagedFilePath,
        'platform': platform,
      });
      if (result == null) return null;
      return ExportedMediaFile(
        uri: (result['uri'] as String?) ?? stagedFilePath,
        displayPath: (result['displayPath'] as String?) ?? stagedFilePath,
        fileName: (result['fileName'] as String?) ?? '',
        sizeBytes: (result['sizeBytes'] as num?)?.toInt() ?? 0,
      );
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> openFile(String uriOrPath) async {
    try {
      return await _methodChannel.invokeMethod<bool>('openFile', {
            'uriOrPath': uriOrPath,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> shareFile(String uriOrPath) async {
    try {
      return await _methodChannel.invokeMethod<bool>('shareFile', {
            'uriOrPath': uriOrPath,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> requestNotificationPermission() async {
    try {
      return await _methodChannel
              .invokeMethod<bool>('requestNotificationPermission') ??
          false;
    } on MissingPluginException {
      return true;
    }
  }
}
