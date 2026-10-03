part of '../../main.dart';

/// Drives one live activity session: starts/pauses/stops the ring sport mode,
/// samples live physiology into the vault every second, and captures raw ring
/// frames. Because the ring may not persist app-started sport, the session's
/// samples/route/raw frames are the source of truth — stored locally.
class SessionController extends ChangeNotifier {
  SessionController(this._ref);

  final Ref _ref;

  Activity? _activity;
  String? _sessionId;
  DateTime? _startedAt;
  bool _active = false;
  bool _paused = false;
  Duration _elapsed = Duration.zero;

  /// The chosen length for a timed practice, in minutes; null for open-ended
  /// sessions. Bug 12: this used to be dropped on the floor at start().
  int? _plannedMinutes;
  bool _bellRung = false;
  bool _overrun = false;

  /// Bug 13(e): the clock used to be a pure Dart counter, so it stopped dead
  /// whenever the OS suspended the app and a walk silently lost minutes.
  /// Elapsed is now wall-clock since [_startedAt], minus time spent paused.
  Duration _pausedTotal = Duration.zero;
  DateTime? _pausedAt;

  /// §5 (mock 12d): Gym's mode. False — "Start and end", nothing to tap —
  /// is the default; true uses the set/rest timer. Remembered per user.
  bool _tracksSets = false;

  /// §5 "Forgotten session". A session nobody ended is the common failure of
  /// start/end tracking: the app cannot tell you later that it is still
  /// recording, so it has to notice while it still can.
  DateTime? _hrSettledAt;
  bool _forgottenFired = false;
  DateTime? _forgottenSnoozedUntil;
  int _sampleCount = 0;
  int? _heartRate;
  final List<int> _hrSeries = [];
  Map<String, dynamic>? _lastSummary;
  Timer? _ticker;
  bool _disposed = false;

  // Voice cues
  String? _activeCue;
  Timer? _cueClearTimer;

  // GPS (outdoor sessions)
  StreamSubscription<Position>? _posSub;
  final List<({double lat, double lng})> _route = [];
  double _distanceMeters = 0;
  double _elevationGain = 0;
  double? _currentSpeed;
  double? _lastAltitude;
  ({double lat, double lng})? _lastPoint;
  bool _gpsDenied = false;
  GpsState _gpsState = GpsState.notUsed;
  ElevationTracker? _elevation;
  int? _startSteps;
  int? _sessionSteps;
  int _lastKmAnnounced = 0;
  // Terrain cues (steep climb / descent care) — grade sampled over ~80 m.
  double? _gradeRefDist;
  double? _gradeRefAlt;
  Duration _lastTerrainCue = const Duration(minutes: -10);

  bool get active => _active;
  bool get paused => _paused;
  Activity? get activity => _activity;
  String? get sessionId => _sessionId;
  DateTime? get startedAt => _startedAt;
  Duration get elapsed => _elapsed;

  /// Movement: fires once heart rate has been back near resting for 20
  /// minutes while a session runs. Still practices, where HR cannot tell us
  /// anything, fire at twice the expected length instead.
  static const Duration kForgottenHrWindow = Duration(minutes: 20);

  /// How far above the resting band still counts as "settled".
  static const int kSettledHrMargin = 10;

  void _checkForgottenSession() {
    if (_forgottenFired || !_active || _paused) return;
    final activity = _activity;
    if (activity == null) return;

    final isMovement = activity.kind == 'gps' ||
        activity.kind == 'indoor' ||
        activity.kind == 'strength';
    if (isMovement) {
      final hr = _heartRate;
      // The day's resting HR where we have it, else the bottom of the
      // clinical band — never the live reading, which is the thing we are
      // comparing against.
      final resting = HomeDashboard.from(_ring).restingHr ??
          restingHrBand(null).low.round();
      if (hr == null) return;
      if (hr <= resting + kSettledHrMargin) {
        _hrSettledAt ??= DateTime.now();
        if (DateTime.now().difference(_hrSettledAt!) >= kForgottenHrWindow) {
          _fireForgotten(activity);
        }
      } else {
        // Back to work: the clock restarts.
        _hrSettledAt = null;
      }
      return;
    }
    // A still practice: twice the expected length is the only honest signal.
    final limit = Duration(minutes: activity.dur * 2);
    if (_elapsed >= limit) _fireForgotten(activity);
  }

