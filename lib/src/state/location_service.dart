part of '../../main.dart';

/// How precise a fix must be before it is allowed to move the numbers. Bug
/// 13(c): every fix used to count, so distance and elevation were inflated by
/// the first wild readings before the GPS settled.
const double kGpsAccuracyCeilingMeters = 20;

/// Climbs smaller than this are noise in GPS altitude, not hills.
const double kMinElevationGainMeters = 3;

/// How the live screen reports the state of the GPS, so zeros are never
/// mistaken for "the session is not working" (bug 13(b)).
enum GpsState {
  /// Not an outdoor session.
  notUsed,

  /// Permission or location services missing.
  denied,

  /// Waiting for the first fix good enough to trust.
  searching,

  /// Fixes are arriving within [kGpsAccuracyCeilingMeters].
  ready,
}

extension GpsStateX on GpsState {
  String? get label => switch (this) {
        GpsState.notUsed => null,
        GpsState.denied => 'GPS unavailable',
        GpsState.searching => 'Finding GPS…',
        GpsState.ready => 'GPS ready',
      };
}

/// Phone GPS for outdoor sessions. GPS, elevation and the route come from the
/// phone — never the ring (per the SDK constraints).
class LocationService {
  /// Whether the user has granted background location, which is what keeps
  /// the stream alive once the screen locks.
  Future<bool> hasBackgroundPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Asks for background ("Allow all the time") location, in plain language,
  /// after foreground access is already granted. Android only; on iOS the
  /// `always` authorisation comes through the same prompt.
  Future<bool> requestBackgroundPermission() async {
    if (await hasBackgroundPermission()) return true;
    // Android requires foreground permission before the background prompt
    // will show at all.
    if (!await ensurePermission()) return false;
    final permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always;
  }

  /// The position stream for a live session.
  ///
  /// Bug 13(a): on Android the stream must declare a location foreground
  /// service or the OS stops delivering fixes once the screen locks, which is
  /// the normal case for a walk or a run.
  Stream<Position> positions({String? notificationText}) {
    if (Platform.isAndroid) {
      return Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 4,
          foregroundNotificationConfig: ForegroundNotificationConfig(
            notificationTitle: 'Vyana is recording',
            notificationText: notificationText ?? 'Recording your session',
            enableWakeLock: true,
            setOngoing: true,
          ),
        ),
      );
    }
    return Geolocator.getPositionStream(
      locationSettings: AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 4,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
      ),
    );
  }
}

/// Smooths GPS altitude into usable elevation gain.
///
/// Bug 13(c): raw altitude was summed on every positive jump, so the figure
/// was zero without a fix and inflated with one. A moving median kills the
/// spikes, and only climbs over [kMinElevationGainMeters] count.
class ElevationTracker {
  ElevationTracker({this.windowSize = 5});

  final int windowSize;
  final List<double> _window = [];
  double? _reference;
  double _gain = 0;

  double get gainMeters => _gain;

  /// Feeds one altitude reading; returns the smoothed value, or null while
  /// the window is still filling.
  double? add(double altitude) {
    _window.add(altitude);
    if (_window.length > windowSize) _window.removeAt(0);
    if (_window.length < windowSize) return null;
    final sorted = [..._window]..sort();
    final median = sorted[sorted.length ~/ 2];
    final reference = _reference;
    if (reference == null) {
      _reference = median;
      return median;
    }
    final climb = median - reference;
    if (climb >= kMinElevationGainMeters) {
      _gain += climb;
      _reference = median;
    } else if (climb <= -kMinElevationGainMeters) {
      // Descending resets the reference so the next climb is measured from
      // the bottom, not from the previous summit.
      _reference = median;
    }
    return median;
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());
