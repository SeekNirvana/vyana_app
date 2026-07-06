# Changelog

## v1.0.4 — 2026-07-06

### Added

- **Calm redesign** — every screen retuned for mindfulness. The palette softens
  to sage/twilight neutrals with de-saturated vital hues; Home is now number-free
  (a slow **breathing orb** and worded state replace the numeric readiness ring)
  and all scores, tiles, charts, and insights live one tap away on the new
  **"Your numbers"** screen (readiness with drivers, vitals grid, movement stats,
  AI insights, and doorways to sleep, weekly patterns, and the data log).
- **Live outdoor sessions with a real map** — GPS runs/walks/rides now show an
  OpenStreetMap route map (pure Dart, no Google services, dark-mode tinted) with
  a live position marker, follow/recenter, live + average **pace**, elevation
  gain, and heart rate with zone bar on one screen.
- **Spoken 10-minute splits** — during movement sessions Vyana speaks time,
  distance, pace, heart rate + zone, and elevation gain every 10 minutes (as the
  practice catalog promised), plus a callout at **every completed kilometre**
  with average pace. Trail runs get steep-climb and descent-care cues; indoor
  and strength sessions get zone-matched encouragement.
- **Meal logging polish** — a proper photo flow: large capture card with camera
  or library, change/remove overlay chips, meal-type pills with icons
  (breakfast/lunch/dinner/snack/hydration), photo-banner meal cards in the
  journal, a detail sheet with pinch-to-zoom **full-screen photo viewer**, and
  the ability to remove meals (photo file cleaned up) and journal entries.

### Fixed

- **GPS on Android 12+** — location permissions were declared with
  `maxSdkVersion="30"` (a BLE-scanning legacy), so modern devices — including
  every Solana Seeker — could never grant location and outdoor sessions recorded
  no route, pace, or elevation. Permissions are now declared for all versions.
- Live session screens show a clear "Location is off" panel with a settings
  shortcut when permission is declined; heart rate keeps recording regardless.

## v1.0.3 — 2026-06-30

### Added

- **Monitor all vitals** — a one-tap check-in on Home that reads every supported
  vital in turn (heart rate, SpO₂, temperature, HRV, blood pressure, and more —
  ECG excluded), auto-reconnecting to the ring first if needed, then syncs so the
  results land on the phone. Set the phone aside and get a **notification** when
  it's done. Also triggerable from the home-screen widget.
- **State-of-being homepage** — Home now leads with a single "How you're being"
  card that combines the readiness ring and worded state into one clear signal
  (no more duplicate "Steady"), felt signal chips, a horizontally-scrollable
  biomarker strip (tap any to open its chart), and both **Check vitals** and
  **Sync** actions. Live progress shows while a check-in runs.
- **Home-screen widgets** — Android App Widgets (and iOS WidgetKit source, see
  `ios/VyanaWidget/SETUP.md`): a live "state of being" tile showing your worded
  state plus a compact 2-column **biomarker grid** (Heart, Oxygen, HRV, Stress,
  Glucose, Steps), resizable from 2×2 up, and a one-tap "Monitor all vitals"
  action button that deep-links in to start a run. iOS medium/large render the
  same grid.
- **Stress rhythm** — the "Pressure" data point is now **Stress**, shown as a
  Calm / Activated / Stressed band chart derived from HRV so it populates and
  refreshes on every sync (the ring stores no stress series of its own).

### Changed

- After an automatic reconnect + sync, the latest state of being is pushed to the
  home-screen widgets.
- **Reading quality gates** — vitals are now validated against plausible ranges
  grounded in real ring data (HRV 10–150, SpO₂ 70–100, glucose 2–35, etc.).
  Loose-contact "all-zero" records are dropped whole, and single-field artefacts
  (e.g. a bogus HRV of 179) are filtered from the current value, charts, sleep
  averages, and history. A Monitor-all run now retries a metric on loose contact
  and flags anything that still won't read as a "retake".

### Fixed

- HRV no longer shows impossible spikes (e.g. 179 ms) on the graph or in sleep
  averages; the artefact cluster is filtered out.
- Glucose, SpO₂ and HRV no longer read **0** from a loose-contact sample — the
  newest *plausible* value is shown instead, both live and in history.
- The Measurements-screen charts (a second code path) now apply the same gates,
  so HRV/SpO₂/glucose artefacts are gone there too, not just on Home.
- Running a single test with poor contact now prompts a retake instead of
  recording a zero.

## v1.0.2 — 2026-06-23

### Added

- **iOS flavor schemes** (`googlePlay`, `dappStore`) so `flutter run` works on
  iPhone alongside Android product flavors (uses `default-flavor: googlePlay`)
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