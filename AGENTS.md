# AGENTS.md — Contributor & AI Coding Agent Guidelines

This document defines mandatory project boundaries, architectural invariants, licensing rules, and verification steps for anyone (human contributors and AI coding agents) working on **KlipFetch**.

---

## 1. Hard Scope Boundaries (Do Not Violate)

1. **Android-Only Target**:
   - **NEVER** scaffold, enable, or commit `ios/`, `web/`, `macos/`, `linux/`, or `windows/` platform folders or platform-specific plugins that break Android-only builds.
   - All native platform channels, permissions, storage logic, and CI workflows target **Android** (`arm64-v8a` and `armeabi-v7a`).
2. **Supported Platforms Are Strictly Limited to 3**:
   - **TikTok**, **Instagram**, and **YouTube** only.
   - **NEVER** add or re-enable Telegram (`libreget-plugin-telegram`), BitTorrent (`librqbit`), Courses (`libreget-plugin-courses`), Bilibili, Pinterest, Reddit, X/Twitter, Twitch, or LibreGet's desktop utilities.
   - When modifying `libreget-core`, keep unused platform extractors and desktop tools disabled under `#[cfg(feature = "desktop")]`.
3. **Non-Play Store Open-Source App**:
   - **NEVER** introduce proprietary Google Play Services (`com.google.android.gms`), Firebase Crashlytics/Analytics, ad SDKs, or telemetry trackers. Keep builds clean for GitHub Releases, Obtainium, and F-Droid / IzzyOnDroid.

---

## 2. License, Attribution & Ethical Guardrails

1. **GNU GPL v3.0 Copyleft**:
   - All source files in this repository are licensed under **GPL-3.0** (matching upstream [`OpenSelena/libreget`](https://github.com/OpenSelena/libreget)).
   - Only add dependencies whose licenses are GPL-3.0-compatible (MIT, BSD, Apache-2.0, Unlicense, MPL-2.0, LGPL). Do not introduce proprietary/closed-source SDKs.
   - Always preserve upstream copyright notices and attribution when adapting code from `OpenSelena/libreget`.
2. **Independent Brand Identity**:
   - **NEVER** copy LibreGet's penguin mascot, app icons, screenshots, or brand assets from `OpenSelena/libreget`.
   - Keep branding strictly as **KlipFetch** (with attribution such as *"Powered by LibreGet core"* where appropriate).
3. **No DRM Bypass or Paywall Circumvention**:
   - Never add code intended to bypass DRM, crack paywalls, or circumvent platform security. Logged-in downloads must only access content the user's own authenticated session already permits.

---

## 3. Architectural Invariants

1. **Dual-Engine Routing Rules**:
   - **TikTok & Instagram** → Attempt native extraction in Rust (`libreget-core` via `flutter_rust_bridge` v2) first, and fall back to Android `youtubedl-android` (`yt-dlp`) on failure.
   - **YouTube** → Route directly to Android `youtubedl-android` (`yt-dlp` + QuickJS-NG + FFmpeg).
2. **Rust Cross-Compilation Hygiene**:
   - `rust/` and `libreget-core` MUST compile cleanly with `--no-default-features --features mobile` for `aarch64-linux-android` and `armv7-linux-androideabi`.
   - **NEVER** introduce `native-tls`, OpenSSL C dependencies, `tauri`, `enigo`, `trash`, `open`, or `x11rb` into the mobile dependency graph. Always use `rustls` (`rustls-tls` / `rustls-tls-webpki-roots`).
3. **Android SELinux W^X Compliance (Critical)**:
   - **NEVER** download native executable binaries (e.g., `ffmpeg`, `deno`, `aria2c`) into writable app storage (`filesDir` / `cacheDir`) and execute them via `ProcessBuilder` or `execve()`. Android 10+ blocks execution from writable app directories.
   - Native executables (`libpython`, `ffmpeg`, `quickjs-ng`, `aria2c`) MUST be packaged via `jniLibs` with `useLegacyPackaging = true` in `android/app/build.gradle.kts` and `android:extractNativeLibs="true"` in `AndroidManifest.xml`.
   - Only the pure-Python `yt-dlp` zipapp may be updated at runtime.
4. **Background Resilience & Scoped Storage**:
   - All active downloads MUST run inside `DownloadForegroundService` with notification progress updates and cancellation actions so Android does not kill transfers when the screen turns off.
   - Stage temporary/partial files inside app-private storage, then atomically export completed media to public `Downloads/KlipFetch/{TikTok,Instagram,YouTube}/` via Android **MediaStore**.
5. **Non-Blocking UI Isolate**:
   - Heavy network parsing, file I/O, SQLite WAL queries, and FFmpeg muxing MUST run on the Rust Tokio runtime or Kotlin background dispatchers — never on the Dart UI isolate.
6. **Cookie Handling**:
   - Capture `HttpOnly` cookies using native Android `WebView` + `CookieManager` (`AuthWebViewActivity.kt`) and store them only in app-private storage (`cookies/cookies.txt`). Never log raw cookie tokens (`sessionid`, `SAPISID`, etc.) or `cookies.txt` contents in console logs or error reports.

---

## 4. Git & Workflow Conventions

1. **Conventional Commits (Atomic per Logical Change)**:
   - Every distinct change gets its own focused commit using Conventional Commits:
     - `feat:` new feature or module
     - `fix:` bug fix
     - `docs:` documentation updates (`README.md`, `PLAN.md`, `AGENTS.md`, `CHANGELOG.md`)
     - `refactor:` internal restructuring without behavior change
     - `ci:` GitHub Actions or build pipeline changes
     - `chore:` maintenance, dependencies, formatting, repo config
   - Do not bundle unrelated edits into one commit.
2. **Changelog Discipline**:
   - Update `CHANGELOG.md` under `## [Unreleased]` (following Keep a Changelog 1.1.0) for every user-facing feature, fix, or architectural change.
3. **Docs Stay Truthful**:
   - Clearly distinguish implemented features from planned roadmap items in `README.md` and `PLAN.md`. Do not claim tests or APK builds passed unless verified directly.

---

## 5. Standard Verification Commands

Run the relevant checks after making changes and before committing/pushing:

### Flutter / Dart
```bash
flutter pub get
flutter analyze
flutter test
```

### Android APK Build (Requires JDK 17 + Android SDK, also run in CI)
```bash
flutter build apk --debug --target-platform android-arm64
```

### Rust Core & FFI (Once Phase 0/1 Rust Workspace Is Present)
```bash
flutter_rust_bridge_codegen generate
cargo check --manifest-path third_party/libreget/src-tauri/libreget-core/Cargo.toml --no-default-features --features mobile
cargo test --manifest-path third_party/libreget/src-tauri/libreget-core/Cargo.toml --no-default-features --features mobile
cargo ndk -t arm64-v8a build --manifest-path rust/Cargo.toml --release
```
