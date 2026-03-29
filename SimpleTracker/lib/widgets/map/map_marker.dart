import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Reusable map marker with a location pin icon and optional label.
class MapMarker {
  /// Builds a [Marker] for use in a [MarkerLayer].
  static Marker build({
    required LatLng point,
    required Color color,
    String? label,
  }) {
    return Marker(
      point: point,
      width: 120,
      height: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on,
            color: color,
            size: 40,
          ),
          if (label != null && label.isNotEmpty)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
