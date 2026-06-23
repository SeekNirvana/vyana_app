#!/usr/bin/env bash
# Single entry point before uploading to publish.solanamobile.com
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Analyze"
flutter analyze --no-fatal-infos

echo ""
echo "==> Unit & contract tests"
flutter test

echo ""
echo "==> Clean release build + APK verification"
"$ROOT/scripts/build-dapp-store-apk.sh"

echo ""
echo "Ready for dApp Store upload."
echo "  https://publish.solanamobile.com"