#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> [1/5] Checking GPL-3.0 license file..."
if ! grep -q "GNU GENERAL PUBLIC LICENSE" LICENSE || ! grep -q "Version 3" LICENSE; then
  echo "ERROR: LICENSE does not appear to be GNU GPL v3.0"
  exit 1
fi

echo "==> [2/5] Checking Android-only workspace invariant..."
for platform_dir in ios web macos linux windows; do
  if [ -d "$platform_dir" ]; then
    echo "ERROR: Forbidden non-Android platform directory present: $platform_dir/"
    exit 1
  fi
done

echo "==> [3/5] Checking for proprietary Google Play Services / Firebase / tracker SDKs..."
FORBIDDEN_PATTERN='com\.google\.android\.gms|com\.google\.firebase|firebase_|google_mobile_ads|onesignal|appsflyer|mixpanel|amplitude'
for target_file in pubspec.yaml pubspec.lock android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml; do
  if [ ! -f "$target_file" ]; then
    echo "ERROR: Expected file missing: $target_file"
    exit 1
  fi
  if grep -qiE "$FORBIDDEN_PATTERN" "$target_file"; then
    echo "ERROR: Proprietary/telemetry dependency detected in $target_file"
    grep -niE "$FORBIDDEN_PATTERN" "$target_file"
    exit 1
  fi
done

echo "==> [4/5] Checking Rust lockfiles for pure-Rust TLS and minimal mobile scope..."
RUST_FORBIDDEN_CRATES='name = "(openssl-sys|native-tls|tauri|librqbit|x11rb)"'
for lockfile in rust/Cargo.lock third_party/libreget-core/Cargo.lock; do
  if [ ! -f "$lockfile" ]; then
    echo "ERROR: Expected lockfile missing: $lockfile"
    exit 1
  fi
  if grep -qE "$RUST_FORBIDDEN_CRATES" "$lockfile"; then
    echo "ERROR: Forbidden Rust crate found in $lockfile"
    grep -nE "$RUST_FORBIDDEN_CRATES" "$lockfile"
    exit 1
  fi
done

echo "==> [5/5] Checking Fastlane metadata constraints and keystore secret hygiene..."
for locale in en-US id; do
  title_file="fastlane/metadata/android/$locale/title.txt"
  short_file="fastlane/metadata/android/$locale/short_description.txt"
  full_file="fastlane/metadata/android/$locale/full_description.txt"
  changelog_file="fastlane/metadata/android/$locale/changelogs/1.txt"

  for f in "$title_file" "$short_file" "$full_file" "$changelog_file"; do
    if [ ! -s "$f" ]; then
      echo "ERROR: Missing or empty Fastlane metadata file: $f"
      exit 1
    fi
  done

  title_len="$(printf '%s' "$(cat "$title_file")" | wc -m | tr -d ' ')"
  short_len="$(printf '%s' "$(cat "$short_file")" | wc -m | tr -d ' ')"
  if [ "$title_len" -gt 30 ]; then
    echo "ERROR: $title_file exceeds 30 characters ($title_len)"
    exit 1
  fi
  if [ "$short_len" -gt 80 ]; then
    echo "ERROR: $short_file exceeds 80 characters ($short_len)"
    exit 1
  fi
done

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  TRACKED_SECRETS="$(git ls-files | grep -E '\.(jks|keystore|p12)$|^android/key\.properties$' || true)"
  if [ -n "$TRACKED_SECRETS" ]; then
    echo "ERROR: Tracked keystore or signing property files detected:"
    echo "$TRACKED_SECRETS"
    exit 1
  fi
fi

echo "PASS: KlipFetch passed GPL-3.0, non-GMS, Android-only, Rust TLS, and Fastlane audits."
