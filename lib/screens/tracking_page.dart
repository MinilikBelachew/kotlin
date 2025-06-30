import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../screens/profile_screen.dart';
import 'package:provider/provider.dart';
import '../providers/map_style_provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:app_settings/app_settings.dart';

class TrackingPage extends StatefulWidget {
  final String token;
  final int driverId;
  final String driverName;
  final VoidCallback onLogout;

  const TrackingPage({
    required this.token,
    required this.driverId,
    required this.driverName,
    required this.onLogout,
    super.key,
  });

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> with WidgetsBindingObserver {
  IO.Socket? socket;
  bool isConnected = false;
  Position? currentPosition;
  String connectionStatus = "Connecting...";
  String currentAddress = "Fetching address...";
  StreamSubscription<Position>? positionSub;

  final MapController _mapController = MapController();
  final List<Marker> _markers = [];
  static const LatLng _initialCameraPosition = LatLng(39.7392, -104.9903);

  int _selectedIndex = 0;

  final String serverUrl = 'http://192.168.119.177:4000';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLocationPermissions();
    _connectSocketIO();
    _startLocationUpdates();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkLocationPermissions();
    }
  }

  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, show a dialog.
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Location Services Disabled'),
            content:
                const Text('Please enable location services to use this app.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  AppSettings.openAppSettings(type: AppSettingsType.location);
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      // Permissions are denied, show a dialog.
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Location Permissions Required'),
            content: const Text(
                'This app needs location permissions to track your location. Please grant "Always Allow" in your settings.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  AppSettings.openAppSettings(type: AppSettingsType.settings);
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _connectSocketIO() {
    try {
      socket = IO.io(serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'extraHeaders': {'token': widget.token},
      });

      socket!.onConnect((_) {
        if (mounted) {
          setState(() {
            isConnected = true;
            connectionStatus = "Connected";
          });
        }
      });

      socket!.onDisconnect((_) {
        if (mounted) {
          setState(() {
            isConnected = false;
            connectionStatus = "Disconnected";
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          connectionStatus = "Connection Error";
        });
      }
      debugPrint("Socket connection error: $e");
    }
  }

  void _startLocationUpdates() {
    positionSub?.cancel();
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 10,
    );
    positionSub =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (position) {
        _updateUIWithLocation(position);
      },
      onError: (e) {
        debugPrint("Location stream error: $e");
      },
    );
  }

  Future<void> _updateUIWithLocation(Position position) async {
    if (!mounted) return;

    setState(() {
      currentPosition = position;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          currentAddress =
              '${place.street}, ${place.locality}, ${place.country}';
        });
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
      setState(() {
        currentAddress = "Address not found";
      });
    }

    _updateMarker(position);
  }

  void _updateMarker(Position position) {
    if (!mounted) return;
    setState(() {
      _markers.clear();
      final latLng = LatLng(position.latitude, position.longitude);
      _markers.add(
        Marker(
          point: latLng,
          width: 80,
          height: 80,
          child: Column(
            children: [
              Icon(
                Icons.location_on,
                color: Theme.of(context).primaryColor,
                size: 40,
              ),
              Text(
                widget.driverName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      );
      if (_selectedIndex == 0) {
        _mapController.move(latLng, _mapController.camera.zoom);
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    positionSub?.cancel();
    socket?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapStyleProvider = Provider.of<MapStyleProvider>(context);

    List<Widget> widgetOptions = <Widget>[
      Column(
        children: [
          ListTile(
            title: const Text("Location Status"),
            subtitle: Text(connectionStatus),
            trailing: Icon(
              isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: isConnected ? Colors.green : Colors.red,
            ),
          ),
          ListTile(
            title: const Text("Current Location"),
            subtitle: Text(currentAddress),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: currentPosition != null
                    ? LatLng(
                        currentPosition!.latitude, currentPosition!.longitude)
                    : _initialCameraPosition,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: mapStyleProvider.currentMapStyle.url,
                  userAgentPackageName: 'com.example.flutter_driver_app',
                ),
                MarkerLayer(markers: _markers),
              ],
            ),
          ),
        ],
      ),
      ProfileScreen(
        driverName: widget.driverName,
        driverId: widget.driverId.toString(),
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver App'),
      ),
      body: Center(child: widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}