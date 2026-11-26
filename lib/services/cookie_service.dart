import '../models/auth_models.dart';
import '../models/media_platform.dart';
import 'android_platform_service.dart';
import 'netscape_cookie_codec.dart';
import 'rust_core_service.dart';

class CookieAuthService {
  const CookieAuthService({
    required this.nativeEngine,
    required this.androidPlatform,
  });

  final NativeEngineClient nativeEngine;
  final AndroidPlatformClient androidPlatform;

  Future<Map<MediaPlatform, CookieSessionStatus>> loadAllStatuses() async {
    final result = <MediaPlatform, CookieSessionStatus>{};
    for (final config in AuthPlatformConfig.all) {
      result[config.platform] = await getStatus(config.platform);
    }
    return result;
  }

  Future<CookieSessionStatus> getStatus(MediaPlatform platform) async {
    final config = AuthPlatformConfig.forPlatform(platform);
    if (config == null) {
      throw ArgumentError.value(platform, 'platform', 'Unsupported platform');
    }

    try {
      final info = await nativeEngine.getCookieDomainStatus(config.domain);
      return CookieSessionStatus(
        platform: platform,
        domain: config.domain,
        hasCookies: info.hasCookies,
        cookieCount: info.cookieCount,
        hasAuthCookie: info.hasAuthCookie,
        updatedAtMs: info.updatedAtMs,
      );
    } catch (_) {
      return CookieSessionStatus(
        platform: platform,
        domain: config.domain,
      );
    }
  }

  Future<CookieSessionStatus?> signInWithBrowser(MediaPlatform platform) async {
    final config = AuthPlatformConfig.forPlatform(platform);
    if (config == null) {
      throw ArgumentError.value(platform, 'platform', 'Unsupported platform');
    }

    final capture = await androidPlatform.openAuthBrowser(
      platform: platform.name,
      loginUrl: config.loginUrl,
      cookieUrls: config.cookieUrls,
      authCookieNames: config.authCookieNames,
    );

    if (capture.cancelled) {
      return null;
    }

    if (capture.netscapeCookies.trim().isNotEmpty && capture.cookieCount > 0) {
      final filtered = validateAndFilterNetscape(
        capture.netscapeCookies,
        config.allowedCookieDomains,
      );
      await nativeEngine.saveNetscapeCookies(config.domain, filtered);
    }

    return getStatus(platform);
  }

  Future<CookieSessionStatus> importNetscapeCookies(
    MediaPlatform platform,
    String rawContent,
  ) async {
    final config = AuthPlatformConfig.forPlatform(platform);
    if (config == null) {
      throw ArgumentError.value(platform, 'platform', 'Unsupported platform');
    }

    final filtered = validateAndFilterNetscape(
      rawContent,
      config.allowedCookieDomains,
    );
    await nativeEngine.saveNetscapeCookies(config.domain, filtered);
    return getStatus(platform);
  }

  Future<SessionTestResult> testSession(MediaPlatform platform) async {
    final config = AuthPlatformConfig.forPlatform(platform);
    if (config == null) {
      throw ArgumentError.value(platform, 'platform', 'Unsupported platform');
    }

    final status = await getStatus(platform);
    final sharedPath = await resolveCookiesPath();
    final sharedReady = sharedPath != null && sharedPath.isNotEmpty;

    if (!status.hasCookies || status.cookieCount == 0) {
      return SessionTestResult(
        platform: platform,
        isValid: false,
        cookieCount: 0,
        sharedFileReady: sharedReady,
        message: 'No cookies stored for ${config.label}. Tap Sign In first.',
      );
    }

    if (!status.hasAuthCookie) {
      return SessionTestResult(
        platform: platform,
        isValid: false,
        cookieCount: status.cookieCount,
        sharedFileReady: sharedReady,
        message:
            '${config.label} cookies found (${status.cookieCount}), but no active login session token was detected (${config.authCookieNames.take(2).join(", ")}). Try signing in again.',
      );
    }

    if (!sharedReady) {
      return SessionTestResult(
        platform: platform,
        isValid: false,
        cookieCount: status.cookieCount,
        sharedFileReady: false,
        message:
            '${config.label} session found (${status.cookieCount} cookies), but shared cookies.txt is not ready yet.',
      );
    }

    return SessionTestResult(
      platform: platform,
      isValid: true,
      cookieCount: status.cookieCount,
      sharedFileReady: true,
      message:
          '${config.label} session active (${status.cookieCount} cookies ready for Rust & yt-dlp).',
    );
  }

  Future<CookieSessionStatus> clearCookies(MediaPlatform platform) async {
    final config = AuthPlatformConfig.forPlatform(platform);
    if (config == null) {
      throw ArgumentError.value(platform, 'platform', 'Unsupported platform');
    }

    await nativeEngine.clearDomainCookies(config.domain);
    await androidPlatform.clearWebViewCookies(cookieUrls: config.cookieUrls);
    return getStatus(platform);
  }

  Future<String?> resolveCookiesPath() async {
    try {
      return await nativeEngine.getSharedCookiesPath();
    } catch (_) {
      return null;
    }
  }
}
