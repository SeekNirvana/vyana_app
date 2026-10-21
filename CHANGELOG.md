# Changelog

## v1.1.4 — 2026-10-21 · The mark as drawn, the ring photo, a readable week

Brand and asset work from the Vyana 2.0 handover that the v1.1.3 pass
missed, plus a second look at the This week chart.

### Added

- **The ring photo on the ring screen (mock 16a).** The transparent
  cut-out `assets/ring_images/ring_inside.png` is in the repo at last, so
  the ring that floats between the status panel and the paired card
  renders instead of leaving the slot empty. The layout has been waiting
  for this file since v1.1.3.

### Fixed

- **The splash drew the icon's dark tile as a square.**
  `assets/splash_logo.png` was the opaque iOS export, so the pre-12 splash
  showed a `#0C211D` square against the `#071211` background rather than
  the mark alone. It is now the handover's transparent `vyana_logo.png`,
  which is what that file was exported for.
- **Brand sources come from the handover exports.** The Android 12 splash
  and the adaptive launcher foreground were derived from the opaque tile
  by `scripts/build-brand-assets.py`, which estimates the tile's
  background per row and feathers an alpha out of it. The handover ships
  both vector-derived at the sizes the tooling wants (1152px and 432px),
  so they are used directly. The launcher's opaque tile moves to its own
  `assets/app_icon.png`, leaving `assets/logo.png` as the transparent
  in-app mark the app actually draws.
- **This week's chart was too small to read (mock 6a).** The bars and the
  day letters shared one 40px box, which left about 19px of bar — a
  mid-week day came out a 9px nub — and the whole bar was clipped as a
  single shape, so a day holding two practices read as one block. The bar
  row now owns 30px, the letters sit under it at 9px, each practice is its
  own 2px-radius segment with a 1.5px gap and the largest at the bottom,
  and a day with nothing done is a 3px hairline.

## v1.1.3 — 2026-10-21 · Background alerts, honest ranges, targets

The 9 Oct handover reopened the backlog after v1.1.2: sixteen bugs found
on 6 Oct and six changes. This release works through all of them.

### Added

- **Optional target on count-up practices (§5).** A goal, not a length —
  the session still counts up and only you end it. 15 / 30 / 45 / 60 min,
  plus 1 / 3 / 5 / 10 km on GPS practices, Custom either way, remembered
  per practice and offered pre-set with a clear ×. Movement gets a spoken
  cue at halfway and on arrival; mindfulness and wellness get a soft bell
  only, since a voice is the thing they were avoiding. The summary reads
  "Target 30 min · reached", or "· 24 of 30 min" when it was not.
- **"On my own" (§5).** Guided / On my own above Start on the fifteen
  practices where the guidance is optional. No voice, pacer, orb or
  audio; the ring mode, its samples and the summary are unchanged, so
  the session still measures what the practice did. Remembered per
  practice. A suggestion from Home always opens Guided.
- **This week, and Your week / month (§5).** A card on Practice under
  Recent, and a screen behind it: Week · Month, period arrows that stop
  at the current period, SESSIONS · TIME · DAYS, stacked bars by day or
  calendar week with a segment per practice in its pin-slot hue, By
  practice rows opening that practice's history, Mindful and HRV cards,
  and a Patterns row. Replaces Weekly Insights (`29`).
- **The new Vyana mark** — a drop inside an open gold ring — on the
  launcher icon, the splash and the app icon, on both platforms.
- **End a session without saving (`28`).** A quiet Discard beside End &
  save, with a confirmation; anything under a minute asks before saving.
- **"Still asleep after 07:02?" (`14(d)`).** The one correction the app
  offers for a night the ring ended at a brief waking.

### Fixed

- **`21` Background alerts and reconnect still did not work** — bugs 6
  and 18 had regressed, for three separate reasons. The scheduled alerts
  use `zonedSchedule`, but the manifest declared neither receiver
  flutter_local_notifications needs, so they could never fire. The
  foreground service required a live connection, so the moment the ring
  dropped, the service whose job is to reconnect it was stopped. And the
  on-by-default from v1.1.2 could not reach anyone who already had a
  saved `false` — that is, every user who reported it.
