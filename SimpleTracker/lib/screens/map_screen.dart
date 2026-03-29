import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tracker_provider.dart';
import '../widgets/live_map_widget.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final provider = Provider.of<TrackerProvider>(context);
  final telemetry = provider.telemetry;
  final remoteFix = telemetry?.remoteFix;
  final localFix = telemetry?.localFix;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: LiveMapWidget(
                  latitude: remoteFix?.latitude,
                  longitude: remoteFix?.longitude,
                  trackerAltitude: remoteFix?.altitude,
                  trackerLabel: provider.selectedRemoteUID,
                  localLatitude: localFix?.latitude,
                  localLongitude: localFix?.longitude,
                  localAltitude: localFix?.altitude,
                  localLabel: 'Ground Station',
                  trackerRssi: telemetry?.rssi,
                  trackerVerticalVelocity: telemetry?.verticalVelocity,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
