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

### iOS

Requires Xcode 16+ and iOS 16 deployment target (set in `ios/Podfile`).

```bash
cd ios && pod install && cd ..
flutter run
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

```bash
./scripts/build-dapp-store-apk.sh
```

Output:

```
build/app/outputs/flutter-apk/app-dappstore-release.apk
```

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