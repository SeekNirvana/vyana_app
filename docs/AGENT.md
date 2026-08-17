# Vyana App — Agent Reference & System Architecture

Vyana is a sovereign wellness companion built for the **PRANA Smart Ring** by **Seek Nirvana**. It bridges continuous biometric tracking, mindfulness and movement practices (*Sadhana*), on-device private AI companions (powered by Google Gemma), and decentralized Web3 payments on Solana.

---

## 1. Core Tenets & System Overview

- **Sovereign & Local-First**: All sensitive biometric data, GPS traces, journal entries, and AI interactions remain exclusively on the user's device in an encrypted local database (`Drift` / SQLite). No mandatory user accounts, no cloud telemetry, and no external AI server dependencies.
- **Biometric Intelligence**: Continuous background monitoring and on-demand spot measurements via Bluetooth Low Energy (BLE) using the PRANA Ring SDK (`vyana_sdk`).
- **Sadhana Practice Hub**: Active session tracking for 25+ activities spanning mindfulness, movement, and wellness/recovery with live telemetry, visual breath pacers, GPS mapping, and voice coaching.
- **Private On-Device AI Guides**: Local LLM execution using `flutter_gemma` (Gemma 2B) with specialized personas (Luna, Nova, Maya, Aran, Ravi, Tara) augmented with real-time biometric context.
- **Web3 & Solana Hardware Store**: Native Solana Mobile Wallet Adapter (MWA) for Seeker/Saga devices, Reown AppKit for standard Android/iOS, and on-chain USDC checkout for ordering PRANA rings.

---

## 2. Directory Structure & Key Files

