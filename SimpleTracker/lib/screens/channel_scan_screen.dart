import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tracker_provider.dart';
import '../services/settings_service.dart';

class ChannelScanScreen extends StatelessWidget {
  const ChannelScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final isScanning = provider.isChannelScanRunning;
    final results = provider.channelScanResults;
    final resultUIDs = results.keys.toList();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Channel Scan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    if (isScanning)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          'CH${provider.channelScanCurrent} / ${provider.channelScanTotal}',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey),
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: provider.isConnected &&
                              !provider.isPaired &&
                              !provider.isScanning
                          ? (isScanning
                              ? provider.stopChannelScan
                              : provider.startChannelScan)
                          : null,
                      icon: isScanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.radar, size: 16),
                      label: Text(isScanning ? 'Stop' : 'Scan Channels'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Progress bar
            if (isScanning)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(
                  value: provider.channelScanTotal > 0
                      ? provider.channelScanCurrent /
                          provider.channelScanTotal
                      : 0,
                ),
              ),

            // Description
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Sweeps channels 1–${channelPresets.length - 1}, '
                'listening for active trackers on each frequency. '
                'Found trackers can be added to the Overview list.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),

            // Results
            Expanded(
              child: resultUIDs.isEmpty
                  ? Center(
                      child: Text(
                        isScanning
                            ? 'Scanning...'
                            : 'No trackers found. Tap "Scan Channels" to start.',
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: resultUIDs.length,
                      itemBuilder: (context, index) {
                        final uid = resultUIDs[index];
                        final hit = results[uid]!;
                        final alreadyAdded =
                            provider.discoveredDevices.containsKey(uid);

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              alreadyAdded
                                  ? Icons.check_circle
                                  : Icons.cell_tower,
                              color: alreadyAdded
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            title: Text(uid),
                            subtitle: Text(
                              '${hit.channelName}  •  RSSI: ${hit.rssi} dBm',
                            ),
                            trailing: alreadyAdded
                                ? const Text('Added',
                                    style: TextStyle(
                                        color: Colors.green, fontSize: 12))
                                : ElevatedButton(
                                    onPressed: () =>
                                        provider.adoptChannelScanHit(uid),
                                    child: const Text('Add'),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
