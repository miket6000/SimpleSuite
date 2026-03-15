import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tracker_provider.dart';
import '../widgets/live_map_widget.dart';
import '../widgets/status_bar.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final telemetry = provider.telemetry;
    final remoteFix = telemetry?.remoteFix;

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
                  trackerLabel: provider.selectedRemoteUID,
                  localLatitude: telemetry?.localFix?.latitude,
                  localLongitude: telemetry?.localFix?.longitude,
                  localLabel: 'Ground Station',
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: StatusBar(
        isGpsFix: provider.remotePacketHasFix && provider.isConnected && provider.isRemoteOnline,
        isTrackerOnline: provider.isRemoteOnline && provider.isConnected,
        isLocalGPSFix: provider.telemetry?.localFix?.hasFix ?? false,
        isConnected: provider.isConnected,
      ),
    );
  }
}
