import 'package:flutter/material.dart';

import '../../logic/geo_tools.dart';
import 'compass_painter.dart';

/// Overlay widget displaying a compass rose with bearing arrow,
/// bearing text, and distance between ground station and remote tracker.
class BearingOverlay extends StatelessWidget {
  final double? localLatitude;
  final double? localLongitude;
  final double? remoteLatitude;
  final double? remoteLongitude;
  final double? localAltitude;
  final double? remoteAltitude;

  const BearingOverlay({
    super.key,
    required this.localLatitude,
    required this.localLongitude,
    required this.remoteLatitude,
    required this.remoteLongitude,
    this.localAltitude,
    this.remoteAltitude,
  });

  @override
  Widget build(BuildContext context) {
    final bearing = bearingBetween(
      localLatitude,
      localLongitude,
      remoteLatitude,
      remoteLongitude,
    );
    final distance = distanceBetween(
      localLatitude,
      localLongitude,
      remoteLatitude,
      remoteLongitude,
    );
    final compass = bearingToCompass(bearing);

    // Format distance for display
    String distanceText;
    if (distance == null) {
      distanceText = '—';
    } else if (distance >= 1000) {
      distanceText = '${(distance / 1000).toStringAsFixed(2)} km';
    } else {
      distanceText = '${distance.toStringAsFixed(0)} m';
    }

    final bearingText =
        bearing != null ? '${bearing.toStringAsFixed(1)}°' : '—';
    final compassText = compass ?? '—';

    final colorScheme = Theme.of(context).colorScheme;
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha:0.8),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Compass rose with bearing arrow
            SizedBox(
              width: 72,
              height: 72,
              child: CustomPaint(
                painter: CompassPainter(bearingDegrees: bearing ?? 0),
              ),
            ),
            const SizedBox(height: 4),
            // Bearing text
            Text(
              '$compassText  $bearingText',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            // Distance text
            Text(
              distanceText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
