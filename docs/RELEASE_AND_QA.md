# Release Engineering, Distribution & Device QA Guide

This document describes how to sign and publish **KlipFetch** Android releases (`v*.*.*`), track updates with **Obtainium** or **F-Droid / IzzyOnDroid**, and verify behavior across target Android OS versions.

---

## 1. Keystore Setup & GitHub Actions Secrets

> **Never commit `*.jks`, `*.keystore`, or `android/key.properties` to Git.** Keep them backed up offline in a password manager.

### Generate a Release Keystore
```bash
keytool -genkeypair -v \
  -keystore klipfetch-release.jks \
  -alias klipfetch \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000
```

### Upload Signing Secrets to GitHub (`fyou00/klipfetch`)
```bash
base64 -i klipfetch-release.jks | tr -d '\n' | gh secret set KEYSTORE_BASE64 -R fyou00/klipfetch
gh secret set KEY_ALIAS -R fyou00/klipfetch --body "klipfetch"
gh secret set KEYSTORE_PASSWORD -R fyou00/klipfetch
gh secret set KEY_PASSWORD -R fyou00/klipfetch
```

### Local Release Build (Optional)
Create `android/key.properties` (ignored by Git):
```properties
storeFile=/absolute/path/to/klipfetch-release.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=klipfetch
keyPassword=YOUR_KEY_PASSWORD
```
Alternatively export `KLIPFETCH_KEYSTORE_PATH`, `KLIPFETCH_KEYSTORE_PASSWORD`, `KLIPFETCH_KEY_ALIAS`, and `KLIPFETCH_KEY_PASSWORD` before running `flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64`.

---

## 2. Cutting a Release vs. Dry-Run Testing

### Automated Dry-Run (No Signing Secrets or GitHub Release Created)
```bash
gh workflow run release.yml -R fyou00/klipfetch -f dry_run=true -f version_tag=v0.1.0-rc1
```
The workflow cross-compiles Rust FFI for both `arm64-v8a` and `armeabi-v7a`, runs tests and dependency audits, builds split R8-minified release APKs (`dist/`), verifies native libraries inside both APKs, generates `SHA256SUMS.txt`, and uploads a downloadable CI artifact.

### Publishing a Tagged Release
Once signing secrets are configured:
```bash
# Ensure pubspec.yaml & fastlane/metadata/android/{en-US,id}/changelogs/<versionCode>.txt are updated
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```
GitHub Actions [`.github/workflows/release.yml`](../.github/workflows/release.yml) automatically builds and attaches:
- `klipfetch-v0.1.0-arm64-v8a.apk` (64-bit modern Android devices)
- `klipfetch-v0.1.0-armeabi-v7a.apk` (legacy 32-bit ARM devices)
- `SHA256SUMS.txt` (cryptographic checksums verified in CI)

---

## 3. Non-Play Store Distribution (Obtainium & F-Droid / IzzyOnDroid)

### Obtainium
1. Open **Obtainium** → **Add App**.
2. Set App Source URL to: `https://github.com/fyou00/klipfetch`
3. Under APK filter / regex, match your device ABI:
   - Modern phones (64-bit): `.*arm64-v8a\.apk$`
   - Legacy 32-bit phones: `.*armeabi-v7a\.apk$`
4. Tap **Add** — Obtainium will automatically pull new `v*.*.*` GitHub Releases.

### F-Droid / IzzyOnDroid Compliance
- **License**: GNU General Public License v3.0 ([`LICENSE`](../LICENSE)).
- **Fastlane metadata**: localized English (`en-US`) and Indonesian (`id`) store metadata and changelogs live under [`fastlane/metadata/android/`](../fastlane/metadata/android/).
- **FOSS dependency audit**: run `./scripts/audit_dependencies.sh` to verify zero Google Play Services (`com.google.android.gms`), Firebase, or telemetry SDKs, pure-Rust TLS (`rustls`), and Android-only structure.

---

## 4. Physical Device QA Matrix (Manual Verification Checklist)

| Android Version | API | Key Verification Checks |
|---|---|---|
| **Android 10** | API 29 | Scoped Storage `MediaStore.Downloads` export into `Downloads/KlipFetch/{TikTok,Instagram,YouTube}/`, SELinux W^X execution (`libklipfetch_ffi.so`, Python, FFmpeg, QuickJS-NG from `jniLibs`) |
| **Android 12** | API 31 | Foreground Service (`DownloadForegroundService`) background continuity when locking screen during >100 MB transfer, Share Sheet `ACTION_SEND` launch |
| **Android 14** | API 34 | `POST_NOTIFICATIONS` permission flow in Settings, `FOREGROUND_SERVICE_DATA_SYNC` enforcement, `AuthWebViewActivity` `HttpOnly` cookie capture without `; wv` Google login block |
| **Android 15** | API 35 | Edge-to-edge WindowInsets in `AuthWebViewActivity`, 4K/1080p YouTube DASH FFmpeg muxing + SponsorBlock + SRT/VTT subtitles, TikTok watermark-free + slideshow audio, Instagram Story & multi-file Carousel batch export |