- **`19` Overnight syncs cut the night short.** With the service on all
  night, a sleep-data request mid-night appears to make the ring close
  its open sleep record. Between your own bedtime and wake time the
  periodic sync no longer asks for sleep; the night is fetched on the
  first sync after you wake.
- **`22` Readiness and sleep reset at midnight.** Every daily value was
  keyed to the calendar date, so at 00:00 last night's sleep belonged to
  yesterday and the new day had no night: Sleep read "Not recorded" and
  readiness fell back to a handful of HRV samples on a fixed scale,
  where one high reading gave 100. The day now turns over at wake.
- **`23` Values that were "too good" were flagged red.** 9h 30m of
  sleep, an HRV above 90, SpO₂ 99% and an athlete's resting 48 all read
  rose with "OUTSIDE". Each range now carries the direction that is
  actually a problem, and the caption says ABOVE or BELOW. Resting HR
  under 40 bpm is amber and explained, never silently personalised.
- **`24` Stress had a "Take a new reading" button** that asked the ring
  for a measurement the page never showed. Removed, and replaced with
  one line saying where the number comes from.
- **`25` A spot reading still looked like a failure** on HRV and heart
  rate, whose hero is the day's value. The hero is now captioned
  "Overnight" or "Resting", with the reading just taken on its own line.
  A measurement that captured nothing says so instead of "Saved".
- **`26` There was no manual sync** outside the stale banner. Sync now
  sits on the ring screen and at the top of You → Ring. The ring screen
  also gains the 2 × 2 info grid, rename beside the name, and "PRANA
  rings near me"; Manage ring opens it directly.
- **`27` Gym's "How it works"** described only the sets mode, although
  Start and end is the default. The steps follow the switch.
- **`29` Weekly Insights was mostly fake data** — a fixed sentence about
  Zone-2 runs, an HRV trend that was always 48→58 ms, 40 calm minutes
  every week — shown to real users as their own. `WeeklySeed` and
  `HomeSeed` are deleted, so nothing can fall back to them again.
- **`30` Practice said "Suggested today"** even after the intent was
  confirmed, which read as "your status is only a suggestion".
- **`31` The ring screen showed "RSSI 0" while connected.** A connected
  ring advertises nothing, so 0 meant "no reading", not a full signal.
- **`32` A 40-second session showed as "0m"**, and one that crossed
  midnight landed on the previous day in Done today.
- **`33` Downhill Skiing and Snowboarding promised "runs"** nothing can
  count. Copy only; tracking is unchanged.
- **`5` The splash mark was cropped on Android 12+**, and would have
  been again with the new art: the mark fills 66% of its tile and the
  mask is a circle two-thirds of the canvas. `scripts/build-brand-assets.py`
  cuts the mark out and re-centres it inside the central 62%, for the
  splash and for the adaptive launcher foreground.

### Changed

- **Perform is orange** `#F5923A` (soft `#F9B97E`), was `#E3A448` /
  `#F2C676`. Gold is reserved for brand moments and ring sync states.

### Known limitations

- **`20` Sleep starts when the ring sees you settle, not when you fall
  asleep.** Checked against the 25 nights of real cached history: every
  one opens with a *light sleep* stage and not one opens awake, so this
  ring does not separate time in bed from time asleep, and inferring an
  onset from heart rate would be inventing a number. The Sleep detail
  says so. The code handles the other case if a future ring labels it.
- **Scanning while a ring is paired stays blocked** until someone
  confirms on hardware that it does not disturb the connection or a
  sync; the SDK may only handle one ring at a time.
  `kScanWhilePairedVerified` is the only switch.
- **The ring photo on the ring screen** needs
  `assets/ring_images/ring_inside.png` (a transparent cut-out). The
  layout is in place and renders nothing until that file is added.
- **Live RSSI** is still the scan-time value: the pinned SDK (v0.2.7)
  exposes no read on a connected device, so an unknown signal shows "—".

## v1.1.2 — 2026-10-03 · Honest numbers, personal normals, cycle tracking

The updated 2.0 handover (28 Sep) replaced its spec with a backlog of 14 open
bugs, 5 screen changes and 2 new features. This release works through all of
them.

