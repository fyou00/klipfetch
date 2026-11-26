import 'package:flutter_test/flutter_test.dart';
import 'package:klipfetch/services/url_extractor.dart';

void main() {
  group('url_extractor', () {
    test('extracts supported TikTok, Instagram, and YouTube URLs from share text', () {
      expect(
        extractSupportedUrlFromText(
          'Watch this funny clip! https://vm.tiktok.com/ZM8abcdef/ #fyp',
        ),
        'https://vm.tiktok.com/ZM8abcdef/',
      );
      expect(
        extractSupportedUrlFromText(
          'Look at this reel (https://www.instagram.com/reel/Cxyz123/?igsh=abc).',
        ),
        'https://www.instagram.com/reel/Cxyz123/?igsh=abc',
      );
      expect(
        extractSupportedUrlFromText(
          'Video title - https://youtu.be/dQw4w9WgXcQ!',
        ),
        'https://youtu.be/dQw4w9WgXcQ',
      );
    });

    test('skips unsupported URL and picks subsequent supported URL if present', () {
      expect(
        extractSupportedUrlFromText(
          'Compare https://x.com/post/1 with https://www.youtube.com/watch?v=abc123',
        ),
        'https://www.youtube.com/watch?v=abc123',
      );
    });

    test('returns null for unsupported domains while extractAnyUrlFromText finds URL', () {
      const text = 'Read this thread: https://x.com/rustlang/status/12345';
      expect(extractSupportedUrlFromText(text), isNull);
      expect(
        extractAnyUrlFromText(text),
        'https://x.com/rustlang/status/12345',
      );
      expect(extractAnyUrlFromText('just plain text without links'), isNull);
    });
  });
}
