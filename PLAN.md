# KlipFetch — Android Implementation Plan

> Detailed engineering roadmap for building **KlipFetch**, an Android-only Flutter media downloader for **TikTok, Instagram, and YouTube** backed by [`OpenSelena/libreget`](https://github.com/OpenSelena/libreget) (`libreget-core` via Rust FFI) and `youtubedl-android` (`yt-dlp` + QuickJS-NG + FFmpeg).

---

## Scope Lock & Architectural Principles

1. **Platform Target**: **Android only** (`minSdk` compatible with `youtubedl-android`, target ABIs `arm64-v8a` and `armeabi-v7a`). No iOS, Web, or desktop code.
2. **Supported Media Platforms**: **TikTok, Instagram, and YouTube only**. All other LibreGet extractors, plugins (`telegram`, `courses`, `convert`), BitTorrent (`librqbit`), and desktop tools remain disabled/excluded.
3. **Distribution Channel**: Open-source GPL-3.0 APK releases via **GitHub Releases (`--split-per-abi`)**, **Obtainium**, and **F-Droid / IzzyOnDroid** (no Google Play Store).
4. **Dual-Engine Routing**:
   - **TikTok & Instagram** → `libreget-core` (Rust FFI) first for fast native extraction and authenticated Stories/Highlights support, with automatic fallback to `youtubedl-android` (`yt-dlp`).
   - **YouTube** → `youtubedl-android` (`yt-dlp` zipapp + QuickJS-NG + FFmpeg) directly for resilient `nsig` player-JS challenge solving and adaptive DASH muxing.
5. **Android SELinux W^X Compliance**: Never download executable binaries into writable app data directories. Native binaries (`libpython`, `ffmpeg`, `quickjs-ng`, `aria2c`) ship in `jniLibs` (`useLegacyPackaging = true` / `android:extractNativeLibs="true"`); only the pure-Python `yt-dlp` zipapp updates at runtime.

---

## Phase 0 — Foundation, Toolchain & Upstream Core Prep

### Status
- [x] Initialize public GPL-3.0 GitHub repository (`klipfetch`)
- [x] Scaffold Android-only Flutter application (`flutter create --platforms=android`)
- [x] Configure initial GitHub Actions Android CI (`.github/workflows/ci.yml`)
- [x] Author `README.md`, `PLAN.md`, `AGENTS.md`, and `CHANGELOG.md`
- [ ] Local developer toolchain setup (JDK 17, Android SDK/NDK, Rust Android targets)
- [ ] Vendor/submodule `OpenSelena/libreget` and patch `libreget-core` for `feature = "mobile"`

### Tasks

#### 0.1 Local Machine Toolchain Setup (Required on Local Host Before Native Builds)
Install the Android & Rust cross-compilation toolchain locally (currently only Flutter SDK `3.47.9`, Rust `1.100.0`, `git`, and `gh` are installed on the development host):
1. Install **JDK 17** (Temurin 17) and configure `JAVA_HOME`.
2. Install **Android SDK** (API 34/35, Build-Tools, Platform-Tools) and **Android NDK** (r26+ / `flutter.ndkVersion`).
3. Install Rust Android targets and FFI tooling:
   ```bash
   rustup target add aarch64-linux-android armv7-linux-androideabi
   cargo install cargo-ndk
   cargo install flutter_rust_bridge_codegen
   ```

#### 0.2 Vendor Upstream `OpenSelena/libreget`
Add our fork (or pinned submodule) of `OpenSelena/libreget` under `third_party/libreget/`:
```bash
git submodule add https://github.com/OpenSelena/libreget.git third_party/libreget
```
*(Or maintain a lightweight fork so mobile patches stay clean and easy to rebase against upstream.)*

#### 0.3 Required Mobile Patches in `third_party/libreget/src-tauri/libreget-core`
Audit findings from `OpenSelena/libreget` show `libreget-core/Cargo.toml` already defines `mobile = []`, but several desktop-only crates are still unconditionally compiled:

1. **`src-tauri/libreget-core/Cargo.toml`**:
   - Gate desktop-only dependencies behind `optional = true` and include them only in `desktop = [...]`:
     - `enigo` (desktop auto-clicker & dictation)
     - `trash` (desktop recycle bin)
     - `open` (desktop file/URL launcher)
     - `libloading` and `ort` (desktop dynamic PDFium / ONNX Runtime)
   - Switch `tokio-tungstenite` from `features = ["native-tls"]` to `features = ["rustls-tls-webpki-roots"]` to avoid cross-compiling OpenSSL C libraries for Android.
2. **`src-tauri/libreget-core/src/core/paths.rs`**:
   - Add a `OnceLock<PathBuf>` mobile storage override (`pub fn set_mobile_data_dir(path: PathBuf)`) compiled under `#[cfg(feature = "mobile")]`, initialized at app startup from Flutter's `getApplicationSupportDirectory()`.
3. **`src-tauri/libreget-core/src/core/tools/mod.rs` & `src/platforms/mod.rs`**:
   - Gate desktop-only tool modules (`autoclick`, `dictation`, `win_*`, `sysclean`, `startup`, `uninstall`, `hosts_block`, `screen_record`, `kdeconnect`, `spicetify`) under `#[cfg(feature = "desktop")]`.
   - Keep only required mobile modules active: `instagram`, `tiktok`, URL parser/detector, `cookie_parser`, `direct_downloader`, `hls_downloader`, `http_client`, and queue/database helpers.

### Phase 0 Verification & Definition of Done
- `cargo check --manifest-path third_party/libreget/src-tauri/libreget-core/Cargo.toml --no-default-features --features mobile --target aarch64-linux-android` exits `0`.
- `cargo test --manifest-path third_party/libreget/src-tauri/libreget-core/Cargo.toml --no-default-features --features mobile` passes without referencing `enigo`, `trash`, `native-tls`, or `tauri`.

---

## Phase 1 — Dual-Engine Core Bridge (Rust FFI + Kotlin `youtubedl-android`)

### Goals
Connect both download engines cleanly to Dart so KlipFetch can probe metadata and execute downloads for TikTok, Instagram, and YouTube.

### Tasks

#### 1.1 Rust FFI Wrapper Crate (`rust/`)
Create `rust/Cargo.toml` (`crate-type = ["cdylib"]`) depending on `libreget-core` (`default-features = false, features = ["mobile"]`), `flutter_rust_bridge = "2.13"`, `rusqlite` (`bundled`), `tokio`, `serde`, and `anyhow`.

Expose a clean FFI API in `rust/src/api/`:
- `init_core(data_dir: String, cache_dir: String) -> Result<()>`
- `probe_url(url: String) -> Result<MediaProbeResult>` (detects platform `TikTok | Instagram | YouTube | Unsupported` + extracts metadata/formats for TikTok & Instagram)
- `download_native(request: NativeDownloadRequest, progress_sink: StreamSink<DownloadProgress>) -> Result<String>`
- `cookies_upsert_netscape(domain: String, netscape_content: String) -> Result<()>`
- `queue_enqueue(...)`, `queue_list()`, `queue_pause(id)`, `queue_resume(id)`, `queue_cancel(id)`

Generate Dart bindings with:
```bash
flutter_rust_bridge_codegen generate
```

#### 1.2 Android Native Execution Layer (`android/`)
Update `android/app/build.gradle.kts`:
- Set `minSdk = 24` (verify compatibility with `youtubedl-android:0.18.1` and `flutter_inappwebview`).
- Add ABI filters & legacy `jniLibs` packaging for W^X compatibility:
  ```kotlin
  android {
      defaultConfig {
          ndk {
              abiFilters += listOf("arm64-v8a", "armeabi-v7a")
          }
      }
      packaging {
          jniLibs {
              useLegacyPackaging = true
          }
      }
  }
  dependencies {
      val youtubedlAndroidVersion = "0.18.1"
      implementation("io.github.junkfood02.youtubedl-android:library:$youtubedlAndroidVersion")
      implementation("io.github.junkfood02.youtubedl-android:ffmpeg:$youtubedlAndroidVersion")
      implementation("io.github.junkfood02.youtubedl-android:aria2c:$youtubedlAndroidVersion")
  }
  ```
- Set `android:extractNativeLibs="true"` in `android/app/src/main/AndroidManifest.xml`.
- Bundle **QuickJS-NG** binary (`libquickjs.so` in `jniLibs/<abi>/`) and pass `--js-runtimes quickjs:<path>` when invoking `yt-dlp` for YouTube `nsig` challenge evaluation.

Create `android/app/src/main/kotlin/io/github/fyou00/klipfetch/YtDlpChannelHandler.kt`:
- Expose `MethodChannel("io.github.fyou00.klipfetch/ytdlp")` with methods:
  - `init` — initialize `YoutubeDL` and `FFmpeg` runtimes once on IO dispatcher
  - `updateYtDlp` — update pure-Python `yt-dlp` zipapp from inside the app
  - `extractInfo(url, cookiesPath)` — run `yt-dlp -J` equivalent and return JSON metadata + format list
  - `download(requestJson)` — execute download with process ID tracking & cancellation
- Expose `EventChannel("io.github.fyou00.klipfetch/ytdlp_progress")` streaming `{taskId, progress, speed, etaSeconds, status, outputPath, error}`.

#### 1.3 Dart Smart URL Router (`lib/services/url_router_service.dart`)
- Validate incoming URLs strictly against **TikTok, Instagram, and YouTube** domains (reject unsupported URLs clearly in UI).
- Route `YouTube` → `YtDlpService` directly.
- Route `TikTok` & `Instagram` → Rust `libreget-core` FFI first; on extraction/HTTP parse error, automatically retry via `YtDlpService` and record fallback telemetry in the task log.

### Phase 1 Verification & Definition of Done
- `cargo ndk -t arm64-v8a build --manifest-path rust/Cargo.toml --release` compiles `libklipfetch_ffi.so`.
- `flutter analyze && flutter test` passes with generated FRB bindings.
- `flutter build apk --debug --target-platform android-arm64` succeeds locally and on GitHub Actions.
- Smoke test on device/emulator extracts metadata JSON for 1 YouTube link, 1 TikTok link, and 1 public Instagram Reel link.

---

## Phase 2 — Android-Native UX & Resilient Background Queue

### Goals
Deliver a responsive Material 3 Android experience with Share Sheet integration, persistent background downloads, and MediaStore gallery export.

### Tasks

#### 2.1 State Management & Navigation (`lib/`)
- Add `flutter_riverpod`, `go_router`, `receive_sharing_intent` (`^1.8.1`), `path_provider`, `permission_handler`, and `device_info_plus`.
- Build core screens:
  - **Home (`features/home/`)**: Smart paste box, clipboard link detection banner, rich preview card (thumbnail, author, duration), resolution/format selector (Video MP4/MKV vs Audio M4A/MP3/Opus), subtitle toggle.
  - **Downloads (`features/downloads/`)**: Active & completed tabs, real-time speed/ETA/phase telemetry (`Connecting`, `Downloading`, `Muxing`, `Saving to Downloads`), pause/resume/retry/cancel controls, open/share finished media.
  - **Settings (`features/settings/`)**: Default quality, audio format, download concurrency, `yt-dlp` updater button, cookie management entry.

#### 2.2 Android Share Sheet & Deep Link Receiver
- Add `ACTION_SEND` (`text/plain`) intent filters in `AndroidManifest.xml` so sharing a link directly from the **YouTube**, **TikTok**, or **Instagram** Android apps opens KlipFetch straight to the format picker bottom sheet.

#### 2.3 Foreground Service & Scoped Storage Export
- Implement `DownloadForegroundService.kt` (`FOREGROUND_SERVICE_DATA_SYNC` permission on Android 14+ / API 34+):
  - Displays live progress notification with Pause / Cancel action intents.
  - Holds partial wakelock only while active tasks are running.
- Implement `MediaStoreExporter.kt`:
  - Downloads stage in app private cache (`cacheDir/staging/`) so `yt-dlp`/FFmpeg/Rust have unrestricted POSIX file access.
  - On completion, atomically copy/insert into public `Downloads/KlipFetch/{TikTok,Instagram,YouTube}/` via Android `MediaStore.Downloads` / `MediaStore.Video` / `MediaStore.Audio` so files appear immediately in the Android Gallery and Files apps.

#### 2.4 Persistent SQLite Queue
- Persist queue items, resolved options, engine used (`rust-core` vs `yt-dlp`), partial progress, and retry counts in Rust SQLite (`rusqlite`) with WAL enabled.
- Resume interrupted downloads automatically on app restart or network recovery.

### Phase 2 Verification & Definition of Done
- Sharing a link from YouTube/TikTok/Instagram Android app opens KlipFetch and populates the preview sheet automatically.
- Locking the screen during a >100 MB download keeps the transfer alive via Foreground Service without OS termination.
- Completed files appear inside `Downloads/KlipFetch/<Platform>/` and are playable by stock Android Gallery/Files apps.

---

## Phase 3 — Platform-Specific Auth, Edge Cases & Polish

### Goals
Handle logged-in content, stories, adaptive 4K muxing, subtitles, and reliability edge cases across all 3 target platforms.

### Tasks

#### 3.1 In-App Auth Browser (`flutter_inappwebview` 6.x)
- Build `AuthBrowserScreen` with dedicated login shortcuts for **Instagram**, **TikTok**, and **YouTube**.
- Use `CookieManager.instance().getCookies(url)` to capture **`HttpOnly`** session cookies (e.g., Instagram `sessionid`, `ds_user_id`, `csrftoken`) and serialize them in Netscape `cookies.txt` format inside app-private storage for both `libreget-core` and `yt-dlp`.
- Provide per-platform "Test Session" and "Clear Cookies" actions in Settings.

#### 3.2 Platform-Specific Refinements
- **Instagram**:
  - Support Posts, Reels, multi-item Carousels, Stories (using session cookies without triggering seen state), Highlights, and Reel audio extraction.
  - Respect rate-limit pacing from `libreget-core` to protect user accounts.
- **TikTok**:
  - Watermark-free video download, photo carousel/slideshow download (individual images or audio+images), and audio-only export.
- **YouTube**:
  - Upper-bound quality matching (`height <= target`, supporting 2160p/4K, 1440p/2K, 1080p, 720p, 480p).
  - Adaptive DASH video+audio muxing via bundled FFmpeg, Shorts, Playlists (selective item picker), SponsorBlock segment removal/skipping, and SRT/VTT subtitle embedding or sidecar export.
  - In-app `yt-dlp` zipapp version check and one-tap updater.

### Phase 3 Verification & Definition of Done
- Instagram Story & private post download succeeds using cookies captured via `AuthBrowserScreen`.
- TikTok video downloads without watermark; photo carousel downloads all slides cleanly.
- YouTube 1080p/4K adaptive download merges video + audio cleanly via FFmpeg with QuickJS-NG solving `nsig` challenges.

---

## Phase 4 — Release Engineering & Distribution

### Goals
Automate reproducible, signed APK releases for non-Play Store distribution.

### Tasks
1. **GitHub Actions Release Workflow (`.github/workflows/release.yml`)**:
   - Trigger on semantic version tags (`v*.*.*`).
   - Build Rust FFI binaries via `cargo-ndk` for `arm64-v8a` and `armeabi-v7a`.
   - Build signed `--split-per-abi` release APKs using repository keystore secrets (`KEYSTORE_BASE64`, `KEY_ALIAS`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`).
   - Publish APKs + SHA-256 checksums to GitHub Releases.
2. **Obtainium & F-Droid / IzzyOnDroid Preparation**:
   - Add `fastlane/metadata/android/` (app description, screenshots, changelog).
   - Verify reproducible/clean GPL-3.0 dependency audit (no proprietary Play Services / GMS blobs).
3. **Device QA Matrix**:
   - Test on Android 10 (API 29), Android 12 (API 31), Android 14 (API 34), and Android 15 (API 35) covering SELinux W^X, notification permissions (`POST_NOTIFICATIONS`), and `FOREGROUND_SERVICE_DATA_SYNC`.

### Phase 4 Verification & Definition of Done
- Tagging `v0.1.0` triggers automated release APK builds (`klipfetch-v0.1.0-arm64-v8a.apk`, `klipfetch-v0.1.0-armeabi-v7a.apk`) with verified SHA-256 sums.
- Clean install and full E2E test pass on physical Android devices without Google Play Services.
