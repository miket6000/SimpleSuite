import '../providers/serial_provider.dart';
import '../settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/setting_row.dart';
import '../channels.dart';

final GlobalKey<SettingPageState> settingPageKey =
    GlobalKey<SettingPageState>();

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});
  @override
  State<SettingPage> createState() => SettingPageState();
}

class SettingPageState extends State<SettingPage> {
  int? selectedChannelIndex;
  bool _isUploading = false;

  // Upload all current settings to the device
  Future<void> updateSettings() async {
    final serial = Provider.of<SerialProvider>(context, listen: false);
    var polling = false;
    if (serial.isPolling) {
      polling = true;
      serial.stopPolling();
    }
    // capture messenger & avoid using context after awaits without mounted check
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isUploading = true);

    try {
      for (final entry in defaultSettings.entries) {
        if (entry.value.modified) {
          try {
            final cmd = entry.value.serialize(); // should produce "SET X Y\n"
            final resp =
                await serial.sendQueuedCommand(cmd, expectResponse: true);
            if (resp.trim() != 'OK') {
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                    content:
                        Text('Device rejected ${entry.key}: "${resp.trim()}"')),
              );
              // stop upload on error (or continue if you prefer)
              break;
            }
          } catch (e) {
            if (!mounted) return;
            messenger.showSnackBar(
              SnackBar(content: Text('Failed to send ${entry.key}: $e')),
            );
            // stop or continue depending on desired behavior
            break;
          }
        }
      }

      if (!mounted) return;
      messenger
          .showSnackBar(const SnackBar(content: Text('Settings uploaded')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
      if (polling) serial.startPolling();
    }
  }

  void factoryReset() {
    final serial = Provider.of<SerialProvider>(context, listen: false);
    if (serial.isConnected) {
      serial.sendQueuedCommand("FACTORY\n");
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settingRows = defaultSettings.entries
        .map((entry) => SettingRow(
              setting: entry.value,
              onChanged: (newVal) {
                entry.value.initialValue ??= entry.value.value;
                setState(() {
                  if (newVal != null) entry.value.value = newVal;
                });
              },
            ))
        .toList();

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              DropdownButton<int>(
                value: selectedChannelIndex,
                hint: const Text("Select Channel"),
                items: channels.map((channel) {
                  return DropdownMenuItem<int>(
                    value: channel.number,
                    child: Text(channel.name),
                  );
                }).toList(),
                onChanged: (index) {
                  final channel = channels.firstWhere((c) => c.number == index);
                  setState(() {
                    selectedChannelIndex = index;
                    applyChannelPreset(channel);
                  });
                },
              ),
              ...settingRows,
              Flex(
                direction: Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: factoryReset,
                    child: const Text("Factory Reset"),
                  ),
                  ElevatedButton(
                    onPressed: _isUploading ? null : () => updateSettings(),
                    child: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text("Upload Settings"),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