```
vyana_app/
├── lib/
│   ├── main.dart                          # App entry point, lifecycle hooks, theme & shell binding
│   └── src/
│       ├── brand/                         # Brand assets, logos, and icons
│       ├── config/                        # EnvConfig (.env loader, RPC endpoints, Reown project ID)
│       ├── data/
│       │   ├── catalog.dart               # Static activity catalog, guide store, seed data
│       │   ├── db.dart                    # Drift database schema (tables, DAOs, migrations)
│       │   └── db.g.dart                  # Generated Drift code
│       ├── repository.dart                # BLE hardware abstraction & SDK bridge
│       ├── scan_screen.dart               # Ring scanning, pairing, and RSSI discovery
│       ├── models.dart                    # Domain models (Vitals, Sleep, Session summaries)
│       ├── vitals_quality.dart            # Signal quality filters & sensor heuristics
│       ├── dashboard_widgets.dart         # Reusable dashboard metric cards & sparklines
│       ├── sleep_screen.dart              # Sleep stage breakdown & hypnogram visualization
│       ├── measurements.dart              # Spot measurements (HR, SpO2, BP, Stress, ECG)
│       ├── info_panels.dart               # Educational panels for biometric metrics
│       ├── cloud.dart                     # Local export/import and sovereign data management
│       ├── utils.dart                     # Formatting, math helpers, time computations
│       ├── mwa_wallet_picker.dart         # Solana Mobile Wallet Adapter picker
│       ├── screens/                       # Presentation screens
│       │   ├── home_screen.dart           # Home tab (readiness score, ring status, quick practices)
│       │   ├── journal_screen.dart        # Antara journal tab (reflections, dreams, meals)
│       │   ├── journal_editors.dart       # Journal & meal entry creation/editing modals
│       │   ├── practice_screen.dart       # Practice catalog tab (Mindfulness, Wellness, Movement)
│       │   ├── session_screen.dart        # Active practice HUD (metrics, controls, finish flow)
│       │   ├── session_bodies.dart        # Activity-specific HUDs (breath pacer, GPS map, timers)
│       │   ├── guides_screen.dart         # AI Guides tab (chat interface & voice conversation)
│       │   ├── guide_store_screen.dart    # Downloadable guide personas & model manager
│       │   ├── guide_persona_settings_screen.dart # Per-guide prompt tuning & response lengths
│       │   ├── you_screen.dart            # You profile tab (vitals overview, ring settings, wallet)
│       │   ├── vitals_detail_screen.dart  # Detailed multi-day charts for each vital
│       │   ├── trends_screen.dart         # Long-term trend analysis
│       │   ├── weekly_screen.dart         # Weekly strain vs. recovery correlation insights
│       │   ├── profile_screen.dart        # User profile, physical attributes, target metrics
│       │   ├── health_monitoring_screen.dart # Continuous auto-monitoring intervals on ring
│       │   ├── sync_settings_screen.dart  # Periodic background sync settings
│       │   ├── ring_onboarding_screen.dart# Initial ring pairing & setup wizard
│       │   ├── ring_order_screen.dart     # In-app PRANA ring store with USDC checkout
│       │   └── wallet_screen.dart         # Solana / Web3 wallet management & transaction history
│       ├── services/                      # Background services and hardware managers
│       │   ├── app_startup_service.dart   # App startup sequencing & initialization
│       │   ├── app_tts_service.dart       # Native Text-To-Speech engine
│       │   ├── device_capability_service.dart # Platform capability detector (MWA, BLE, Gemma)
│       │   ├── guide_model_manager.dart   # Gemma weights download, verification & storage
│       │   ├── guide_persona_prefs_service.dart # Persona custom system prompts & tuning
│       │   ├── guide_runtime_service.dart # Offline LLM prompt synthesis with health context
│       │   ├── guide_voice_service.dart   # Voice-driven guide chat (TTS + voice synthesis)
│       │   ├── home_widget_service.dart   # Android Home Screen widget updates & deep links
│       │   ├── meal_photo_service.dart    # Camera & gallery image attachments for meals
│       │   ├── ring_foreground_service.dart # Foreground service & background BLE sync isolate
│       │   ├── ring_history_cache_service.dart # Offline cache of ring history pulls
│       │   ├── ring_order_pricing.dart    # Ring SKU pricing & discounts
│       │   ├── ring_order_service.dart    # Ring order database operations
│       │   ├── ring_order_tx_data.dart    # Solana transaction memo & reference payload formats
│       │   ├── ring_usdc_payment_service.dart # SPL USDC transfer transaction builder & sender
│       │   ├── vitals_notification_service.dart # Local notification scheduler for health alerts
│       │   └── vyana_storage_service.dart # App storage directory manager
│       ├── shell/
│       │   └── vyana_shell.dart           # Persistent 5-tab root navigation shell & bottom bar
│       ├── state/                         # Riverpod state notifiers & controllers
│       │   ├── correlation_engine.dart    # Biometric correlation analysis (sleep vs. HRV)
│       │   ├── guide_service.dart         # Active guide state & messaging stream
│       │   ├── home_dashboard.dart        # Home dashboard metric aggregates & readiness
│       │   ├── location_service.dart      # GPS geolocation stream for outdoor activities
│       │   ├── reown_wallet_service.dart  # Reown AppKit / WalletConnect controller
│       │   ├── ring_controller.dart       # PRANA ring BLE controller & state machine
│       │   ├── session_controller.dart    # Active practice session state manager
│       │   ├── session_sync.dart          # Session database sync & persistence
│       │   ├── solana_mobile_wallet_service.dart # Solana Mobile Wallet Adapter controller
│       │   ├── user_profile_controller.dart # User profile state notifier
│       │   ├── voice_cue_service.dart     # Spoken audio cues for exercise intervals/splits
│       │   ├── wallet_controller.dart     # Unified Web3 wallet controller
│       │   └── wallet_platform.dart       # Platform-specific wallet selection
│       ├── theme/                         # App theme, typography (Manrope), and color tokens
│       ├── wellness/                      # High-level wellness state & readiness calculations
│       └── widgets/                       # Reusable UI primitives, buttons, sheets, and charts
└── docs/
    ├── AGENT.md                           # This architecture and agent reference document
    └── building.md                        # Build guides for Android, iOS, Seeker/Saga flavors
```

---

## 3. Subsystem Architecture

### 3.1 PRANA Smart Ring Subsystem (BLE)
- **Ring Controller (`RingController`)**: Manages the BLE connection state machine (`disconnected` → `connecting` → `connected`), pairing persistence via `PranaRingStore`, auto-reconnects, battery status, and sport mode bridging.
- **Exponential Reconnect Backoff**: To conserve device battery while the ring is out of range, passive background reconnection attempts scale from `5s` up to `90s` (`_reconnectBackoff`). User-driven actions reset the backoff immediately.
- **Background Sync (`RingForegroundService`)**: On Android, a foreground service isolate (`ringForegroundServiceCallback`) runs a periodic heartbeat (`kRingForegroundSyncTick`) that instructs the main isolate to pull ring history even while the app is backgrounded.
- **Spot Measurements (`measurements.dart`)**:
  - Live Heart Rate & Real-Time PPG Waveform
  - Blood Oxygen ($SpO_2$)
  - Stress & Pressure
  - Blood Pressure (Systolic / Diastolic estimation)
  - ECG Waveform (Lead-I equivalent contact measurement with live 500Hz rendering)
