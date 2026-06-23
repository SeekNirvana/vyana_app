# Changelog

## v1.0.2 — 2026-06-23

### Added

- **Exit confirmation** on main tabs — Android hardware back shows a confirm
  dialog instead of closing the app (pushed screens such as scan and vitals
  still pop normally)
- **Reset PRANA ring** on the You tab — when connected, factory-resets the ring
  if `isSupportFactorySettings` is available; otherwise erases on-ring health
  history via SDK delete commands (sleep, steps, vitals, etc.), then unpairs,
  clears local vitals/cache, and returns to Home (strong confirmation with
  backup warning; unsupported optional deletes such as sport do not fail reset)

## v1.0.1 — 2026-06-19

First open-source release.

### Added

- Privacy & sovereignty screen with plain-language data policy
- Redesigned About screen with Vyana branding, mission copy, and link to seeknirvana.com

### Changed

- New Vyana logo on app icon, splash screen, and wallet connect metadata
- Home welcome copy: "Your wellness, on your terms."
- Updated PRANA ring product gallery images

### Fixed

- Release build launch crash on Solana Seeker (R8/JNI)
- Mobile Wallet Adapter icon display when connecting wallet

### Build

- Dual Android flavors: `googlePlay` and `dappStore`
- dApp Store release signing via `key.properties` (local only, not in repo)