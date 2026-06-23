#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEY_PROPS="$ROOT/android/key.properties"
KEYSTORE="$ROOT/android/keystores/vyana-dappstore.keystore"
APK_DIR="$ROOT/build/app/outputs/flutter-apk"

die() {
  echo "error: $*" >&2
  exit 1
}

[[ -f "$KEY_PROPS" ]] || die "Missing android/key.properties — run: cp android/key.properties.example android/key.properties"
[[ -f "$KEYSTORE" ]] || die "Missing dApp Store keystore — run:
  keytool -genkey -v -keystore android/keystores/vyana-dappstore.keystore \\
    -alias vyana-dappstore -keyalg RSA -keysize 2048 -validity 10000"

cd "$ROOT"
flutter pub get
# Avoid stale incremental snapshots omitting recent Dart changes (e.g. new UI rows).
flutter clean
flutter build apk --release --flavor dappStore --target-platform android-arm64

APK="$APK_DIR/app-dappstore-release.apk"
[[ -f "$APK" ]] || die "Expected APK not found at $APK"

"$ROOT/scripts/verify-release-apk.sh" "$APK"

echo ""
echo "Signed dApp Store APK (verified):"
echo "  $APK"
echo ""
echo "Verify signing:"
if [[ -n "${ANDROID_HOME:-}" && -d "$ANDROID_HOME/build-tools" ]]; then
  APKSIGNER="$(find "$ANDROID_HOME/build-tools" -name apksigner -type f | sort -V | tail -1)"
  if [[ -n "$APKSIGNER" ]]; then
    echo "  $APKSIGNER verify --print-certs \"$APK\""
    "$APKSIGNER" verify --print-certs "$APK"
  else
    echo "  apksigner not found under \$ANDROID_HOME/build-tools"
  fi
else
  echo "  Set ANDROID_HOME, then:"
  echo "  \$ANDROID_HOME/build-tools/<version>/apksigner verify --print-certs \"$APK\""
fi
echo ""
echo "Upload to: https://publish.solanamobile.com"