- **Ring History Cache (`RingHistoryCacheService`)**: Ring data frames (steps, sleep, HR, BP) are cached locally in SQLite to instantly hydrate dashboards on cold start before BLE handshake completes.

### 3.2 Sadhana Practice Engine
- **Activity Catalog (`catalog.dart`)**: Over 25 curated activities organized into three categories:
  1. **Mindfulness**: Meditation, Breathwork, Classical Pranayama, Yoga Nidra, Body Scan, Mantra Meditation, Walking Meditation, Sound Bath, HRV Breathing.
  2. **Wellness & Recovery**: Sun Salutation (*Surya Namaskar*), Yoga Flow, Stretching, Mobility, Pilates, Warm-up, Cool-down, Sauna, Cold Plunge, Recovery Session, NSDR / Nap, Physiotherapy.
  3. **Movement / Sport**: Outdoor Run, Trail Run, Walk, Hike/Trek, Cycling, Indoor Cycling, Treadmill, Rowing, Elliptical, Strength Training, Functional Fitness, HIIT, Jump Rope, Dance, Basketball, Football, Badminton, Tennis, Golf, Swimming, Rock Climbing, Free Workout.
- **Active HUD & Sensors (`session_screen.dart`, `session_bodies.dart`)**:
  - Visual animated breath pacer for breathwork and ratio pranayama (inhale, hold, exhale, hold).
  - Live GPS tracking with route polyline, speed, altitude, and split times (`flutter_map` + `geolocator`).
  - Spoken audio splits and interval cues via `VoiceCueService` and `AppTtsService`.
  - Raw SDK event logging and continuous sample capture into SQLite.

### 3.3 On-Device AI Guides Subsystem
- **Shared Model Architecture**: All personas run locally on Google's **Gemma 2B** (`gemma-2b-it`) quantized model via `flutter_gemma`. A single model download unlocks all personas.
- **Guide Personas**:
  - **Luna** (`luna`): Sleep, circadian rhythms, down-regulation, and recovery.
  - **Nova** (`nova`): Daytime energy, HRV optimization, and athletic vitality.
  - **Maya** (`maya`): Mindfulness, breath awareness, and daily calm.
  - **Aran** (`aran`): Movement, strength programming, and physical intention.
  - **Ravi** (`ravi`): Dream exploration, symbolic reflection, and journaling insights.
  - **Tara** (`tara`): Nourishment, meal reflection, and steady energy.
- **Dynamic Context Injection (`GuideRuntimeService`)**: Prompts are augmented on-the-fly with the user's latest readiness score, sleep duration, resting HR, active streak, recent practices, and journal notes without transmitting data to any cloud service.
- **Voice Mode (`GuideVoiceService`)**: Conversational spoken responses with selectable system TTS voices and real-time audio playback.

### 3.4 Antara Journal (Inner Vault)
- **Reflections & Dreams**: Rich text journaling categorized into Dreams, Reflections, and Ideas with tag filtering.
- **Meal Diary**: Visual meal logging with camera capture (`image_picker`), meal type classification (Breakfast, Lunch, Dinner, Snack, Hydration), and nutritional reflection.
- **AI Refinement**: On-demand guide analysis for journal entries (e.g., Ravi analyzing dream themes, Tara reviewing meal balance).

### 3.5 Solana & Web3 Integration
- **Dual Wallet Backends (`WalletController`)**:
  - **Solana Mobile Wallet Adapter (MWA)**: Used on Solana Mobile devices (Saga, Seeker) for zero-friction native signing.
  - **Reown AppKit (WalletConnect v2)**: Cross-platform fallback for standard Android and iOS devices supporting Solana and Ethereum.
- **In-App PRANA Hardware Store (`RingOrderScreen`, `RingUsdcPaymentService`)**:
  - Native checkout to purchase PRANA smart rings using SPL-USDC on Solana.
  - Generates parameterized transfer transactions with on-chain `memo` instructions containing order IDs, referral codes, and size choices for automated fulfillment.

