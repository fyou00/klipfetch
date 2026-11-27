# Changelog

All notable changes to **KlipFetch** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-11-27

### Added
- Hallmark Editorial design specification (`design.md`) and FigCraft source/renders (`design/klipfetch.figcraft`, `design/build_figcraft.mjs`, `design/tokens.css`, `design/renders/`)
- Bundled SIL OFL 1.1 typography (`Bricolage Grotesque`, `IBM Plex Sans` 400/600, and `IBM Plex Mono`) under `assets/fonts/`
- Editorial control primitives (`lib/widgets/editorial_controls.dart`) and ink/paper status tags (`lib/widgets/platform_badge.dart`)
- Android Kiln Aperture adaptive launcher icon (`mipmap-anydpi-v26/ic_launcher.xml`, foreground/monochrome vector drawables, `mdpi`–`xxxhdpi` PNG mipmaps) and warm archival paper launch background (`#F5F2EC`)

### Changed
- Redesigned `KlipFetchTheme` and all primary screens (`Home`, `Downloads`, `Settings`, `Accounts & Cookies`) in an Editorial paper-and-terracotta layout (`#F5F2EC` background, `#FFFCF7` surfaces, `#BF3909` accent, `#1A1715` ink)
- Replaced Material 3 bottom navigation bar with an Editorial top-rule navigation bar (`lib/app/klipfetch_app.dart`)
- Ordered Home playlist picker above video container/subtitles/SponsorBlock toggles and flattened Settings and Accounts & Cookies rows with 1px hairlines
- Aligned native Android `AuthWebViewActivity` toolbar with vector Close/Reload icons, hairline divider, terracotta loading bar, and 4dp `Save Session` action button

### Removed
- Removed untracked `web/` scaffold folder to maintain strict Android-only build boundaries

## [0.1.2] - 2026-11-27

### Fixed
- Fixed immediate startup force-close crash in R8-minified Android release APKs caused by R8 stripping Apache Commons Compress (`org.apache.commons.compress.*`) classes used reflectively by `youtubedl-android` during initialization.
- Hardened Kotlin coroutine method-channel handlers (`YtDlpChannelHandler`, `AndroidPlatformHandler`) to catch `Throwable` with `CoroutineExceptionHandler` safety nets and defensive Android 14/15 foreground-service guards.
- Fixed QuickJS-NG native binary path resolution (`libqjs.so` with fallback to `libquickjs.so`) for YouTube JavaScript runtime extraction.
- Added automated `classes.dex` R8 keep-rule verification to `.github/workflows/release.yml`.

## [0.1.1] - 2026-11-26

### Changed
- Locked KlipFetch to Light Mode while keeping the Settings Appearance selector (`System` / `Dark` / `Light`) visible as an inert control with an explicit locked-mode notice.
- Restyled the Light Mode palette to **Warm Daylight Paper + Burnt Vermilion** (`#F5F2EC` scaffold, `#FFFCF7` cards, `#BF3909` primary accent, unified `#8A8175` control outlines) so all platform (`TikTok`, `Instagram`, `YouTube`), engine (`Rust Core`, `yt-dlp`, `yt-dlp fallback`), and status (`Connected`, `Incomplete`, `Completed`) badges pass WCAG 2.1 AA contrast (`>= 4.94:1` text, `3.75:1` interactive outlines).
- Removed card-in-card playlist border in favor of a flat Material tonal inset, eliminated redundant download status labels and middle-dot metadata concatenation, normalized `Best` quality casing across screens, and added `FontFeature.tabularFigures()` for stable progress/metric alignment.
- Aligned Android native `AuthWebViewActivity` (toolbar, light status bar icons, 1dp divider, `Save Session` button, session detection status colors) and `values-night/styles.xml` with Light Mode.
- Upgraded `.github/workflows/release.yml` with early fail-fast `keytool` keystore verification and automatic release notes extracted from `CHANGELOG.md`.

## [0.1.0] - 2026-11-26