### Added

- **Personal baselines (§14).** Every verdict used to be a fixed population
  rule, so a 5h 40m sleeper or a naturally low-HRV body read as permanently
  short-slept or stressed however they felt. For the first 14 days the base is
  a typical adult (`−17 vs typical 55`) behind a "Learning your normal ·
  DAY n OF 14" strip; after that it is the user's own 30-day average
  (`+2 vs base 36`). When a vital sits outside its typical range on ≥10 of the
  last 14 days *and* holds steady, Nova asks once — about the feeling, never
  the number — and only an answer that says "this is fine" adopts the personal
  range. "Mostly rested" also moves the sleep score's duration target to the
  user's own 14-night median (floored at 6 h). Answers are editable in
  You → Your normal. SpO₂ below 92%, an irregular rhythm and a heart rate more
  than 20 bpm over band are never personalised.
- **Cycle tracking (§14b).** Opt-in, on-device, offered once after the profile
  is saved with a female gender; the Cycle row and section exist only while
  that holds, and switching away keeps the logged days. One tap marks day 1;
  period length is recorded rather than assumed ("Period ended"), with a
  single "Did your period end on 12 Sep?" prompt two days after the expected
  end so it never interrupts a longer period. A swipeable month calendar makes
  correcting any day one tap, and states the count behind every average.
  Pregnancy mode shows week, trimester and a 40-week bar, and pauses the
  personal base. Once two cycles exist, resting HR, HRV, temperature and
  stress compare against the same *phase*. New cycle mauve `#C58BB0`, used
  only on cycle marks.
- **Named sports.** Downhill Skiing, Cross-country Skiing, Snowboarding, Ice
  Skating, Ice Hockey, Padel, Squash, Table Tennis, Volleyball, Hockey,
  Boxing / Martial Arts, Surfing and Kayaking / SUP, plus **Sauna & Cold
  Plunge** and **Sauna & Swim** as single sessions with no taps between
  rounds. Mapped to the SDK's real modes where they exist (table tennis,
  volleyball, kayak, skating) rather than defaulting everything to free mode.
- **Add your own sport**, with one question — "Where do you do it?" — a glyph
  picker, its own history and pinning. **Catalogue search** across all three
  categories, falling back to "Add '{query}' as your own sport".
- **Done today** on Home: today's finished sessions under the suggested card,
  each opening its saved summary. The suggestion's play button becomes a grey
  tick once it has been done.
- **Gym, two modes** (replacing "Strength Training", same id so history
  carries over): "Start and end" by default, or "Track sets & rest".
- **Past sessions are openable** — from the Practice header, the new Recent
  row, a pin's history, or any history row — rendered from stored data rather
  than memory, with **The morning after** (next-morning HRV and that night's
  sleep against base) and Delete session.

### Fixed

- **`11` Resting HR was the latest live heart rate** — 137 bpm after a run,
  judged against the resting band and feeding both readiness and the health
  alert. It is now one value per day: the lowest sustained five-minute average
  inside last night's sleep window, or the lowest daytime average excluding
  every session and the 30 minutes after it.
- **`16` Home's HRV was the latest spot reading** on fixed cut-offs, so the
  arrow and the verdict could disagree. Home and readiness now use overnight
  HRV, and the verdict comes from the same base as the arrow.
- **`7` Stress was judged on a fixed HRV scale** identical for everyone. It is
  now deviation from the user's own HRV range, falling back to the population
  scale until a baseline exists.
- **`14` Missing and partial nights were treated as real sleep.** Only a night
  whose sleep day is today counts; otherwise the Sleep card reads "Not
  recorded" and readiness falls back to HRV with the score line saying so. A
  night counts as incomplete only when both things are true — too little sleep
  was recorded *and* the ring reported nothing afterwards, which is what a
  flat battery or a removed ring looks like — and is then excluded from
  averages, bases and the §14 questions. (A first cut of this rule also
  demanded a trailing `awake` stage; the ring emits one on barely a fifth of
  nights, so 21 of 25 real nights were being written off. Caught on device.)
- **`17` Morning sync showed old values with no sign new data was coming.**
  Mid-sync the Sleep card says "Getting last night…", a sync that returns
  without today's night retries at 3, 10 and 30 minutes, and the event log
  records whether the ring produced one.
