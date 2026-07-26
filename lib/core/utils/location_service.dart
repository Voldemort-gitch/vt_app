import 'dart:math';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  static Future<Position?> getCurrentLocation() async {
    bool hasPermission = await checkPermission();
    if (!hasPermission) return null;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    return position;
  }

  static bool isLocationSpoofed(Position position) {
    return position.isMocked;
  }

  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const int earthRadius = 6371000; // meters
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  static bool isWithinRadius({
    required double userLat,
    required double userLng,
    required double officeLat,
    required double officeLng,
    required double allowedRadius,
  }) {
    final double distance = calculateDistance(
      userLat,
      userLng,
      officeLat,
      officeLng,
    );
    return distance <= allowedRadius;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
}
