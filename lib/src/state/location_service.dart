part of '../../main.dart';

/// Phone GPS for outdoor sessions. GPS, elevation and the route come from the
/// phone — never the ring (per the SDK constraints).
class LocationService {
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Stream<Position> positions() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 4,
        ),
      );
}

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());
