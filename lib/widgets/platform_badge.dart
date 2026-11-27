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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: compact ? 12 : 14,
          decoration: BoxDecoration(
            color: tone.ink,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          platform.displayName,
          style: TextStyle(
            fontFamily: KlipFetchTheme.bodyFontFamily,
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: KlipFetchTheme.lightInk,
          ),
        ),
      ],
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
    final isFallback = engine == DownloadEngine.ytDlp && usedFallback;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: tone.fill,
        borderRadius: BorderRadius.circular(2),
        border: isFallback ? null : Border.all(color: tone.border),
      ),
      child: Text(
        label,
        style: isFallback
            ? TextStyle(
                fontFamily: KlipFetchTheme.bodyFontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tone.ink,
              )
            : KlipFetchTheme.monoStyle(
                size: 11,
                height: 1.2,
                color: tone.ink,
              ),
      ),
    );
  }
}

class EditorialStatusTag extends StatelessWidget {
  const EditorialStatusTag({
    super.key,
    required this.label,
    this.tone = KlipFetchTheme.neutralTone,
    this.outlined = false,
  });

  final String label;
  final BadgeTone tone;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: tone.fill,
        borderRadius: BorderRadius.circular(2),
        border: outlined ? Border.all(color: tone.border) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: KlipFetchTheme.bodyFontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: tone.ink,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