  void _fireForgotten(Activity activity) {
    _forgottenFired = true;
    final settled = _hrSettledAt;
    final minutesAgo =
        settled == null ? null : DateTime.now().difference(settled).inMinutes;
    unawaited(
      VitalsNotificationService.instance.showForgottenSession(
        activityName: activity.name,
        settledMinutesAgo: minutesAgo,
      ),
    );
    _notify();
  }

  /// Wall-clock elapsed: survives the app being suspended mid-session.
  Duration _wallClockElapsed() {
    final started = _startedAt;
    if (started == null) return _elapsed;
    final paused = _pausedAt == null
        ? _pausedTotal
        : _pausedTotal + DateTime.now().difference(_pausedAt!);
    final total = DateTime.now().difference(started) - paused;
    return total.isNegative ? Duration.zero : total;
  }

  /// The length the user chose for a timed practice, or null when the session
  /// is open-ended (all movement).
  int? get plannedMinutes => _plannedMinutes;

  Duration? get plannedDuration =>
      _plannedMinutes == null ? null : Duration(minutes: _plannedMinutes!);

  bool get isTimed => _plannedMinutes != null;

  /// Whether this session logs individual sets and rests.
  bool get tracksSets => _tracksSets;

  /// When heart rate settled back near resting, for the "End at 12:40" action
  /// that back-dates the session instead of inflating it with forgotten time.
  DateTime? get hrSettledAt => _hrSettledAt;

  /// True while the forgotten-session prompt should be shown in-app.
  bool get looksForgotten =>
      _forgottenFired &&
      (_forgottenSnoozedUntil == null ||
          DateTime.now().isAfter(_forgottenSnoozedUntil!));

  /// "Still going" — snoozes the prompt for 20 minutes.
  void snoozeForgotten() {
    _forgottenSnoozedUntil = DateTime.now().add(const Duration(minutes: 20));
    _notify();
  }

  /// Ends the session back-dated to when heart rate settled, so the forgotten
  /// stretch is not counted as practice.
  Future<void> endAtSettled() async {
    final settled = _hrSettledAt;
    if (settled == null) {
      await end();
      return;
    }
    _backdateEndTo = settled;
    await end();
  }

  DateTime? _backdateEndTo;