### Added
- GNU General Public License v3.0 (`LICENSE`) and tailored `.gitignore` covering Flutter, Android NDK/signing secrets, Rust FFI artifacts, and local cookie/database files.
- Android-only Flutter application scaffold (`klipfetch`, package `io.github.fyou00.klipfetch`) targeting Flutter 3.47.9 / Dart 3.13.7, AGP 9.1.0, and Kotlin 2.4.0.
- Comprehensive `README.md` documenting the project scope (Android-only; TikTok, Instagram, and YouTube; non-Play Store distribution), Dual-Engine Hybrid Architecture (`libreget-core` Rust FFI via `flutter_rust_bridge` v2 + `youtubedl-android` with QuickJS-NG and FFmpeg), Android W^X compliance, and full tech stack.
- Phased 5-stage Android implementation roadmap in `PLAN.md` covering upstream `libreget-core` mobile preparation, Rust/Kotlin bridges, Share Sheet & Foreground Service UX, InAppWebView `HttpOnly` cookie auth, and split-per-ABI release engineering.
- Contributor and AI coding agent guardrails in `AGENTS.md` enforcing Android-only scope, 3-platform boundaries, GPL-3.0 copyleft, W^X hygiene, Conventional Commits, and verification commands.
- GitHub Actions CI workflow (`.github/workflows/ci.yml`) running `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build apk --debug --target-platform android-arm64` on `ubuntu-latest`.
- Vendored, mobile-pruned `libreget-core` (`third_party/libreget-core/`, upstream `OpenSelena/libreget` commit `dff2b974ec798e76a3c6d95d2e3b7273173dc674`) compiled with `feature = "mobile"`, pure-Rust `rustls-tls`, TikTok/Instagram extractors, `set_mobile_data_dir`, and `FALLBACK_YTDLP` handoff markers.
- `klipfetch_ffi` Rust crate (`rust/`) and generated `flutter_rust_bridge` `2.13.0` Dart bindings (`lib/src/rust/`) exposing `init_core`, `detect_platform`, `probe_native_media`, `download_native_media`, `cancel_native_download`, Netscape cookie persistence, and SQLite WAL download queue CRUD.
- Android `youtubedl-android:0.18.1` (`library`, `ffmpeg`, `aria2c`) Kotlin bridge (`YtDlpChannelHandler.kt`) with `minSdk = 24`, `abiFilters`, `useLegacyPackaging = true`, `android:extractNativeLibs="true"`, `ACTION_SEND` intent filter, and QuickJS-NG runtime hook.
- Dart Dual-Engine models and services (`RustCoreService`, `YtDlpService`, `UrlRouterService`) enforcing strict TikTok/Instagram/YouTube scope with automatic fallback to `yt-dlp` and unit tests (`test/url_router_service_test.dart`).
- Phase 2 Android-native infrastructure: `DownloadForegroundService.kt` (`FOREGROUND_SERVICE_DATA_SYNC` + active-task `WAKE_LOCK`), `MediaStoreExporter.kt` (scoped storage export into `Downloads/KlipFetch/{TikTok,Instagram,YouTube}/`), `AndroidPlatformHandler.kt` (`ACTION_SEND` Share Sheet bridge, `POST_NOTIFICATIONS` request flow, `FileProvider` open/share), and `YtDlpChannelHandler.kt` `outputPath` resolution (`--no-simulate --print after_move:filepath`).
- Phase 2 Riverpod (`flutter_riverpod: ^2.6.1`) state layer (`DownloadQueueNotifier`, `SettingsRepository`, `QueueRepository`, `UrlExtractor`, `AndroidPlatformService`, `AppSettings`, `QueueItem`) with persistent SQLite queue synchronization.
- Phase 2 Material 3 Android UI (`AppTheme`, `PlatformBadge`, **Home**, **Downloads**, **Settings** screens, `KlipFetchApp`) and Phase 2 unit/widget test suites (`test/url_extractor_test.dart`, `test/download_queue_controller_test.dart`, `test/widget_test.dart`).
- Phase 3 in-app cookie authentication (`AuthWebViewActivity.kt` Android `WebView` + `CookieManager` Netscape `cookies.txt` capture, `AuthBrowserScreen`, `CookieAuthService`, `NetscapeCookieCodec`, Rust `CookieDomainStatus` / `get_shared_cookies_path` FFI) with per-platform **Sign In**, **Test**, **Import**, and **Clear** controls for Instagram, TikTok, and YouTube.
- Phase 3 platform refinements: Instagram Story/Highlight `yt-dlp` cookie routing, audio fallback, and 350 ms carousel pacing; TikTok slideshow non-`.jpeg` fallback and background audio toggle; YouTube 4K/2K/1080p/720p/480p upper bounds, MP4/MKV container selector, selective Playlist item picker, SponsorBlock removal, and SRT/VTT subtitle download/embedding.
- Batch `MediaStoreExporter.exportDirectory` support for multi-file carousels, slideshows, and subtitle sidecars plus Phase 3 unit and widget tests (`test/netscape_cookie_codec_test.dart`, `test/ytdlp_parser_test.dart`, expanded router/queue/widget tests).
- Uploaded `klipfetch-android-arm64-debug` (`app-debug.apk`, 14-day retention) as a downloadable artifact in `.github/workflows/ci.yml`.
- Phase 4 release engineering (`android/app/proguard-rules.pro`, release signing & `split-per-abi` configuration in `android/app/build.gradle.kts`, aligned version `0.1.0+1`).
- Automated `.github/workflows/release.yml` building dual-ABI (`arm64-v8a` + `armeabi-v7a`) split release APKs with `cargo-ndk`, verifying `libklipfetch_ffi.so`, generating `SHA256SUMS.txt`, and publishing tagged GitHub Releases (`v*.*.*` + `workflow_dispatch` dry-runs).
- Obtainium / F-Droid Fastlane metadata (`fastlane/metadata/android/{en-US,id}/`), automated dependency audit (`scripts/audit_dependencies.sh`), and `docs/RELEASE_AND_QA.md` (keystore guide, Obtainium setup, Android 10–15 QA matrix).

### Changed
- Pinned Flutter SDK `3.47.9` and upgraded `.github/workflows/ci.yml` to run `./scripts/audit_dependencies.sh`, `libreget-core` and `klipfetch_ffi` Rust tests, cross-compile `libklipfetch_ffi.so` (`arm64-v8a`) via `cargo-ndk`, run Flutter checks, and verify the shared library inside the built debug APK (using `actions/setup-java@v5`).
- Refreshed `README.md` architecture diagram, tech stack, repository tree, and distribution documentation to reflect completed Phase 0–4 modules.
- Updated `YtDlpService` to return resolved `outputPath` from `YtDlpChannelHandler.kt` and replaced the starter template in `lib/main.dart` with `KlipFetchApp`.
- Updated `UrlRouterService`, `YtDlpChannelHandler.kt`, and `DownloadQueueNotifier` to propagate shared `cookies.txt`, muxing phase telemetry, and multi-file staging directory exports.

[Unreleased]: https://github.com/fyou00/klipfetch/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/fyou00/klipfetch/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/fyou00/klipfetch/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/fyou00/klipfetch/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/fyou00/klipfetch/releases/tag/v0.1.0
