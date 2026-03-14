import 'package:flutter/material.dart';
import 'package:gps_tracker/logic/geo_tools.dart';
import 'package:gps_tracker/models/gps_fix.dart';
import '../widgets/datatile.dart';
import '../widgets/status_bar.dart';
import '../widgets/location_qr_widget.dart';
import 'package:provider/provider.dart';
import '../providers/serial_provider.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  OverviewScreenState createState() => OverviewScreenState();
}

class OverviewScreenState extends State<OverviewScreen> {
  DateTime lastMessageTime = DateTime.now();
  double altOffset = 0.0;

  toggleAbsoluteAlt(GpsFix? remoteFix) {
    if (altOffset > 0.0) {
      altOffset = 0.0;
    } else {
      if (remoteFix?.altitude != null) {
        altOffset = remoteFix!.altitude!;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final serial = Provider.of<SerialProvider>(context);
    final telemetry = serial.telemetry;
    final remoteFix = telemetry?.remoteFix;
    final discoveredDevices = serial.discoveredDevices;
    final discoveredUIDs = discoveredDevices.keys.toList();
    final selectedUID = serial.selectedRemoteUID;

    final int crossAxisCount =
        MediaQuery.of(context).size.width > 650 ? 3 : 1; // For mobile
    final List dataTiles = [
      //DataTile(title: "Time",               value: telemetry?.localFix.timestamp != null ? DateFormat("HH:mm:ss").format(telemetry!.localFix.timestamp!) : null),
      DataTile(
          title: "Last Packet Age",
          value: serial.lastUniqueRemotePacketTime != null
              ? "${DateTime.now().difference(serial.lastUniqueRemotePacketTime!).inSeconds}s"
              : null),
      DataTile(
          title: "RSSI",
          value: telemetry?.rssi != null ? "${telemetry?.rssi} dBm" : null),
      DataTile(
          title: "Altitude",
          value: remoteFix?.altitude != null
              ? "${(remoteFix!.altitude! - altOffset).toStringAsFixed(0)} m"
              : null,
          onPressed: () => toggleAbsoluteAlt(remoteFix)),
      DataTile(
          title: "Latitude",
          value: remoteFix?.latitude != null
              ? remoteFix!.latitude!.toStringAsFixed(4)
              : null),
      DataTile(
          title: "Longitude",
          value: remoteFix?.longitude != null
              ? remoteFix!.longitude!.toStringAsFixed(4)
              : null),
      DataTile(
          title: "Vertical Velocity",
          value: telemetry?.verticalVelocity != null
              ? "${telemetry!.verticalVelocity!.toStringAsFixed(0)} m/s"
              : null),
      DataTile(
          title: "Bearing",
          value: telemetry?.bearing != null
              ? "${telemetry!.bearing!.toStringAsFixed(0)} deg (${bearingToCompass(telemetry.bearing)})"
              : null),
      DataTile(
          title: "Distance",
          value: telemetry?.distance != null
              ? "${telemetry!.distance!.toStringAsFixed(0)} m"
              : null),
      DataTile(
          title: "Elevation",
          value: telemetry?.elevation != null
              ? "${telemetry!.elevation!.toStringAsFixed(0)} deg"
              : null),
    ];

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Remote Tracker Selection',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          if (serial.isPaired)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ElevatedButton.icon(
                                onPressed: () => serial.selectRemoteUID(null),
                                icon: const Icon(Icons.link_off, size: 16),
                                label: const Text('Unpair'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                          ElevatedButton.icon(
                            onPressed: serial.isConnected &&
                                    !serial.isScanning &&
                                    !serial.isPaired
                                ? () => serial.startScan()
                                : null,
                            icon: serial.isScanning
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.search, size: 16),
                            label: Text(
                                serial.isScanning ? 'Scanning...' : 'Scan'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (discoveredUIDs.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'No trackers discovered yet',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Individual tracker buttons with RSSI
                        ...discoveredUIDs.map((uid) {
                          final isSelected = selectedUID == uid;
                          final rssi = discoveredDevices[uid];
                          return FilterChip(
                            label: Text('$uid (${rssi} dBm)'),
                            selected: isSelected,
                            onSelected: serial.isPaired
                                ? null
                                : (_) => serial.selectRemoteUID(uid),
                          );
                        }),
                      ],
                    ),
                  if (discoveredUIDs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(
                        'Discovered: ${discoveredUIDs.length} tracker(s)',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
            GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisExtent: 80, // Set fixed height for each item
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: dataTiles.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                return dataTiles[index];
              },
            ),
            SizedBox(height: 20),
            LocationQrWidget(
              latitude: remoteFix?.latitude,
              longitude: remoteFix?.longitude,
            ),
          ],
        ),
      ),
      bottomNavigationBar: StatusBar(
          // use the "most recent packet had fix" flag so we reflect current packet state
          isGpsFix: serial.remotePacketHasFix &&
              serial.isConnected &&
              serial.isRemoteOnline,
          isTrackerOnline: serial.isRemoteOnline && serial.isConnected,
          isLocalGPSFix: (serial.telemetry?.localFix?.hasFix ?? false) &&
              serial.isConnected,
          isConnected: serial.isConnected),
    );
  }
}