  /// Time left on a timed practice, floored at zero.
  Duration? get remaining {
    final planned = plannedDuration;
    if (planned == null) return null;
    final left = planned - _elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// 0.0 → 1.0 across a timed practice, for the ring on the breath orb.
  double? get timedProgress {
    final planned = plannedDuration;
    if (planned == null || planned.inSeconds == 0) return null;
    return (_elapsed.inSeconds / planned.inSeconds).clamp(0.0, 1.0);
  }

  /// True once a timed practice has reached its length and not been extended.
  /// The live screen shows "Time's up" with Finish and Keep going.
  bool get timeUp => _bellRung && !_overrun;

  /// The user chose to carry on past the chosen length: the session reverts
  /// to counting up and stops nagging.
  void keepGoing() {
    if (!_bellRung) return;
    _overrun = true;
    _notify();
  }
  int get sampleCount => _sampleCount;
  int? get heartRate => _heartRate;
  List<int> get hrSeries => List.unmodifiable(_hrSeries);
  Map<String, dynamic>? get lastSummary => _lastSummary;

  List<({double lat, double lng})> get route => List.unmodifiable(_route);
  double get distanceMeters => _distanceMeters;
  double get elevationGain => _elevationGain;

  /// Current speed in m/s, or null if unknown.
  double? get currentSpeed => _currentSpeed;

  /// True when the user declined location for a GPS session — the live screen
  /// shows how to enable it.
  bool get gpsPermissionDenied => _gpsDenied;

  /// What the live screen says about the GPS (bug 13(b)): zeros used to be
  /// indistinguishable from a session that was not recording.
  GpsState get gpsState => _gpsState;

  /// Distance is held back until the first trustworthy fix, so it reads "—"
  /// rather than a confident 0.00 km.
  bool get hasGpsFix => _gpsState == GpsState.ready;

  /// Steps taken during this session, from the ring's cumulative daily count
  /// (bug 13(d)): end − start, never the whole day's total.
  int? get sessionSteps => _sessionSteps;

  /// The voice cue currently showing in the banner (auto-clears).
  String? get activeCue => _activeCue;

  RingController get _ring => _ref.read(ringControllerProvider);
  VyanaDatabase get _db => _ref.read(databaseProvider);

  /// Starts a session for [activity]. Returns null on success, or a reason if
  /// it could not start (scheduler conflict). Capture works even if the ring is
  /// offline — it just records no physiology.
  /// Starts [activity]. [minutes] is the length the user chose (from a
  /// suggestion or the "How long?" picker). For timed practices it is a
  /// promise: the session counts down from it and ends on a bell (bug 12).
  /// Movement ignores it and counts up.
  Future<String?> start(
    Activity activity, {
    int? minutes,
    bool tracksSets = false,
  }) async {
    if (_active) return 'A session is already running.';
    final ring = _ring;
    if (ring.isMeasuring) {
      return 'Finish the current measurement before starting a session.';
    }

    final id = 's${DateTime.now().microsecondsSinceEpoch}';
    final sportType = sportTypeCodeForRing(activity.ring);
    final now = DateTime.now();

    await _db.startSession(
      id: id,
      category: activity.cat,
      vyanaActivityType: activity.id,
      ringSportType: sportType,
      startedAt: now,
      phoneLocationEnabled: activity.gps,
      guidanceTemplateId: activity.guidance,
    );

    _activity = activity;
    _tracksSets = tracksSets;
    _plannedMinutes = activity.isTimed ? minutes : null;
    _bellRung = false;
    _overrun = false;
    _sessionId = id;
    _startedAt = now;
    _active = true;
    _paused = false;
    _elapsed = Duration.zero;
    _pausedTotal = Duration.zero;
    _pausedAt = null;
    _sampleCount = 0;
    _heartRate = null;
    _hrSeries.clear();
    _lastSummary = null;
    _route.clear();
    _distanceMeters = 0;
    _elevationGain = 0;
    _currentSpeed = null;
    _lastAltitude = null;
    _lastPoint = null;
    _gpsDenied = false;
    _gpsState = activity.gps ? GpsState.searching : GpsState.notUsed;
    _elevation = activity.gps ? ElevationTracker() : null;
    _startSteps = ring.vitals.steps;
    _sessionSteps = null;
    _lastKmAnnounced = 0;
    _gradeRefDist = null;
    _gradeRefAlt = null;
    _lastTerrainCue = const Duration(minutes: -10);

    // Take ownership of the ring (serializes one-shot measurements) and start
    // capturing raw frames.
    ring.setSessionActive(true);
    ring.sessionEventSink = _onRawEvent;

    // Start the clock + capture immediately; the ring/GPS commands run in the
    // background so a busy BLE queue can't block the UI from opening the
    // session. Sample capture works regardless (it reads live vitals).
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _notify();

    if (ring.isConnected) {
      unawaited(ring.repo.startSport(sportType));
      unawaited(ring.repo.setRealtimeData(true));
    }
    if (activity.gps) {
      unawaited(_startLocation(id));
    }
    // Breathwork is normally done with the phone face down, so the end cue
    // has to survive a locked screen: schedule it now rather than relying on
    // the app being foregrounded when the timer expires.
    final planned = _plannedMinutes;
    if (planned != null && planned > 0) {
      unawaited(
        VitalsNotificationService.instance.schedulePracticeEnd(
          at: now.add(Duration(minutes: planned)),
          activityName: activity.name,
        ),
      );
    }

    return null;
  }

  Future<void> _startLocation(String sessionId) async {
    final service = _ref.read(locationServiceProvider);
    final ok = await service.ensurePermission();
    if (_disposed || !_active) return;
    if (!ok) {
      _gpsDenied = true;
      _gpsState = GpsState.denied;
      _notify();
      return;
    }
    // Bug 13(a): without "Allow all the time" Android cuts the stream when
    // the screen locks. Asked here, in context, rather than up front.
    unawaited(service.requestBackgroundPermission());
    _posSub = service
        .positions(
          notificationText: 'Recording your ${_activity?.name ?? 'session'}',
        )
        .listen((pos) {
      if (!_active || _paused || _disposed) return;
      // Bug 13(c): drop fixes we cannot trust rather than letting them
      // inflate distance and elevation.
      if (pos.accuracy > kGpsAccuracyCeilingMeters) {
        if (_gpsState == GpsState.searching) _notify();
        return;
      }
      if (_gpsState != GpsState.ready) {
        _gpsState = GpsState.ready;
      }
      final point = (lat: pos.latitude, lng: pos.longitude);
      final last = _lastPoint;
      if (last != null) {
        _distanceMeters += Geolocator.distanceBetween(
            last.lat, last.lng, point.lat, point.lng);
      }
      // Smoothed, with a minimum climb — raw altitude jitter is not hills.
      _elevation?.add(pos.altitude);
      _elevationGain = _elevation?.gainMeters ?? _elevationGain;
      _lastAltitude = pos.altitude;
      _lastPoint = point;
      _currentSpeed = pos.speed >= 0 ? pos.speed : null;
      _route.add(point);
      if (_route.length > 3000) _route.removeAt(0);
      // Announce each completed kilometre with the average pace so far.
      final km = _distanceMeters ~/ 1000;
      if (km > _lastKmAnnounced) {
        _lastKmAnnounced = km;
        final pace = _spokenPace();
        emitCue(
          'Kilometre $km.${pace == null ? '' : ' Average pace $pace per kilometre.'}',
        );
      }
      _maybeEmitTerrainCue(pos.altitude);
      unawaited(_db.addRoutePoint(
        sessionId: sessionId,
        timestamp: DateTime.now(),
        lat: point.lat,
        lng: point.lng,
        altitude: pos.altitude,
        speed: pos.speed,
      ));
      _notify();
    });
  }

  void _tick() {
    if (!_active || _paused || _disposed) return;
    _elapsed = _wallClockElapsed();

    // Bug 12 (2): a timed practice ends on a soft bell and a haptic, once.
    final planned = plannedDuration;
    if (planned != null && !_bellRung && _elapsed >= planned) {
      _bellRung = true;
      // The breath pacer finishes its current exhale before the bell, so the
      // cue never cuts a breath in half.
      unawaited(_ringEndBell());
    }
    final v = _ring.vitals;
    // Bug 13(d): the Walk catalogue promises "Steps & distance", but only the
    // ring's cumulative daily total was ever stored. The session's own count
    // is end − start.
    final steps = v.steps;
    if (steps != null) {
      _startSteps ??= steps;
      final delta = steps - _startSteps!;
      if (delta >= 0) _sessionSteps = delta;
    }
    if (v.heartRate != null) {
      _heartRate = v.heartRate;
      _hrSeries.add(v.heartRate!);
      if (_hrSeries.length > 240) _hrSeries.removeAt(0);
    }
    _sampleCount++;

    // Spoken split every 10 minutes for movement sessions — time, pace,
    // heart rate, and elevation, as the practice catalog promises.
    final kind = _activity?.kind;
    if ((kind == 'gps' || kind == 'indoor' || kind == 'strength') &&
        _elapsed.inSeconds > 0 &&
        _elapsed.inSeconds % 600 == 0) {
      _emitSplitCue();
    }

    _checkForgottenSession();

    final id = _sessionId;
    if (id != null) {
      unawaited(_db.addSample(
        sessionId: id,
        timestamp: DateTime.now(),
        heartRate: v.heartRate,
        spo2: v.bloodOxygen,
        hrv: v.hrv,
        temperature: v.temperature,
        steps: v.steps,
        ringDistance: v.distanceMeters,
        ringCalories: v.calories,
        stressPressure: v.pressure,
        gpsLat: _lastPoint?.lat,
        gpsLng: _lastPoint?.lng,
        gpsSpeed: _currentSpeed,
        altitude: _lastAltitude,
        elevationGain: _elevationGain,
      ));
    }
    _notify();
  }

  /// Speaks a care cue on sustained steep climbs and descents (≥8% grade over
  /// ~80 m), at most once every three minutes.
  void _maybeEmitTerrainCue(double altitude) {
    _gradeRefDist ??= _distanceMeters;
    _gradeRefAlt ??= altitude;
    final dDist = _distanceMeters - _gradeRefDist!;
    if (dDist < 80) return;
    final grade = (altitude - _gradeRefAlt!) / dDist;
    _gradeRefDist = _distanceMeters;
    _gradeRefAlt = altitude;
    if ((_elapsed - _lastTerrainCue).inSeconds < 180) return;
    if (grade >= 0.08) {
      _lastTerrainCue = _elapsed;
      emitCue('Steep climb — shorten your stride and keep the breath steady.');
    } else if (grade <= -0.08) {
      _lastTerrainCue = _elapsed;
      emitCue('Descending — soft knees, easy control.');
    }
  }

  /// Average pace so far as a spoken "M SS" string, or null before there is
  /// enough distance to be meaningful.
  String? _spokenPace() {
    if (_distanceMeters < 50 || _elapsed.inSeconds == 0) return null;
    final secPerKm = _elapsed.inSeconds / (_distanceMeters / 1000);
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).round().toString().padLeft(2, '0');
    return '$m $s';
  }

