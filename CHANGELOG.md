# Changelog

All notable changes to **KlipFetch** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

### Changed
- Pinned Flutter SDK `3.47.9` and upgraded `.github/workflows/ci.yml` to run `libreget-core` and `klipfetch_ffi` Rust tests, cross-compile `libklipfetch_ffi.so` (`arm64-v8a`) via `cargo-ndk`, run Flutter checks, and verify the shared library inside the built debug APK.

[Unreleased]: https://github.com/fyou00/klipfetch/commits/main
