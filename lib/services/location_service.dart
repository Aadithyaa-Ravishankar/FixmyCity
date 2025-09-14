import 'dart:math';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Position? _currentPosition;
  
  // Get user's current location - always request permission
  static Future<Position?> getCurrentLocation() async {
    try {
      // Check current permission status first
      LocationPermission permission = await Geolocator.checkPermission();
      
      // If denied, request permission
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      // Handle different permission states
      if (permission == LocationPermission.denied) {
        print('Location permission denied by user.');
        return null;
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied.');
        return null;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled. Please enable location services.');
        return null;
      }

      // Get current position with web-friendly settings
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Use medium for better web compatibility
        timeLimit: const Duration(seconds: 30), // Longer timeout for web
      );
      
      _currentPosition = position;
      print('Location obtained: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('Error getting location: $e');
      // Try with lower accuracy as fallback
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 10),
        );
        _currentPosition = position;
        print('Location obtained with low accuracy: ${position.latitude}, ${position.longitude}');
        return position;
      } catch (fallbackError) {
        print('Fallback location attempt failed: $fallbackError');
        _currentPosition = null;
        return null;
      }
    }
  }

  // Calculate distance between two points using Haversine formula
  static double calculateDistance(
    double lat1, double lon1, 
    double lat2, double lon2
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;

    return distance; // Distance in kilometers
  }

  // Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Format distance for display
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      int meters = (distanceKm * 1000).round();
      return '${meters}m away';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)}km away';
    } else {
      return '${distanceKm.round()}km away';
    }
  }

  // Get cached current position
  static Position? getCachedPosition() {
    return _currentPosition;
  }

  // Calculate distance from current location to a point
  static String? getDistanceFromCurrent(double lat, double lon) {
    if (_currentPosition == null) return null;
    
    double distance = calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lon,
    );
    
    return formatDistance(distance);
  }
}
