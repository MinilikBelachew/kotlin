import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enum to define different map styles
enum MapStyle {
  osmStandard(
    name: 'Standard OSM',
    url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  ),
  osmHot(
    name: 'Humanitarian OSM',
    url: 'https://tileserver.memomaps.de/tilegen/{z}/{x}/{y}.png',
  ),
  osmCyclo(
    name: 'OpenCycleMap',
    url:
        'https://tile.thunderforest.com/cycle/{z}/{x}/{y}.png?apikey=YOUR_API_KEY', // Add API Key if needed
  ),
  stamenToner(
    name: 'Stamen Toner',
    url: 'https://stamen-tiles.a.ssl.fastly.net/toner/{z}/{x}/{y}.png',
  ),
  stamenTerrain(
    name: 'Stamen Terrain',
    url: 'https://stamen-tiles.a.ssl.fastly.net/terrain/{z}/{x}/{y}.png',
  );

  const MapStyle({required this.name, required this.url});
  final String name;
  final String url;
}

class MapStyleProvider with ChangeNotifier {
  MapStyle _currentMapStyle = MapStyle.osmStandard;

  MapStyle get currentMapStyle => _currentMapStyle;

  Future<void> loadMapStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStyleName = prefs.getString('mapStyle');
    if (savedStyleName != null) {
      try {
        _currentMapStyle = MapStyle.values.firstWhere(
            (style) => style.name == savedStyleName,
            orElse: () => MapStyle.osmStandard);
      } catch (e) {
        debugPrint("Error loading map style: $e");
        _currentMapStyle = MapStyle.osmStandard;
      }
    }
    notifyListeners();
  }

  void setMapStyle(MapStyle style) async {
    _currentMapStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mapStyle', style.name);
    notifyListeners();
  }
}