---

## 4. Database Schema (Drift / SQLite)

The local database is stored at `VyanaStorageService.instance.wellnessPath` under `vyana_vault`:

| Table Name | Description |
|---|---|
| `activity_sessions` | Tracks each completed or active practice (category, activity ID, timestamps, GPS flag, summary JSON). |
| `samples` | Time-series sensor samples (HR, $SpO_2$, HRV, stress, temperature, steps, GPS lat/lng, elevation). |
| `route_points` | High-resolution GPS polyline points for outdoor map rendering. |
| `raw_sdk_events` | Unmodified BLE frames from the ring to guarantee zero data loss. |
| `journal_entries` | Private user notes, dream logs, and reflections with AI refinement status. |
| `meals` | Food and hydration logs with local photo file paths. |
| `guide_persona_prefs`| Custom system prompts, response length (`short`, `balanced`, `detailed`), and temperature overrides per guide. |
| `guide_voice_prefs` | User's preferred TTS voice ID and auto-speech toggles. |
| `ring_history_caches`| Serialized ring history pulls (steps, sleep stages, HR curves) for cold-start hydration. |
| `ring_orders` | Local record of PRANA ring hardware purchases and Solana transaction signatures. |

---

## 5. Navigation & UI Structure

The root interface is managed by `VyanaShell` with 5 primary tabs:

1. **Home (`tabIndex: 0`)**:
   - Live Ring Status (Connected, Syncing, Offline with reconnect status)
   - Readiness Score ($0-100$) and drivers (HRV, Sleep, Resting HR)
   - Contextual greeting (Morning intentions vs. Evening wind-down)
   - Quick practice recommendations & personalized Guide insight cards
   - One-tap "Check vitals" trigger
2. **Journal (`tabIndex: 1`)**:
   - Filterable timeline of Reflections, Dreams, Ideas, and Meals
   - Integrated meal photo logging
   - Deep-dive entry reader with AI guide reflection actions
3. **Practice (`tabIndex: 2`)**:
   - Center elevated lotus action
   - Segmented filter: Mindfulness, Wellness, Movement
   - 25+ activities with duration, guidance mode, and equipment requirements
   - Direct launch into active practice HUD (`SessionScreen`)
4. **Guides (`tabIndex: 3`)**:
   - Direct conversational chat with active AI guide
   - Voice mode toggle with speech animation
   - Persona switcher and Guide Store for downloading models
   - Persona customization (system prompt & response style editor)
5. **You (`tabIndex: 4`)**:
   - Biometric detail screens: Heart Rate, Sleep Hypnogram, $SpO_2$, Stress, Temperature
   - Weekly correlation insights and strain vs. recovery trends
   - Ring Hardware settings: Continuous monitoring rates, battery status, firmware info, unpairing
   - Web3 Wallet connection, address display, and balance check
   - In-app PRANA Ring order screen

---

## 6. Build Flavors & Platform Targets

Refer to [`docs/building.md`](file:///Users/shachindra/Projects/SeekNirvana/vyana_app/docs/building.md) for full build instructions:

- **`googlePlay`** (Default): Standard Android build with Reown AppKit and Google Play Services compatibility.
- **`dappStore`**: Optimized for Solana Mobile devices (Saga, Seeker) with direct Solana Mobile Wallet Adapter integration and Seed Vault support.
- **iOS**: Targets iOS 16.0+ via Xcode schemes matching the Android flavors.

---

## 7. Guidelines for AI Agents Modifying Vyana

1. **Maintain Sovereignty**: Never add external HTTP calls for transmitting user vitals, notes, or prompts to third-party cloud servers. All analytics and LLM inference must execute locally.
2. **Preserve BLE State Safety**: Always release streams, cancel tickers (`_ecgSnapshotTicker`, `_connectionStateTimer`), and unregister foreground callbacks when controllers or screens are disposed.
3. **Respect Reconnect Backoff**: Always utilize `_resetReconnectBackoff()` for user-initiated actions and `_growReconnectBackoff()` for failed passive background scans to avoid battery drain.
4. **Coordinate UI Theming**: Use `context.vyana` / `VyanaColors` / `VyanaType` rather than hardcoded Material colors to preserve the custom warm ivory/emerald/dark mode design system.