- **`12` The chosen length never reached the session**, so a suggested
  3-minute breathwork counted up forever. Timed practices now count down with
  a ring on the orb, end on a soft bell and haptic, and offer Finish or Keep
  going — with a notification scheduled at start, for a locked phone. Movement
  gets no preset length, and untimed rows stop advertising "35 min".
- **`13` Outdoor sessions stopped in a pocket and were then lost.** GPS runs
  under a location foreground service with background permission; fixes over
  20 m accuracy are dropped; elevation is a moving median counting only climbs
  over 3 m; session steps are recorded; the clock is wall-time so suspension
  costs nothing; and a session the system killed is offered back on Home as
  Resume / End it, closed at the last captured moment.
- **`18` The ring didn't reconnect in the background.** The foreground service
  is on by default whenever a ring is paired and restarts after a reboot;
  reconnect tries a direct connect by address before paying for a scan; and
  the backoff resets when Bluetooth returns or the app is opened. If Android's
  battery settings killed Vyana and cost data, Home says so once, with Allow
  or Not now.
- **`6` Alerts only fired while the app was open.** Alerts are evaluated on
  every background heartbeat, and the two elapsed-time alerts — 24-hour stale
  ring, two hours out of reach — are now handed to the OS so they arrive with
  the app dead, on both platforms.
- **`15` "Take a new reading" looked like it did nothing.** The screen updates
  live, and the result stays on the button: "New reading · 36.4 °C · 09:31",
  or "Couldn't get a clean reading" — which used to look identical to success.
- **`8` Journal entries couldn't be edited**, so a mistranscription was
  permanent unless deleted and re-dictated, losing the timestamp the pattern
  engine joins on. Entries and meals are now editable, patterns recompute, and
  Nova's reflection can be re-asked rather than silently left stale.
- **`10` Finished sessions couldn't be found again**, and "Readiness impact
  +3 expected" was a formula over duration and category presented as a
  finding. The invented number is gone; sessions are findable and openable.
- **`9` Chakra points were still shown** after rewards were removed — the
  session summary, the wallet row and the hard-coded balance.
- **`5` The splash mark was cropped on Android 12+**, where the icon is masked
  to a circle two-thirds of the canvas.
- **Forgotten sessions**: a session nobody ended now says so — after heart
  rate has been near resting for 20 minutes, or twice the expected length for
  a still practice — offering "End at 12:40", back-dated so the forgotten
  stretch isn't counted.
- **Pattern evidence** now shows the non-matching dreams of the window and a
  per-row delta against a stated baseline, instead of leaving the percentage
  to be derived.
- **Intent pre-set** no longer sticks on Recover when ring data arrives after
  the first build.

- **Readiness is computed in one place.** Home's score and the Metrics chart
  reached it differently — the chart averaged every HRV reading in the day,
  including daytime spot measurements, while Home used the overnight window —
  so the big number and today's point on the chart could disagree. The chart
  also counted truncated nights, which dragged down the very average Home
  compares against. Both now share one function and skip incomplete nights.
  Readiness remains deliberately about today: last night's sleep score at 65%
  and that night's HRV at 35%, not accumulated sleep debt.

### Changed

- Practice screens drop the meta chips, the "What Vyana tracks" chips and the
  coaching panel — they described the app, not the practice. "How it works"
  collapses once a practice has been done, and the icon takes its pin-slot hue
  rather than a per-activity accent, which broke the colour rule.
- Treadmill Run → **Treadmill Walk / Run** (id unchanged).
- Database schema 8 → 10: `CycleDays`, `UserActivities`, and pattern
  counter-evidence plus baseline.

### Known gaps

- Bug 6's fourth item — a WorkManager / BGAppRefreshTask periodic task — is
  **not** implemented. The two alerts it was meant to drive are now OS-
  scheduled instead, which delivers them with the app dead and needs no
  background isolate (one would have no Bluetooth connection to inspect in any
  case). Low battery still needs a live reading, so it fires only while the
  app or the service is running.
