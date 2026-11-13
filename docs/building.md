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

## Releases from CI

`.github/workflows/release.yml` publishes a GitHub Release when a `v*` tag is
pushed:

```bash
# pubspec.yaml must already say 1.1.5, and CHANGELOG.md must have a
# "## v1.1.5" section — the workflow fails on either mismatch.
git tag v1.1.5 && git push origin v1.1.5
```

It attaches two APKs, their `SHA256SUMS.txt` and the R8 mapping files:

| Artifact | Flavor | Signing |
|---|---|---|
| `vyana-<version>-generic-unsigned.apk` | `googlePlay` | none — sign it yourself before installing |
| `vyana-<version>-solana-dappstore.apk` | `dappStore` | the dApp Store key, when the secrets below are set |

Running the workflow by hand (**Actions → Release → Run workflow**) publishes a
**prerelease** instead, so a dry run is never served as the current version.

### Repository secrets for dApp Store signing

Four, under **Settings → Secrets and variables → Actions → New repository
secret**. Without them the workflow still runs and publishes, but the dApp
Store APK comes out unsigned and says so in the release body.

| Secret | Value |
|---|---|
| `DAPPSTORE_KEYSTORE_BASE64` | The keystore file, base64-encoded (see below) |
| `DAPPSTORE_STORE_PASSWORD` | `dappStoreStorePassword` from `android/key.properties` |
| `DAPPSTORE_KEY_PASSWORD` | `dappStoreKeyPassword` |
| `DAPPSTORE_KEY_ALIAS` | `dappStoreKeyAlias` (e.g. `vyana-dappstore`) |

Encode the keystore as one line, with no trailing newline:

```bash
base64 -i android/keystores/vyana-dappstore.keystore | tr -d '\n' | pbcopy
```

CI writes an `android/key.properties` holding **only** the `dappStore*` entries
and deletes it afterwards. That is what makes the two builds differ:
`app/build.gradle.kts` creates a signing config only for a flavor whose entries
are filled in, so `googlePlay` has none and comes out unsigned. No build-file
change is needed to tell them apart.

> Keep this key. The dApp Store, like Play, identifies the app by its signing
> certificate — losing it means publishing a new listing rather than an update.
> It must stay separate from the Play upload key.

## Submit to Solana dApp Store

Signed APK → [publish.solanamobile.com](https://publish.solanamobile.com)

Docs: [Build and sign an APK](https://docs.solanamobile.com/dapp-store/build-and-sign-an-apk)
## Packaging Nova's voice

Nova speaks with [Kokoro](https://github.com/hexgrad/kokoro) (Apache 2.0),
run on the phone through [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx)
(Apache 2.0). The app never fetches the model from a third-party mirror at
runtime, so the release has to be mirrored on our own host first.

### Which build, and why

`kokoro-en-v0_19` from sherpa-onnx's pretrained TTS models — English, 11
voices, full fp32 weights.

| File | Size |
|---|---|
| `model.onnx` | 330 MB |
| `voices.bin` | 5.5 MB |
| `tokens.txt` | 1.1 KB |
| `espeak-ng-data/` | ~18 MB |
| **Total** | **~355 MB** |

Deliberately **not quantised**. int8 roughly thirds the model, but its
spectral correlation against fp32 is about 0.92 — audible, in a voice whose
whole job is to sound calm during a practice. int8 also saves download size
and memory rather than inference time, so the usual reason to accept that
loss does not apply. The multi-lang packs carry a Chinese lexicon and a 26 MB
voice bank we never call; this pack's `voices.bin` is 5.5 MB, which is where
the real saving is.

There is no `kokoro-v0.19-int8` upstream, whatever an earlier pin said: v0.19
ships fp32 only, and the int8 builds are the multi-lang packs.

### Mirroring it

For each file (`model.onnx`, `voices.bin`, `tokens.txt`,
`espeak-ng-data.tar`):

1. Download it from the official sherpa-onnx release and check it against the
   checksum published with that release. Do this once, at packaging time.
2. Upload that exact file to
   `https://cdn.seeknirvana.app/voices/kokoro/kokoro-en-v0_19/<file>` over
   HTTPS.
3. Record its URL, `sha256sum` output and byte size as a `PinnedAsset` in
   `kNovaVoiceFiles` in `lib/src/services/nova_voice_assets.dart`.

The app then verifies every file against its pinned digest after download and
again before first load, deleting and retrying once on a mismatch. A second
mismatch raises `NovaVoiceIntegrityException` and nothing is loaded.

### Until it is mirrored

`kNovaVoiceFiles` is empty, `novaVoiceConfigured` is false, nothing is
downloaded, and **reading aloud is simply unavailable**. It does not fall
back to the phone's own text-to-speech: `flutter_tts` is only ever as good as
the engine the phone happens to have, and on a phone without Google services
— which the dApp Store build cannot assume — that is a flat screen-reader
voice, which is worse than silence for guidance. Guides › Vani Voice says so,
and the "Speak replies aloud" switch stays off and disabled.

`AppTtsService` keeps `flutter_tts` for one job only: setting the shared
`AVAudioSession` category, which is process-wide and so governs Kokoro's
playback through `audioplayers` and mic capture through `record`. It can be
replaced by `audioplayers`' own `AudioContext` — left as is because that is
the routing already proven on device.

Confirm `kGuideModelSizeLabel` against the real combined download on a device
once the files exist — it is the Gemma bundle plus ~355 MB of voice.
