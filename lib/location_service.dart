import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'notification_service.dart';

class LocationService {
  static const restrictedLatitude = -6.1993446;
  static const restrictedLongitude = 39.3077723;

  // Function to get the current location
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  // Function to track location continuously
  static Stream<Position> trackLocation() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update position when the device moves 10 meters
      ),
    );
  }

  // Function to calculate distance between two points
  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000; // Earth's radius in meters
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  // Helper function to convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Function to check proximity to the restricted area
  static Future<void> checkForRestrictedArea(Position position) async {
    final distance = calculateDistance(
      position.latitude,
      position.longitude,
      restrictedLatitude,
      restrictedLongitude,
    );

    if (distance <= 10) {
      // Send notification to the local device
      await NotificationService.showNotification(
        'Restricted Area',
        'You are in a restricted area!',
      );

      // Send notification to the database
      final deviceId = await getDeviceId();
      await sendNotificationToServer(
          position.latitude, position.longitude, deviceId);
    }
  }

// Function to send notifications to the server
  static Future<void> sendNotificationToServer(
      double latitude, double longitude, String deviceId) async {
    final url =
        Uri.parse('http://192.168.204.3/mamix/db/save_notifications.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'device_id': deviceId,
          'latitude': latitude,
          'longitude': longitude,
          'message': 'You are in a restricted area!',
          'message_to_admin': 'This Vessel entered in a restricted area',
        }),
      );

      if (response.statusCode != 200) {
        print('Failed to send notification to server: ${response.body}');
      }
    } catch (e) {
      print('Error sending notification to server: $e');
    }
  }

  // Function to retrieve device ID (Android or iOS)
  static Future<String> getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String deviceId;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.model;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? 'unknown_device';
    } else {
      deviceId = 'unsupported_platform';
    }

    return deviceId;
  }

  // Function to send location data to the PHP backend
  static Future<void> sendLocationToServer(
      Position position, String deviceId) async {
    final deviceId = await getDeviceId();
    final url = Uri.parse(
        'http://192.168.146.3/mamix/db/save_location.php'); // Endpoint to update location
    final data = {
      'deviceId': deviceId,
      'latitude': position.latitude,
      'longitude': position.longitude,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode != 200) {
        print('Failed to send location to server: ${response.body}');
      }
    } catch (e) {
      print('Error sending location to server: $e');
    }
  }

  // Function to send location data to backend with device ID
  static Future<void> sendLocationToBackend(
      double latitude, double longitude) async {
    final deviceId = await getDeviceId();

    final url = Uri.parse('http://192.168.146.3/mamix/db/save_location.php');
    final response = await http.post(
      url,
      body: jsonEncode({
        'device_id': deviceId,
        'latitude': latitude,
        'longitude': longitude,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send location data');
    }
  }
}