  void _emitSplitCue() {
    final isGps = _activity?.gps ?? false;
    final parts = <String>['${_elapsed.inMinutes} minutes in.'];
    if (isGps) {
      if (_distanceMeters > 50) {
        parts.add(
            '${(_distanceMeters / 1000).toStringAsFixed(1)} kilometres.');
      }
      final pace = _spokenPace();
      if (pace != null) parts.add('Pace $pace per kilometre.');
    }
    if (_heartRate != null) {
      parts.add('Heart rate $_heartRate.');
      final zone = hrZoneIndex(_heartRate);
      if (zone >= 0) parts.add('Zone ${zone + 1}.');
    }
    if (isGps) {
      parts.add('Elevation gain ${_elevationGain.round()} metres.');
    } else {
      // Indoor and strength sessions get a short zone-matched encouragement.
      final zone = hrZoneIndex(_heartRate);
      parts.add(zone >= 3
          ? 'Working hard — stay smooth.'
          : zone >= 2
              ? 'Strong rhythm — keep it here.'
              : 'Easy and steady. Well done.');
    }
    emitCue(parts.join(' '));
  }

  /// Shows [text] in the cue banner and (if enabled) speaks it; auto-clears.
  /// The end-of-practice cue: lets a breath pacer finish its exhale, then a
  /// soft sound plus a haptic, then the in-screen "Time's up" state.
  Future<void> _ringEndBell() async {
    final kind = _activity?.kind;
    if (kind == 'breath') {
      // One breath at most — long enough to land on an out-breath, short
      // enough not to feel like a delay.
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!_active || _disposed) return;
    }
    unawaited(SystemSound.play(SystemSoundType.alert));
    unawaited(HapticFeedback.mediumImpact());
    emitCue("Time's up.");
    _notify();
  }

  void emitCue(String text) {
    _cueClearTimer?.cancel();
    _activeCue = text;
    if (_ref.read(voiceCuesEnabledProvider)) {
      unawaited(_ref.read(voiceCueServiceProvider).speak(text));
    }
    _notify();
    _cueClearTimer = Timer(const Duration(milliseconds: 5400), () {
      if (_disposed) return;
      _activeCue = null;
      _notify();
    });
  }

  void _onRawEvent(Map<dynamic, dynamic> event) {
    final id = _sessionId;
    if (id == null || !_active) return;
    unawaited(_db.addRawEvent(
      sessionId: id,
      timestamp: DateTime.now(),
      payload: event.toString(),
    ));
  }

  // ── Recovery of a killed session (bug 13(e)) ──────────────────────────────

  /// An unfinished session found on launch, offered as "Your walk from 14:02
  /// is still recording" with Resume / End it. Null when there is none.
  SessionRow? _recoverable;

  SessionRow? get recoverableSession => _recoverable;

  /// Looks for a session that was never finished — the process was killed
  /// mid-walk. Its samples and route points are already in the vault, so
  /// nothing captured is lost; it just needs closing or resuming.
  Future<void> findRecoverableSession() async {
    if (_active) return;
    final row = await _db.unfinishedSession();
    if (_disposed || row == null) return;
    // A session older than a day is stale: close it silently rather than
    // asking about a walk from last week.
    if (DateTime.now().difference(row.startedAt) > const Duration(hours: 24)) {
      await _endRecovered(row);
      return;
    }
    _recoverable = row;
    _notify();
  }

  /// Picks the recovered session back up, with its original start time, so
  /// the clock continues from where it actually began.
  Future<String?> resumeRecoveredSession() async {
    final row = _recoverable;
    if (row == null || _active) return 'Nothing to resume.';
    final activity = activityById(row.vyanaActivityType);
    if (activity == null) {
      await _endRecovered(row);
      return 'That practice is no longer in the catalogue.';
    }

    _activity = activity;
    _sessionId = row.id;
    _startedAt = row.startedAt;
    _active = true;
    _paused = false;
    _pausedTotal = Duration.zero;
    _pausedAt = null;
    _elapsed = _wallClockElapsed();
    _plannedMinutes = null;
    _bellRung = false;
    _overrun = false;
    _recoverable = null;

    final existing = await _db.samplesFor(row.id);
    _sampleCount = existing.length;
    _hrSeries
      ..clear()
      ..addAll([
        for (final sample in existing)
          if (sample.heartRate != null) sample.heartRate!,
      ]);
    if (_hrSeries.length > 240) {
      _hrSeries.removeRange(0, _hrSeries.length - 240);
    }

    final route = await _db.routeFor(row.id);
    _route
      ..clear()
      ..addAll([
        for (final p in route) (lat: p.lat, lng: p.lng),
      ]);
    _distanceMeters = 0;
    for (var i = 1; i < _route.length; i++) {
      _distanceMeters += Geolocator.distanceBetween(
        _route[i - 1].lat,
        _route[i - 1].lng,
        _route[i].lat,
        _route[i].lng,
      );
    }
    _lastPoint = _route.isEmpty ? null : _route.last;
    _lastKmAnnounced = _distanceMeters ~/ 1000;
    _elevation = activity.gps ? ElevationTracker() : null;
    _gpsState = activity.gps ? GpsState.searching : GpsState.notUsed;

    final ring = _ring;
    ring.setSessionActive(true);
    ring.sessionEventSink = _onRawEvent;
    _startSteps = ring.vitals.steps;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _notify();

    if (ring.isConnected) {
      unawaited(ring.repo.startSport(sportTypeCodeForRing(activity.ring)));
      unawaited(ring.repo.setRealtimeData(true));
    }
    if (activity.gps) unawaited(_startLocation(row.id));
    return null;
  }

  /// Closes the recovered session at the last moment actually captured, and
  /// recomputes its summary from stored samples and route points.
  Future<void> endRecoveredSession() async {
    final row = _recoverable;
    if (row == null) return;
    await _endRecovered(row);
  }

  Future<void> _endRecovered(SessionRow row) async {
    final lastSample = await _db.lastSampleTime(row.id);
    final endedAt = lastSample ?? row.startedAt;
    final samples = await _db.samplesFor(row.id);
    final route = await _db.routeFor(row.id);

    final hrs = [
      for (final s in samples)
        if (s.heartRate != null) s.heartRate!,
    ];
    int? avg, mx, mn;
    final zones = List<int>.filled(5, 0);
    if (hrs.isNotEmpty) {
      avg = (hrs.reduce((a, b) => a + b) / hrs.length).round();
      mx = hrs.reduce(math.max);
      mn = hrs.reduce(math.min);
      for (final hr in hrs) {
        final z = hrZoneIndex(hr);
        if (z >= 0) zones[z]++;
      }
    }
    var distance = 0.0;
    for (var i = 1; i < route.length; i++) {
      distance += Geolocator.distanceBetween(
        route[i - 1].lat,
        route[i - 1].lng,
        route[i].lat,
        route[i].lng,
      );
    }
    final activity = activityById(row.vyanaActivityType);
    final summary = {
      'activity': row.vyanaActivityType,
      'category': row.category,
      'kind': activity?.kind,
      'durationSec': endedAt.difference(row.startedAt).inSeconds,
      'samples': samples.length,
      'avgHr': avg,
      'maxHr': mx,
      'minHr': mn,
      'zones': zones,
      'recovery': mx != null && hrs.isNotEmpty ? mx - hrs.last : null,
      'distanceMeters': distance.round(),
      'elevationGain': 0,
      'recovered': true,
    };
    await _db.finishSession(row.id, endedAt, jsonEncode(summary));
    if (_disposed) return;
    _recoverable = null;
    _notify();
  }

  /// Dismisses the offer without closing the session, so it can be decided
  /// later rather than being lost.
  void dismissRecoverable() {
    if (_recoverable == null) return;
    _recoverable = null;
    _notify();
  }

  Future<void> pause() async {
    if (!_active || _paused) return;
    _paused = true;
    _pausedAt = DateTime.now();
    final a = _activity;
    if (a != null && _ring.isConnected) {
      await _ring.repo.pauseSport(sportTypeCodeForRing(a.ring));
    }
    _notify();
  }

  Future<void> resume() async {
    if (!_active || !_paused) return;
    _paused = false;
    final pausedAt = _pausedAt;
    if (pausedAt != null) {
      _pausedTotal += DateTime.now().difference(pausedAt);
      _pausedAt = null;
    }
    final a = _activity;
    if (a != null && _ring.isConnected) {
      await _ring.repo.resumeSport(sportTypeCodeForRing(a.ring));
    }
    _notify();
  }

  /// Stops the ring sport, releases the scheduler and finalises the session
  /// with a computed summary. The summary is returned for the post-session UI.
  Future<Map<String, dynamic>> end() async {
    // A session that ends early must not leave its bell scheduled.
    unawaited(VitalsNotificationService.instance.cancelPracticeEnd());
    if (!_active) return _lastSummary ?? const {};
    _ticker?.cancel();
    _ticker = null;
    _posSub?.cancel();
    _posSub = null;
    _cueClearTimer?.cancel();
    _activeCue = null;
    unawaited(_ref.read(voiceCueServiceProvider).stop());

    final ring = _ring;
    final a = _activity;
    final id = _sessionId;
    if (a != null && ring.isConnected) {
      await ring.repo.stopSport(sportTypeCodeForRing(a.ring));
      await ring.repo.setRealtimeData(false);
    }
    ring.sessionEventSink = null;
    ring.setSessionActive(false);

    final endedAt = _backdateEndTo ?? DateTime.now();
    if (_backdateEndTo != null) {
      // Back-dated: the elapsed figure must match the time actually practised.
      final started = _startedAt;
      if (started != null) _elapsed = endedAt.difference(started);
    }
    final summary = _computeSummary();
    if (id != null) {
      await _db.finishSession(id, endedAt, jsonEncode(summary));
      if (_ref.read(sessionSyncEnabledProvider)) {
        unawaited(_ref.read(sessionSyncServiceProvider).queue(id));
      }
    }
    // Lucid dreaming is the one practice whose result arrives the next
    // morning: finishing it arms the Journal's wake capture.
    if (a?.id == kLucidDreamingId && _elapsed.inMinutes >= 2) {
      unawaited(_ref.read(lucidArmedProvider.notifier).arm());
    }

    _active = false;
    _paused = false;
    _backdateEndTo = null;
    _forgottenFired = false;
    _forgottenSnoozedUntil = null;
    _hrSettledAt = null;
    _lastSummary = summary;
    _notify();
    return summary;
  }

  Map<String, dynamic> _computeSummary() {
    int? avg, mx, mn;
    final zones = List<int>.filled(5, 0);
    if (_hrSeries.isNotEmpty) {
      avg = (_hrSeries.reduce((a, b) => a + b) / _hrSeries.length).round();
      mx = _hrSeries.reduce((a, b) => a > b ? a : b);
      mn = _hrSeries.reduce((a, b) => a < b ? a : b);
      for (final hr in _hrSeries) {
        final z = hrZoneIndex(hr);
        if (z >= 0) zones[z]++;
      }
    }
    // HR recovery: drop from peak to the final reading.
    final recovery =
        (mx != null && _hrSeries.isNotEmpty) ? (mx - _hrSeries.last) : null;
    return {
      'activity': _activity?.id,
      'category': _activity?.cat,
      'kind': _activity?.kind,
      'durationSec': _elapsed.inSeconds,
      'samples': _sampleCount,
      'avgHr': avg,
      'maxHr': mx,
      'minHr': mn,
      'zones': zones,
      'recovery': recovery,
      'distanceMeters': _distanceMeters.round(),
      'elevationGain': _elevationGain.round(),
      if (_sessionSteps != null) 'steps': _sessionSteps,
    };
  }

  /// Clears the finished-session view state (after the summary is dismissed).
  void clear() {
    if (_active) return;
    _activity = null;
    _plannedMinutes = null;
    _bellRung = false;
    _overrun = false;
    _sessionId = null;
    _lastSummary = null;
    _elapsed = Duration.zero;
    _pausedTotal = Duration.zero;
    _pausedAt = null;
    _sessionSteps = null;
    _startSteps = null;
    _gpsState = GpsState.notUsed;
    _elevation = null;
    _sampleCount = 0;
    _heartRate = null;
    _hrSeries.clear();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _posSub?.cancel();
    _cueClearTimer?.cancel();
    super.dispose();
  }
}

final sessionControllerProvider =
    ChangeNotifierProvider<SessionController>((ref) => SessionController(ref));
