import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Location Tracker',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LocationTrackerScreen(),
    );
  }
}

class LocationTrackerScreen extends StatefulWidget {
  const LocationTrackerScreen({Key? key}) : super(key: key);

  @override
  State<LocationTrackerScreen> createState() => _LocationTrackerScreenState();
}

class _LocationTrackerScreenState extends State<LocationTrackerScreen> {
  Position? _currentPosition;
  final String _deviceId =
      'unique_device_id_123'; // Replace with actual device identifier

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
  }

  /// Starts location updates and sends them to the server automatically.
  void _startLocationUpdates() {
    LocationService.trackLocation().listen((Position position) {
      setState(() {
        _currentPosition = position;
      });

      // Check for proximity to the restricted area
      LocationService.checkForRestrictedArea(position);

      // Automatically send location to the server
      LocationService.sendLocationToServer(position, _deviceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Location Tracker')),
      body: Center(
        child: _currentPosition == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Latitude: ${_currentPosition!.latitude}',
                    style: const TextStyle(fontSize: 20),
                  ),
                  Text(
                    'Longitude: ${_currentPosition!.longitude}',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Location updates are sent to the server automatically.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}
