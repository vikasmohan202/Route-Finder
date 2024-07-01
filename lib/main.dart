import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:route_finder/map.dart';
// ignore: depend_on_referenced_packages
import 'package:uuid/uuid.dart';
import 'package:geocoding/geocoding.dart';
import 'package:drop_down_search_field/drop_down_search_field.dart';

void main() => runApp(RouteFinderApp());

class RouteFinderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: RouteFinderHome(),
    );
  }
}

class RouteFinderHome extends StatefulWidget {
  @override
  _RouteFinderHomeState createState() => _RouteFinderHomeState();
}

class _RouteFinderHomeState extends State<RouteFinderHome> {
  // final Location _locationService = Location();
  TextEditingController _startController = TextEditingController();
  TextEditingController _destinationController = TextEditingController();
  final Set<Polyline> _polylines = {};
  final String _sessionToken = Uuid().v4();
  List<dynamic> _startSuggestions = [];
  List<dynamic> _destinationSuggestions = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _initLocationService();
  }

  void _initLocationService() async {
    try {
      // Check initial permission status
      LocationPermission permission = await Geolocator.checkPermission();

      // Request permission if initially denied
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          // Handle the case when the user denies permission
          debugPrint("Location permission denied");
          return;
        }
      }

      // Handle the case when the user has permanently denied permission
      if (permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        return;
      }

      // Get current position
    } on PlatformException catch (e) {
      // Handle platform-specific errors
      debugPrint("PlatformException while getting location: $e");
    } catch (e) {
      // Handle all other errors
      debugPrint("Error while getting location: $e");
    }
  }

  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=AIzaSyDGBBUl2gpsGC3L4X6PoEIBk5s5Mc8JNIM';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['results'].isNotEmpty) {
        return data['results'][0]['formatted_address'];
      }
    }
    return 'Unknown Location';
  }

  Future<void> _fetchRoute() async {
    setState(() {
      isLoading = true;
    });
    if (_startController.text.isEmpty || _destinationController.text.isEmpty) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${_startController.text}&destination=${_destinationController.text}&key=AIzaSyDGBBUl2gpsGC3L4X6PoEIBk5s5Mc8JNIM';

    http.Response response = await http.get(Uri.parse(url));
    Map<String, dynamic> data = jsonDecode(response.body);
    String distance = data['routes'][0]['legs'][0]['distance']['text'];
    print(distance);
    if (data['status'] == 'OK') {
      String encodedPolyline = data['routes'][0]['overview_polyline']['points'];
      List<LatLng> polylinePoints = _decodePolyline(encodedPolyline);
      _polylines.clear();
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: polylinePoints,
        color: Colors.blue,
        width: 5,
      ));
      List<Location> locations =
          await locationFromAddress(_startController.text);

      // ignore: use_build_context_synchronously
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapScreen(
            location: locations.first,
            polylines: _polylines,
          ),
        ),
      );
      setState(() {
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polyline;
  }

  Future<void> _getPlaceSuggestions(String input, bool isStartField) async {
    if (input.isEmpty) {
      setState(() {
        if (isStartField) {
          _startSuggestions = [];
        } else {
          _destinationSuggestions = [];
        }
      });
      return;
    }

    String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=AIzaSyDGBBUl2gpsGC3L4X6PoEIBk5s5Mc8JNIM&sessiontoken=$_sessionToken';

    http.Response response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      setState(() {
        if (isStartField) {
          _startSuggestions = jsonDecode(response.body)['predictions'];
        } else {
          _destinationSuggestions = jsonDecode(response.body)['predictions'];
        }
      });
    } else {
      setState(() {
        if (isStartField) {
          _startSuggestions = [];
        } else {
          _destinationSuggestions = [];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Finder'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _startController,
                      decoration: const InputDecoration(
                        labelText: 'Current Location',
                      ),
                      onChanged: (value) {
                        _getPlaceSuggestions(value, true);
                      },
                    ),
                  ),
                  _buildSuggestionsBox(_startSuggestions, true),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _destinationController,
                      decoration: const InputDecoration(
                        labelText: 'Destination',
                      ),
                      onChanged: (value) {
                        _getPlaceSuggestions(value, false);
                      },
                    ),
                  ),
                  _buildSuggestionsBox(_destinationSuggestions, false),
                  ElevatedButton(
                    onPressed: _fetchRoute,
                    child: const Text('Find Route'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSuggestionsBox(List<dynamic> suggestions, bool isStartField) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(suggestions[index]['description']),
          onTap: () {
            setState(() {
              if (isStartField) {
                _startController.text = suggestions[index]['description'];
                _startSuggestions = [];
              } else {
                _destinationController.text = suggestions[index]['description'];
                _destinationSuggestions = [];
              }
            });
          },
        );
      },
    );
  }
}
