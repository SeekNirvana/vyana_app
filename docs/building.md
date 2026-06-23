# Building Vyana App

## Prerequisites

- Flutter SDK (see `pubspec.yaml` for Dart SDK constraint)
- Android Studio / Xcode for platform toolchains
- For release APKs: your own signing keystore (never commit it)

## Environment

```bash
cp .env.example .env
```

Edit `.env` for wallet/RPC features you need. Ring-only development works without
a real Reown project ID on Solana Mobile devices (native MWA).

## Debug

```bash
flutter pub get
flutter run
```

### Android emulator / device

```bash
flutter run --flavor googlePlay
```

`googlePlay` is also the default flavor (`pubspec.yaml` → `default-flavor`), so
plain `flutter run` works too — including the IDE Run button.

For Seeker/Saga builds:

```bash
flutter run --flavor dappStore
```

### iOS

Requires Xcode 16+ and iOS 16 deployment target (set in `ios/Podfile`).

Vyana mirrors the Android flavors as Xcode schemes (`googlePlay`, `dappStore`).
`googlePlay` is the default (`pubspec.yaml` → `default-flavor`), so plain
`flutter run` works on a connected iPhone:

```bash
cd ios && pod install && cd ..
flutter run
```

For the dApp Store scheme:

```bash
flutter run --flavor dappStore
```

## Release (Android)

Vyana ships two product flavors:

| Flavor | Use |
|--------|-----|
| `googlePlay` | Google Play distribution |
| `dappStore` | Solana dApp Store (Seeker/Saga) |

### Signing setup (local only)

```bash
# Generate your own keystore — do not use production keys from others
keytool -genkey -v -keystore android/keystores/vyana-dappstore.keystore \
  -alias vyana-dappstore -keyalg RSA -keysize 2048 -validity 10000

cp android/key.properties.example android/key.properties
# Edit key.properties with your passwords
```

### dApp Store APK (arm64)

**Always use the script** — never `flutter build apk` alone for store uploads.

```bash
./scripts/pre-store-upload.sh
```

That runs `flutter analyze`, `flutter test`, a **clean** release build, signing, and
**mandatory APK verification** (`scripts/verify-release-apk.sh`). The build **fails**
if the APK is missing compiled features (catches stale incremental builds that bump
the version but drop new Dart code).

Build only (after tests already passed):

```bash
./scripts/build-dapp-store-apk.sh
```

Output:

```
build/app/outputs/flutter-apk/app-dappstore-release.apk
```

### Before every store upload

1. Run `./scripts/pre-store-upload.sh` (or at minimum `./scripts/build-dapp-store-apk.sh`)
2. Confirm the script prints `Release APK verified` — if it fails, **do not upload**
3. Install the APK on a Seeker and spot-check new features in **release** mode (not debug)
4. When adding features, append fingerprints to `scripts/release-manifest.txt`

### Clean rebuild

If a release APK shows stale UI after code changes:

```bash
flutter clean
flutter pub get
./scripts/build-dapp-store-apk.sh
```

### R8 / ProGuard

Release builds set `shrink=false` in `android/gradle.properties` because heavy
JNI plugins (MediaPipe, whisper, ring SDK) crash when minified. Do not enable
R8 shrinking without extensive native testing.

## Analyze & test

```bash
flutter analyze
flutter test
```

## Submit to Solana dApp Store

Signed APK → [publish.solanamobile.com](https://publish.solanamobile.com)

Docs: [Build and sign an APK](https://docs.solanamobile.com/dapp-store/build-and-sign-an-apk)