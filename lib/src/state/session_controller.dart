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

  bool get active => _active;
  bool get paused => _paused;
  Activity? get activity => _activity;
  String? get sessionId => _sessionId;
  DateTime? get startedAt => _startedAt;
  Duration get elapsed => _elapsed;
  int get sampleCount => _sampleCount;
  int? get heartRate => _heartRate;
  List<int> get hrSeries => List.unmodifiable(_hrSeries);
  Map<String, dynamic>? get lastSummary => _lastSummary;

  List<({double lat, double lng})> get route => List.unmodifiable(_route);
  double get distanceMeters => _distanceMeters;
  double get elevationGain => _elevationGain;

  /// Current speed in m/s, or null if unknown.
  double? get currentSpeed => _currentSpeed;

  /// The voice cue currently showing in the banner (auto-clears).
  String? get activeCue => _activeCue;

  RingController get _ring => _ref.read(ringControllerProvider);
  VyanaDatabase get _db => _ref.read(databaseProvider);

  /// Starts a session for [activity]. Returns null on success, or a reason if
  /// it could not start (scheduler conflict). Capture works even if the ring is
  /// offline — it just records no physiology.
  Future<String?> start(Activity activity) async {
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
    _sessionId = id;
    _startedAt = now;
    _active = true;
    _paused = false;
    _elapsed = Duration.zero;
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

    return null;
  }

  Future<void> _startLocation(String sessionId) async {
    final ok = await _ref.read(locationServiceProvider).ensurePermission();
    if (!ok || _disposed || !_active) return;
    _posSub = _ref.read(locationServiceProvider).positions().listen((pos) {
      if (!_active || _paused || _disposed) return;
      final point = (lat: pos.latitude, lng: pos.longitude);
      final last = _lastPoint;
      if (last != null) {
        _distanceMeters += Geolocator.distanceBetween(
            last.lat, last.lng, point.lat, point.lng);
      }
      if (_lastAltitude != null && pos.altitude > _lastAltitude!) {
        _elevationGain += pos.altitude - _lastAltitude!;
      }
      _lastAltitude = pos.altitude;
      _lastPoint = point;
      _currentSpeed = pos.speed >= 0 ? pos.speed : null;
      _route.add(point);
      if (_route.length > 3000) _route.removeAt(0);
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
    _elapsed += const Duration(seconds: 1);
    final v = _ring.vitals;
    if (v.heartRate != null) {
      _heartRate = v.heartRate;
      _hrSeries.add(v.heartRate!);
      if (_hrSeries.length > 240) _hrSeries.removeAt(0);
    }
    _sampleCount++;

    // Spoken split every 5 minutes for movement sessions.
    final kind = _activity?.kind;
    if ((kind == 'gps' || kind == 'indoor' || kind == 'strength') &&
        _elapsed.inSeconds > 0 &&
        _elapsed.inSeconds % 300 == 0) {
      _emitSplitCue();
    }

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

  void _emitSplitCue() {
    final parts = <String>['${_elapsed.inMinutes} minutes.'];
    if ((_activity?.gps ?? false) && _distanceMeters > 50) {
      final secPerKm = _elapsed.inSeconds / (_distanceMeters / 1000);
      final m = secPerKm ~/ 60;
      final s = (secPerKm % 60).round().toString().padLeft(2, '0');
      parts.add('Pace $m $s per kilometre.');
    }
    if (_heartRate != null) parts.add('Heart rate $_heartRate.');
    if ((_activity?.gps ?? false) && _elevationGain > 5) {
      parts.add('Elevation gain ${_elevationGain.round()} metres.');
    }
    emitCue(parts.join(' '));
  }

  /// Shows [text] in the cue banner and (if enabled) speaks it; auto-clears.
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

  Future<void> pause() async {
    if (!_active || _paused) return;
    _paused = true;
    final a = _activity;
    if (a != null && _ring.isConnected) {
      await _ring.repo.pauseSport(sportTypeCodeForRing(a.ring));
    }
    _notify();
  }

  Future<void> resume() async {
    if (!_active || !_paused) return;
    _paused = false;
    final a = _activity;
    if (a != null && _ring.isConnected) {
      await _ring.repo.resumeSport(sportTypeCodeForRing(a.ring));
    }
    _notify();
  }

  /// Stops the ring sport, releases the scheduler and finalises the session
  /// with a computed summary. The summary is returned for the post-session UI.
  Future<Map<String, dynamic>> end() async {
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

    final summary = _computeSummary();
    if (id != null) {
      await _db.finishSession(id, DateTime.now(), jsonEncode(summary));
      if (_ref.read(sessionSyncEnabledProvider)) {
        unawaited(_ref.read(sessionSyncServiceProvider).queue(id));
      }
    }

    _active = false;
    _paused = false;
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
    };
  }

  /// Clears the finished-session view state (after the summary is dismissed).
  void clear() {
    if (_active) return;
    _activity = null;
    _sessionId = null;
    _lastSummary = null;
    _elapsed = Duration.zero;
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
