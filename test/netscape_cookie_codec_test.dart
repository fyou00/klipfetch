import 'package:flutter_test/flutter_test.dart';
import 'package:klipfetch/models/auth_models.dart';
import 'package:klipfetch/services/netscape_cookie_codec.dart';

void main() {
  group('NetscapeCookieCodec', () {
    const sampleCookies = '''
# Netscape HTTP Cookie File
#HttpOnly_.instagram.com\tTRUE\t/\tTRUE\t2147483647\tsessionid\tsuper_secret_ig_token
.instagram.com\tTRUE\t/\tTRUE\t2147483647\tdates\t123
#HttpOnly_.google.com\tTRUE\t/\tTRUE\t2147483647\tSAPISID\tyt_secret_token
.example.com\tTRUE\t/\tFALSE\t0\tunrelated\tignore_me
''';

    test('parses HttpOnly and standard Netscape entries', () {
      final parsed = parseNetscapeCookies(sampleCookies);
      expect(parsed.length, 4);
      expect(parsed[0].httpOnly, isTrue);
      expect(parsed[0].domain, '.instagram.com');
      expect(parsed[0].name, 'sessionid');
      expect(parsed[0].value, 'super_secret_ig_token');
      expect(parsed[1].httpOnly, isFalse);
      expect(parsed[2].domain, '.google.com');
    });

    test('filters cookies strictly to allowed domains', () {
      final igOnly = validateAndFilterNetscape(
        sampleCookies,
        AuthPlatformConfig.instagram.allowedCookieDomains,
      );
      expect(igOnly, contains('#HttpOnly_.instagram.com'));
      expect(igOnly, contains('sessionid'));
      expect(igOnly, isNot(contains('google.com')));
      expect(igOnly, isNot(contains('example.com')));

      final ytAndGoogle = validateAndFilterNetscape(
        sampleCookies,
        AuthPlatformConfig.youtube.allowedCookieDomains,
      );
      expect(ytAndGoogle, contains('.google.com'));
      expect(ytAndGoogle, contains('SAPISID'));
      expect(ytAndGoogle, isNot(contains('instagram.com')));
    });

    test('throws FormatException when invalid or no matching domain', () {
      expect(
        () => validateAndFilterNetscape(
          'not valid netscape cookies',
          AuthPlatformConfig.tiktok.allowedCookieDomains,
        ),
        throwsFormatException,
      );
      expect(
        () => validateAndFilterNetscape(
          sampleCookies,
          AuthPlatformConfig.tiktok.allowedCookieDomains,
        ),
        throwsFormatException,
      );
    });

    test('summarizes auth presence and redacts raw cookie values', () {
      final summary = summarizeNetscape(
        sampleCookies,
        allowedDomains: AuthPlatformConfig.instagram.allowedCookieDomains,
        authCookieNames: AuthPlatformConfig.instagram.authCookieNames,
      );
      expect(summary.totalCount, 4);
      expect(summary.matchedDomainCount, 2);
      expect(summary.hasAuthCookie, isTrue);
      expect(summary.cookieNames, ['sessionid', 'dates']);

      final preview = redactCookiePreview(
        sampleCookies,
        allowedDomains: AuthPlatformConfig.instagram.allowedCookieDomains,
      );
      expect(preview, contains('2 cookies'));
      expect(preview, contains('sessionid'));
      expect(preview, isNot(contains('super_secret_ig_token')));
      expect(preview, isNot(contains('yt_secret_token')));
    });
  });
}
