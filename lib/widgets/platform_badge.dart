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
    final color = KlipFetchTheme.platformColor(platform);
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
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 15, color: color),
          const SizedBox(width: 5),
          Text(
            platform.displayName,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: color,
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
    final scheme = Theme.of(context).colorScheme;
    final label = switch ((engine, usedFallback)) {
      (DownloadEngine.rustCore, _) => 'Rust Core',
      (DownloadEngine.ytDlp, true) => 'yt-dlp fallback',
      (DownloadEngine.ytDlp, false) => 'yt-dlp',
    };
    final color = engine == DownloadEngine.rustCore
        ? const Color(0xFFF78166)
        : (usedFallback ? const Color(0xFFD29922) : scheme.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
