# iOS background sync, reconnect and alerts

Bug 47. Every background feature in Vyana — overnight sync, auto-reconnect,
ring alerts, the evening battery check, plan reminders — used to run through
the Android foreground service (`lib/src/services/ring_foreground_service.dart`),
which no-ops on iOS. With the app closed on an iPhone, nothing happened until
it was opened again, and the App Store listing described the same app.

## What ships in this repo

1. **`bluetooth-central` in `UIBackgroundModes`** (`ios/Runner/Info.plist`).
   Without it iOS tears the ring's BLE connection down the moment Vyana is
   backgrounded, so there is nothing to reconnect to, let alone sync.

2. **The time-based alerts are handed to the OS in advance**, because iOS
   gives no background timer to evaluate them with. Each is cancelled as soon
   as it stops being true:

   | Alert | Scheduled | Cancelled |
   | --- | --- | --- |
   | Not synced for 24 h | on every successful sync | on the next sync |
   | Out of reach for 2 h | on every confirmed connection | on the next connection |
   | Evening battery (< `kOvernightBatteryMin`) | whenever the ring reports a low battery | when it is charged past `kBatteryRecoveredPercent` |
   | Plan reminder (item 46) | when a planned day is set up | when the practice is done, or the plan changes |

   On Android these are evaluated live in the service isolate instead
   (bug 44), so nothing is scheduled twice.

## What is still needed, in the ring SDK

**Core Bluetooth state restoration.** `bluetooth-central` alone keeps an
already-live connection alive; it does not bring Vyana back after iOS has
suspended or terminated it. For that, the central manager must be created
with a restore identifier and the app must adopt the restoration callback:

```swift
// In the SDK's iOS plugin, where the CBCentralManager is created:
CBCentralManager(
  delegate: self,
  queue: nil,
  options: [CBCentralManagerOptionRestoreIdentifierKey: "com.seeknirvana.vyana.central"]
)
```

```swift
// AppDelegate:
func application(
  _ application: UIApplication,
  willRestoreState dict: [String: Any]
) { /* hand the restored peripherals back to the SDK */ }
```

The central manager belongs to `YCProductSDK`, vendored through the
`vyana_sdk` git dependency (`pubspec.yaml`), so this cannot be added from the
app. It needs either SDK support for a restore identifier or a change in the
`vyana_sdk` repository.

**Until it ships:** keep "syncs in the background" claims out of the iOS App
Store listing. On iPhone, Vyana syncs while it is running or recently
backgrounded; it is not relaunched by the ring.
