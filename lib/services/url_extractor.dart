import '../models/media_platform.dart';

final RegExp _httpUrlPattern = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);
final RegExp _trailingPunctuation = RegExp(r'''[.,)!?\]"'>;]+$''');

/// Extracts the first URL from free-form text (such as an Android Share Sheet
/// payload or clipboard snippet) that belongs to TikTok, Instagram, or YouTube.
String? extractSupportedUrlFromText(String rawText) {
  for (final match in _httpUrlPattern.allMatches(rawText)) {
    final cleaned = match.group(0)?.replaceAll(_trailingPunctuation, '') ?? '';
    if (cleaned.isEmpty) continue;
    if (detectMediaPlatform(cleaned) != MediaPlatform.unsupported) {
      return cleaned;
    }
  }
  return null;
}

/// Extracts the first HTTP(S) URL regardless of platform, used to detect
/// out-of-scope URLs in shared text so the UI can show a clear message.
String? extractAnyUrlFromText(String rawText) {
  final match = _httpUrlPattern.firstMatch(rawText);
  if (match == null) return null;
  final cleaned = match.group(0)?.replaceAll(_trailingPunctuation, '') ?? '';
  return cleaned.isEmpty ? null : cleaned;
}
