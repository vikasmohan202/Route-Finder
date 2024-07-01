import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  final Set<Polyline> polylines;
  final Location location;

  MapScreen({required this.location, required this.polylines});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    // The map bounds will be set once the map controller is initialized
  }

  void _setMapBounds() {
    if (_mapController != null && widget.polylines.isNotEmpty) {
      List<LatLng> polylinePoints = widget.polylines.first.points;
      LatLngBounds bounds = _calculateBounds(polylinePoints);

      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double x0 = points[0].latitude;
    double x1 = points[0].latitude;
    double y0 = points[0].longitude;
    double y1 = points[0].longitude;

    for (LatLng point in points) {
      if (point.latitude > x1) x1 = point.latitude;
      if (point.latitude < x0) x0 = point.latitude;
      if (point.longitude > y1) y1 = point.longitude;
      if (point.longitude < y0) y0 = point.longitude;
    }

    return LatLngBounds(
      northeast: LatLng(x1, y1),
      southwest: LatLng(x0, y0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(widget.location.latitude, widget.location.longitude),
          zoom: 10,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
          _setMapBounds(); // Set map bounds once the controller is initialized
        },
        polylines: widget.polylines,
      ),
    );
  }
}
