import 'media_platform.dart';

class AuthPlatformConfig {
  const AuthPlatformConfig({
    required this.platform,
    required this.domain,
    required this.label,
    required this.loginUrl,
    required this.cookieUrls,
    required this.allowedCookieDomains,
    required this.authCookieNames,
    required this.helperNote,
  });

  final MediaPlatform platform;
  final String domain;
  final String label;
  final String loginUrl;
  final List<String> cookieUrls;
  final List<String> allowedCookieDomains;
  final List<String> authCookieNames;
  final String helperNote;

  static const instagram = AuthPlatformConfig(
    platform: MediaPlatform.instagram,
    domain: 'instagram.com',
    label: 'Instagram',
    loginUrl: 'https://www.instagram.com/accounts/login/',
    cookieUrls: [
      'https://www.instagram.com/',
      'https://i.instagram.com/',
      'https://instagram.com/',
    ],
    allowedCookieDomains: ['instagram.com', 'cdninstagram.com'],
    authCookieNames: ['sessionid', 'ds_user_id'],
    helperNote: 'Enables Stories, Highlights, and private posts you can view.',
  );

  static const tiktok = AuthPlatformConfig(
    platform: MediaPlatform.tiktok,
    domain: 'tiktok.com',
    label: 'TikTok',
    loginUrl: 'https://www.tiktok.com/login',
    cookieUrls: [
      'https://www.tiktok.com/',
      'https://m.tiktok.com/',
      'https://tiktok.com/',
    ],
    allowedCookieDomains: ['tiktok.com', 'tiktokv.com'],
    authCookieNames: ['sessionid', 'sid_tt', 'sessionid_ss'],
    helperNote: 'Helps with region-restricted posts and age-gated TikTok clips.',
  );

  static const youtube = AuthPlatformConfig(
    platform: MediaPlatform.youtube,
    domain: 'youtube.com',
    label: 'YouTube',
    loginUrl:
        'https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fwww.youtube.com%2F',
    cookieUrls: [
      'https://www.youtube.com/',
      'https://m.youtube.com/',
      'https://accounts.google.com/',
      'https://www.google.com/',
    ],
    allowedCookieDomains: ['youtube.com', 'google.com'],
    authCookieNames: [
      'SAPISID',
      'SID',
      'LOGIN_INFO',
      '__Secure-3PSID',
      '__Secure-1PSID',
    ],
    helperNote: 'Helps with age-restricted videos and signed-in YouTube feeds.',
  );

  static const List<AuthPlatformConfig> all = [
    instagram,
    tiktok,
    youtube,
  ];

  static AuthPlatformConfig? forPlatform(MediaPlatform platform) {
    switch (platform) {
      case MediaPlatform.instagram:
        return instagram;
      case MediaPlatform.tiktok:
        return tiktok;
      case MediaPlatform.youtube:
        return youtube;
      case MediaPlatform.unsupported:
        return null;
    }
  }
}

class CookieSessionStatus {
  const CookieSessionStatus({
    required this.platform,
    required this.domain,
    this.hasCookies = false,
    this.cookieCount = 0,
    this.hasAuthCookie = false,
    this.updatedAtMs,
  });

  final MediaPlatform platform;
  final String domain;
  final bool hasCookies;
  final int cookieCount;
  final bool hasAuthCookie;
  final int? updatedAtMs;

  bool get isConnected => hasCookies && hasAuthCookie;

  CookieSessionStatus copyWith({
    bool? hasCookies,
    int? cookieCount,
    bool? hasAuthCookie,
    int? updatedAtMs,
    bool clearUpdatedAt = false,
  }) {
    return CookieSessionStatus(
      platform: platform,
      domain: domain,
      hasCookies: hasCookies ?? this.hasCookies,
      cookieCount: cookieCount ?? this.cookieCount,
      hasAuthCookie: hasAuthCookie ?? this.hasAuthCookie,
      updatedAtMs:
          clearUpdatedAt ? null : (updatedAtMs ?? this.updatedAtMs),
    );
  }
}

class AuthBrowserCapture {
  const AuthBrowserCapture({
    required this.cancelled,
    this.netscapeCookies = '',
    this.cookieCount = 0,
    this.hasAuthCookie = false,
  });

  final bool cancelled;
  final String netscapeCookies;
  final int cookieCount;
  final bool hasAuthCookie;
}

class SessionTestResult {
  const SessionTestResult({
    required this.platform,
    required this.isValid,
    required this.message,
    this.cookieCount = 0,
    this.sharedFileReady = false,
  });

  final MediaPlatform platform;
  final bool isValid;
  final String message;
  final int cookieCount;
  final bool sharedFileReady;
}
