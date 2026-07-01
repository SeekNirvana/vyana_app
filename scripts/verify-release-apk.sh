#!/usr/bin/env bash
# Gate store uploads: fail if a release APK is missing compiled features or version.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="${RELEASE_MANIFEST:-$ROOT/scripts/release-manifest.txt}"

die() {
  echo "error: $*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <release.apk>

Checks that the APK's arm64 libapp.so contains every pattern in:
  $MANIFEST

Also verifies versionName/versionCode match pubspec.yaml.

Run automatically at the end of scripts/build-dapp-store-apk.sh — do not skip.
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0
[[ -n "${1:-}" ]] || { usage >&2; die "APK path required"; }

APK="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
[[ -f "$APK" ]] || die "APK not found: $APK"
[[ -f "$MANIFEST" ]] || die "Release manifest not found: $MANIFEST"

PUBSPEC="$ROOT/pubspec.yaml"
[[ -f "$PUBSPEC" ]] || die "pubspec.yaml not found"

EXPECTED_VERSION="$(grep -E '^version:' "$PUBSPEC" | awk '{print $2}')"
[[ -n "$EXPECTED_VERSION" ]] || die "Could not read version from pubspec.yaml"
EXPECTED_NAME="${EXPECTED_VERSION%%+*}"
EXPECTED_CODE="${EXPECTED_VERSION##*+}"

LIBAPP="$(mktemp)"
STRINGS_FILE="$(mktemp)"
trap 'rm -f "$LIBAPP" "$STRINGS_FILE"' EXIT
unzip -p "$APK" lib/arm64-v8a/libapp.so >"$LIBAPP" 2>/dev/null \
  || die "No lib/arm64-v8a/libapp.so in APK (wrong ABI or corrupt APK?)"
LC_ALL=C strings "$LIBAPP" >"$STRINGS_FILE"

# Flutter AOT stores many UI literals as UTF-16LE in libapp.so; `strings` only
# extracts ASCII runs, so also scan the raw snapshot for UTF-8 and UTF-16LE.
libapp_contains() {
  local pattern="$1"
  LC_ALL=C grep -Fq "$pattern" "$STRINGS_FILE" && return 0
  python3 - "$LIBAPP" "$pattern" <<'PY'
import sys

libapp_path, pattern = sys.argv[1], sys.argv[2]
data = open(libapp_path, "rb").read()
encoded = (
    pattern.encode("utf-8"),
    pattern.encode("utf-16-le"),
)
sys.exit(0 if any(chunk in data for chunk in encoded) else 1)
PY
}

echo "Verifying release APK:"
echo "  $APK"
echo "  manifest: $MANIFEST"
echo "  expected version: $EXPECTED_NAME ($EXPECTED_CODE)"
echo ""

missing=0
while IFS= read -r pattern || [[ -n "$pattern" ]]; do
  [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
  if ! libapp_contains "$pattern"; then
    echo "  MISSING  $pattern"
    missing=$((missing + 1))
  else
    echo "  ok       $pattern"
  fi
done <"$MANIFEST"

if [[ "$missing" -gt 0 ]]; then
  echo ""
  die "$missing required release fingerprint(s) missing.

This usually means a stale incremental build (version bumped, Dart code not recompiled).
Fix:
  flutter clean && ./scripts/build-dapp-store-apk.sh

Never upload an APK that fails this check."
fi

# Version from APK badging (aapt/aapt2) or fallback to unzip + strings on versionName.
ACTUAL_NAME=""
ACTUAL_CODE=""
if command -v aapt >/dev/null 2>&1; then
  BADGING="$(aapt dump badging "$APK" 2>/dev/null || true)"
elif [[ -n "${ANDROID_HOME:-}" ]]; then
  AAPT="$(find "$ANDROID_HOME/build-tools" -name aapt -type f 2>/dev/null | sort -V | tail -1)"
  [[ -n "$AAPT" ]] && BADGING="$("$AAPT" dump badging "$APK" 2>/dev/null || true)"
fi

if [[ -n "${BADGING:-}" ]]; then
  ACTUAL_NAME="$(printf '%s\n' "$BADGING" | sed -n "s/.*versionName='\([^']*\)'.*/\1/p" | head -1)"
  ACTUAL_CODE="$(printf '%s\n' "$BADGING" | sed -n "s/.*versionCode='\([^']*\)'.*/\1/p" | head -1)"
fi

if [[ -z "$ACTUAL_NAME" || -z "$ACTUAL_CODE" ]]; then
  echo ""
  echo "warning: could not read APK version via aapt — fingerprint check passed, version check skipped"
  echo "  install Android build-tools or set ANDROID_HOME for full verification"
  exit 0
fi

echo ""
echo "  APK versionName: $ACTUAL_NAME"
echo "  APK versionCode: $ACTUAL_CODE"

[[ "$ACTUAL_NAME" == "$EXPECTED_NAME" ]] \
  || die "versionName mismatch: APK=$ACTUAL_NAME pubspec=$EXPECTED_NAME"
[[ "$ACTUAL_CODE" == "$EXPECTED_CODE" ]] \
  || die "versionCode mismatch: APK=$ACTUAL_CODE pubspec=$EXPECTED_CODE"

SHA="$(shasum -a 256 "$APK" | awk '{print $1}')"
echo ""
echo "Release APK verified."
echo "  SHA-256: $SHA"