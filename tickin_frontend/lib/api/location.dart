import 'package:geolocator/geolocator.dart';

import 'package:flutter/foundation.dart';

class LocationService {
  static Future<bool> _ensurePermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // UNIVERSAL LOCATION FETCH (Works on all Geolocator versions)
  static Future<Position?> _getLocation() async {
    bool ok = await _ensurePermission();
    if (!ok) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low, // battery saver & stable
      );
    } catch (e) {
      debugPrint("LOCATION ERROR: $e");
      return null;
    }
  }

  static Future<Position?> getCurrentPosition() async {
    return await _getLocation();
  }
}
