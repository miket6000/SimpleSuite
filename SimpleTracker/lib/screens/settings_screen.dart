import '../providers/tracker_provider.dart';
import '../services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/setting_row.dart';

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

  Future<void> updateSettings() async {
    final provider = Provider.of<TrackerProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isUploading = true);

    try {
      final ok = await provider.uploadSettings();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(ok ? 'Settings uploaded' : 'Some settings failed')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void factoryReset() {
    final provider = Provider.of<TrackerProvider>(context, listen: false);
    if (provider.isConnected) {
      provider.factoryReset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final deviceSettings = provider.settings;

    final settingRows = deviceSettings.entries
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
                items: channelPresets.map((channel) {
                  return DropdownMenuItem<int>(
                    value: channel.number,
                    child: Text(channel.name),
                  );
                }).toList(),
                onChanged: (index) {
                  final channel = channelPresets.firstWhere((c) => c.number == index);
                  setState(() {
                    selectedChannelIndex = index;
                    provider.applyChannelPreset(channel);
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
