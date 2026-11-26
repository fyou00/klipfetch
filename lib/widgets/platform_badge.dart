import 'package:flutter/material.dart';

import '../models/media_platform.dart';
import '../models/media_probe.dart';
import '../theme/app_theme.dart';

class PlatformBadge extends StatelessWidget {
  const PlatformBadge({
    super.key,
    required this.platform,
    this.compact = false,
  });

  final MediaPlatform platform;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tone = KlipFetchTheme.platformTone(platform);
    final icon = switch (platform) {
      MediaPlatform.tiktok => Icons.music_note_rounded,
      MediaPlatform.instagram => Icons.photo_camera_outlined,
      MediaPlatform.youtube => Icons.play_arrow_rounded,
      MediaPlatform.unsupported => Icons.block_rounded,
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: tone.fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 15, color: tone.ink),
          const SizedBox(width: 5),
          Text(
            platform.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tone.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class EngineBadge extends StatelessWidget {
  const EngineBadge({
    super.key,
    required this.engine,
    this.usedFallback = false,
  });

  final DownloadEngine engine;
  final bool usedFallback;

  @override
  Widget build(BuildContext context) {
    final label = switch ((engine, usedFallback)) {
      (DownloadEngine.rustCore, _) => 'Rust Core',
      (DownloadEngine.ytDlp, true) => 'yt-dlp fallback',
      (DownloadEngine.ytDlp, false) => 'yt-dlp',
    };
    final tone = KlipFetchTheme.engineTone(
      engine,
      usedFallback: usedFallback,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: tone.ink,
        ),
      ),
    );
  }
}
