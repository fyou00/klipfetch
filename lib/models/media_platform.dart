enum MediaPlatform {
  tiktok,
  instagram,
  youtube,
  unsupported;

  String get displayName {
    switch (this) {
      case MediaPlatform.tiktok:
        return 'TikTok';
      case MediaPlatform.instagram:
        return 'Instagram';
      case MediaPlatform.youtube:
        return 'YouTube';
      case MediaPlatform.unsupported:
        return 'Unsupported';
    }
  }
}

bool _hostMatches(String host, String domain) {
  return host == domain || host.endsWith('.$domain');
}

/// Classifies [rawUrl] strictly within KlipFetch's mobile scope:
/// TikTok, Instagram, and YouTube.
MediaPlatform detectMediaPlatform(String rawUrl) {
  final parsed = Uri.tryParse(rawUrl.trim());
  if (parsed == null) return MediaPlatform.unsupported;
  final scheme = parsed.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return MediaPlatform.unsupported;
  }
  final host = parsed.host.toLowerCase();
  if (host.isEmpty) return MediaPlatform.unsupported;

  if (_hostMatches(host, 'youtube.com') ||
      _hostMatches(host, 'youtube-nocookie.com') ||
      host == 'youtu.be') {
    return MediaPlatform.youtube;
  }
  if (_hostMatches(host, 'instagram.com') ||
      _hostMatches(host, 'ddinstagram.com')) {
    return MediaPlatform.instagram;
  }
  if (_hostMatches(host, 'tiktok.com')) {
    return MediaPlatform.tiktok;
  }
  return MediaPlatform.unsupported;
}
