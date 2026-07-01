# iOS home-screen widget — Xcode setup

The Android widgets build automatically. iOS WidgetKit needs a **widget extension
target**, which must be added in Xcode once (it cannot be scripted safely). The
Swift source, `Info.plist`, and entitlements are already in this folder — you're
just wiring them into the Xcode project.

Everything else (Dart bridge, deep links, data push) is already done.

## 1. Add the App Group to the Runner app
1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the **Runner** target → **Signing & Capabilities**.
3. Click **+ Capability** → **App Groups**.
4. Add the group **`group.com.seeknirvana.vyana`** (checked).
   - This makes Xcode set `CODE_SIGN_ENTITLEMENTS` for Runner. You can point it at
     the provided `Runner/Runner.entitlements`, or let Xcode generate its own —
     just keep the group id identical.

## 2. Create the widget extension target
1. **File → New → Target… → Widget Extension**.
2. Product name: **`VyanaWidget`**. Uncheck "Include Configuration Intent".
   Finish, and **do not** activate the scheme when prompted (Cancel is fine).
3. Xcode creates a `VyanaWidget` group with a template `VyanaWidget.swift`,
   `Info.plist`, and an entitlements file. **Delete the template `.swift`** and
   **add the one in this folder** (`ios/VyanaWidget/VyanaWidget.swift`) to the
   new target instead (or replace the template's contents with it).
4. Set the extension's **Deployment Target** to iOS 14 or later (17+ recommended
   so `containerBackground` renders the card background).

## 3. Add the App Group to the widget target
1. Select the **VyanaWidget** target → **Signing & Capabilities**.
2. **+ Capability → App Groups**, add **`group.com.seeknirvana.vyana`**.
   - Or set its `CODE_SIGN_ENTITLEMENTS` to the provided
     `VyanaWidget/VyanaWidgetExtension.entitlements`.
3. Set the same **Team** (`VV2P8ZJ55M`) as Runner.

## 4. Flavors (googlePlay / dappStore schemes)
This project ships flavor schemes. In the widget target's **Build Settings**,
make sure `FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER` resolve (they inherit
from the Generated.xcconfig like Runner) so the Info.plist version keys fill in.
If a flavor scheme doesn't embed the extension, add **VyanaWidget** to that
scheme's Build targets and to Runner's **Embed App Extensions** phase.

## 5. Verify
1. `flutter run` (or a flavor scheme) on a device/simulator.
2. Long-press the home screen → **+** → search **Vyana**. Add both:
   - **State of being** (small/medium) — shows the latest felt readings.
   - **Monitor all vitals** (small) — tap launches the app and starts a run.
3. Do a Monitor-all-vitals run in the app; the state-of-being widget should
   refresh within a few seconds (the app calls `WidgetCenter.reloadTimelines`).

## How it's wired
- Dart writes state into `UserDefaults(suiteName: "group.com.seeknirvana.vyana")`
  via `HomeWidgetService.pushState` after every sync.
- The widgets read those keys (`state_title`, `state_line`, `state_tone`,
  `updated_label`, …) in `loadEntry()`.
- Tapping a widget opens `vyanawidget://monitor` (action) or `vyanawidget://open`
  (display). `home_widget`'s plugin surfaces the URL; `VyanaShell` starts
  `runAllVitals()` on the `monitor` host.