- §15's open questions are unchanged: typical-adult base values still use each
  range's midpoint for want of an age/sex norm source, and rounds inside the
  sauna combos are not inferred from the HR trace.

## v1.1.1 — 2026-09-20 · Ring state you can act on

### Fixed

- **Home ring pill on a phone the ring has never synced to** showed a cached
  battery % with no way to sync. A paired ring with no sync on this phone is
  now *stale*: the pill reads **SYNC** and the "Today is missing" banner
  offers Sync now. Once a reconnect attempt has actually failed since launch
  the ring is *disconnected*: the pill reads **CONNECT** and the banner offers
  Reconnect — no more battery number for a ring the phone hasn't spoken to.
- **SYNC with a dropped link** used to say "Updating your health data…" and
  then do nothing. It now reaches for the ring first, syncs on success, and
  says "Ring not in reach" with a Retry when it can't.
- **Ring alerts never fired across launches.** The two-hour offline clock and
  the low-battery episode lived in memory and reset every restart; both are
  now persisted (`vyana.ring.alert.*`), so "Nothing is reading you right now"
  fires after two hours out of reach regardless of relaunches and the
  ≤15 % battery alert repeats at most every 12 h. The "not synced since …"
  push no longer fires for a ring that has never synced here (the pill and
  banner cover that).
- **Intent pre-set stuck on Recover** even with a high readiness score. The
  first pre-set ran before the ring cache hydrated (no score → Recover) and the
  "recompute when data lands" hook compared the controller to itself. An
  unconfirmed pre-set is now re-derived whenever the readiness score changes;
  a confirmed choice is never overwritten.
- **Metric card verdicts** ("Recovered", "Balanced") wrapped to two lines on
  narrower phones; they now scale to a single line at normal text size and
  wrap only when the system text scale is above 1.25×.

### Docs

- README refreshed for the 2.0 layout (five tabs, Nova, Metrics, patterns).

## v1.1.0 — 2026-09-19 · Vyana 2.0 (Home · Metrics · Practice · Journal · You)

### Changed

- **Five tabs**: Home · Metrics · Practice · Journal · You. The Guides tab is
  gone; **Nova is a pill above the nav on every screen** (Ask Nova / Install
  private AI guide · 1.1 GB / Installing … %), opening her chat as a pushed
  screen.
- **Home** is one read: ring-status eyebrow + battery pill, a 104px readiness
  arc with the state word, one sentence that follows the chosen intent, three
  fixed metric cards (HRV · Sleep · Resting HR), the **intent row** (Recover /
  Perform / Settle, pre-set from your weekday history) and one suggested
  practice. Stale / offline rings get an inline Sync now / Reconnect banner.
- **Metrics** (new tab, replaces "Health metrics") owns the time axis: 7D /
  30D / 90D readiness chart with your average, Movement · TODAY with window
  averages, every vital against its reference window *and* your own baseline
  (`+11 vs base 54` · `TYPICAL 21–90 MS`), peak badges, an ECG section, and a
  quiet "Export reports → IN YOU" line.
- **Practice**: intent chip + readiness eyebrow, the same suggested practice,
  a horizontal rail of **pinned practices** (colour per pin slot, Edit mode,
  `SUN 32M · 129BPM` metadata), and the catalogue with Movement first.
- **Journal** is one day-grouped timeline of entries and meals; wake capture
  leads with a filled mic; tags are tappable filters; a search sheet combines
  text, tags and a date scope; Nova's reflections are stored and shown inset.
- **You**: ring group trimmed to device management (routine vs destructive),
  Sync row folds interval + Android background service, Notifications row
  (Ring & data / Health alerts on, Nudges off), Nova footprint row, "How often
  do you train?" → personal resting-HR band, and a Your data export group.

### Added

- `Patterns` table + engine: Nova joins journal tags to sleep nights and
  sessions to next-day HRV, persists findings with a holding → weakening →
  ended lifecycle, shows one card per surface, the evidence on tap, and the
  full history on Weekly Insights.
- Reference ranges for sleep (7–9 h) and resting HR (band by training
  frequency, clinical 60–100 when unanswered) in `vitals_quality.dart`.
- **Lucid Dreaming** (Mindfulness, 14 min) — finishing it arms the next
  morning's wake capture ("Did you catch it?").
