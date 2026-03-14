import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/serial_provider.dart';
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
    final serial = Provider.of<SerialProvider>(context);
    final telemetry = serial.telemetry;
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
                  trackerLabel: serial.selectedRemoteUID,
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
        isGpsFix: serial.remotePacketHasFix && serial.isConnected && serial.isRemoteOnline,
        isTrackerOnline: serial.isRemoteOnline && serial.isConnected,
        isLocalGPSFix: serial.telemetry?.localFix?.hasFix ?? false,
        isConnected: serial.isConnected,
      ),
    );
  }
}
