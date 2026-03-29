import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Floating action buttons for centering the map on the remote tracker
/// and/or the local ground station.
class MapCenterButtons extends StatelessWidget {
  final LatLng? remotePosition;
  final LatLng? localPosition;
  final MapController mapController;

  const MapCenterButtons({
    super.key,
    this.remotePosition,
    this.localPosition,
    required this.mapController,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Center on remote tracker (bottom-left)
        if (remotePosition != null)
          Positioned(
            bottom: 16,
            left: 16,
            child: FloatingActionButton.small(
              onPressed: () {
                mapController.move(remotePosition!, mapController.camera.zoom);
              },
              backgroundColor: Colors.red,
              child:
                  const Icon(Icons.location_on, color: Colors.white, size: 20),
            ),
          ),
        // Center on ground station (bottom, offset right)
        if (localPosition != null)
          Positioned(
            bottom: 16,
            left: 80,
            child: FloatingActionButton.small(
              onPressed: () {
                mapController.move(localPosition!, mapController.camera.zoom);
              },
              backgroundColor: Colors.blue,
              child:
                  const Icon(Icons.location_on, color: Colors.white, size: 20),
            ),
          ),
      ],
    );
  }
}