- Push alerts for ring offline / stale 24h / low battery (once at 15%) and
  health alerts; retest control on vital reports gated on the ring's own
  start-measurement flag.
- Health report (CSV), journal (JSON) and full archive exports.

- **Nova is the only guide** — one model, one persona covering sleep, dreams,
  breath, movement and nutrition; the store installs Nova alone. Model size is
  stated once (`kGuideModelSizeLabel`, 3.1 GB) everywhere.
- **Practice pins** reorder by press-and-hold in Edit mode; suggested practices
  are always four minutes or less and open the activity screen at that length.
- **Exports** are grouped with sub-options: Health (summary per day, every
  vital reading, sleep nights, ECG) and Journal (all, dreams, reflections,
  ideas, meals), each for a 7D / 30D / 90D / ALL period; Metrics and Journal
  deep-link to their own section.
- **Type floors**: no caption below 12sp, mono eyebrows ≥ 11.5, list rows
  ≥ 48dp; at large text sizes the nav, Home metric cards, intent chips and
  Practice status wrap or stack instead of clipping.
- Splash shows the mark on the app background (no tile); the logo tile is a
  solid dark square. The ring store shows two square product shots.
- Readiness middle band is amber, not grey; state words are Ready · Balanced ·
  Depleted. The pre-set intent chip is dashed until confirmed.
- About and Privacy screens re-checked against the code: removed claims for
  features that do not exist (weather push, notification forwarding, OTA),
  listed the real outbound connections, and marked cloud sync as not yet live.

### Fixed

- The three Home signals no longer change identity day to day (fixed slots).
- Sleep no longer renders HRV's "Well recovered" string.
- Home's fixed-height hero replaced with gap-based flex so long strings wrap
  instead of overlapping.
- ECG Record is gated on `isSupportRealTimeECG` / `isSupportECGDiagnosis`.
- Ring onboarding no longer crashes when Home's "Pair now" panel is removed by
  the connection it started (navigator captured before the context dies).
- Journal tab rendered blank (unbounded `stretch` Row inside a ListView).
- Peak badges (`30-DAY HIGH`) require five prior days, not three readings.
- The Nova pill is opaque and clear of the nav; it no longer covers the last
  card at the end of a scroll.

## v1.0.5 — 2026-08-20

### Added

- **Ring onboarding** after first pair — a four-step wizard to name the ring,
  turn on vitals monitoring, optionally wipe previous on-ring health data
  (skippable for a new ring), and enable the always-on Android foreground
  service that keeps BLE alive in the background.
- **Ring sync interval** on the You tab — configurable app-side history fetch
  (5–60 minutes, default 20) independent of the ring's own monitoring cadence.
- **Explicit health monitoring** — ring-side periodic checks are no longer
  auto-applied; you set them during onboarding or later from You.
- **Background sync heartbeat** — Android foreground service isolate ticks the
  main isolate so history is pulled while the app is backgrounded.
- **Reconnect backoff** — passive BLE retries grow exponentially when the ring
  is out of range; user-driven reconnects still retry immediately.
- Home header shows live ring status: connected, syncing, or offline and
  reconnecting.
- **ECG results & local history** — every 60-second recording (the full
  ~15k-sample waveform + metrics) is now saved on-device and browsable from a new
  ECG screen, ready for future A-Fib/V-Fib analysis. Post-ECG detail is richer: a
  clear atrial-fibrillation banner, a plain-language QRS explanation, and extra
  HRV-derived indices (stress, body load, vitality, autonomic balance, breathing)
  shown in a tidy grid.

### Changed

- You-tab settings: health monitoring, sync interval, and foreground-service
  rows with current values; data wipe during onboarding is optional.
- UI polish — icon badges, card gradients, icon colors, onboarding, and
  settings consistency; refreshed homescreen type and ring status indicator.

### Fixed

- **ECG "Result" showed nothing** — undiagnosed or noisy readings (including a
  valid heart rate and the AF flag) were discarded; results now always surface
  and persist.
- **Stress history** — the Stress metric plotted only the latest value; it now
  shows a full trend derived from HRV history, like every other vital.

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