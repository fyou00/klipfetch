# Upstream Attribution & Mobile Pruning Record

This directory contains a pruned, mobile-adapted pure-Rust subset of `src-tauri/libreget-core` from **[OpenSelena/libreget](https://github.com/OpenSelena/libreget)**, licensed under **GNU General Public License v3.0 (GPL-3.0)**.

- **Upstream Repository**: `https://github.com/OpenSelena/libreget`
- **Upstream Commit SHA**: `dff2b974ec798e76a3c6d95d2e3b7273173dc674`
- **Upstream Commit Date**: `2026-11-26 02:36:49 +0600`
- **License**: GNU GPL v3.0 (see root `../../LICENSE`)

## Retained Upstream Files
- `src/models/{mod.rs,download.rs,media.rs,progress.rs,settings.rs}`
- `src/core/{adaptive_concurrency.rs,cookie_parser.rs,direct_downloader.rs,errors.rs,events.rs,filename.rs,http_client.rs,http_fetcher.rs,media_signature.rs,paths.rs,redirect.rs}`
- `src/platforms/{traits.rs,cookie_provider.rs,instagram.rs,tiktok.rs}`

## Adaptations for KlipFetch (Android Mobile)
1. **Desktop & Out-of-Scope Dependencies Removed**:
   - Excluded all non-mobile crates (`enigo`, `trash`, `open`, `libloading`, `ort`, `lopdf`, `xz2`, `image`, `tokio-tungstenite`/`native-tls`) and desktop subprocess modules (`ytdlp.rs`, `ffmpeg.rs`, `dependencies.rs`, `process.rs`, `core/tools/*`).
   - Removed all platforms outside KlipFetch's scope (`TikTok`, `Instagram`, `YouTube` only).
2. **`src/core/paths.rs`**:
   - Added `set_mobile_data_dir(PathBuf)` and `mobile_cookie_file()` so Flutter's Android sandbox directory (`path_provider`) feeds `libreget-core` directly.
3. **`src/core/cookie_parser.rs`**:
   - Replaced desktop `ytdlp::ext_cookie_path_if_fresh()` lookup with `crate::platforms::cookie_provider::cookie_path_for(domain)` / `crate::core::paths::mobile_cookie_file()`.
4. **`src/platforms/instagram.rs` & `src/platforms/tiktok.rs`**:
   - Attempt native Rust scraping first (`request_embed` / `request_gql` for Instagram; `fetch_detail` for TikTok) instead of calling `yt-dlp` upfront.
   - Replaced subprocess `yt-dlp` fallback calls with explicit `Err(anyhow!("FALLBACK_YTDLP: ..."))` markers so Dart's Smart URL Router delegates seamlessly to Android `youtubedl-android`.
5. **`src/platforms/mod.rs`**:
   - Scoped `Platform` enum strictly to `YouTube`, `Instagram`, and `TikTok` with unit tests.
