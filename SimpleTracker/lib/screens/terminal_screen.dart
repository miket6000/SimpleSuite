import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tracker_provider.dart';
import '../widgets/serial_display.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  TerminalScreenState createState() => TerminalScreenState();
}

class TerminalScreenState extends State<TerminalScreen> {
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();
  
  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void _sendCommand(TrackerProvider provider, TextEditingController controller) {
    if (provider.isConnected) {
      try {
        provider.sendRawCommand("${controller.text}\n");
        controller.clear();
      } catch (e) {
        debugPrint("Error in _sendCommand(): $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final logFile = provider.logFilePath;

    // Ensure dropdown value is only used when present exactly once
    final ports = provider.availablePorts.toList();
    final uniquePorts = <String>[];
    final seen = <String>{};
    for (var p in ports) {
      if (seen.add(p)) uniquePorts.add(p);
    }
    final safeSelected = (provider.selectedPort != null && uniquePorts.contains(provider.selectedPort))
        ? provider.selectedPort
        : null;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: DropdownButton<String>(
                hint: const Text("Select Port"),
                value: safeSelected,
                isExpanded: true,
                items: uniquePorts
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (value) {
                  provider.selectPort(value);
                },
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: provider.isConnected
                  ? provider.disconnect
                  : provider.connect,
              child: Text(provider.isConnected ? "Disconnect" : "Connect"),
            )
          ]),
          SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onSubmitted: (_) {
                  Future.microtask(() {
                    _sendCommand(provider, controller);
                    if (!Platform.isAndroid && !Platform.isIOS) {
                      focusNode.requestFocus();
                    }                    
                  });
                },
                decoration: InputDecoration(hintText: "Type command"),
              ),
            ),
            SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _sendCommand(provider, controller),
              child: Text("Send"),
            )
          ]),
          SizedBox(height: 16),
          Expanded(
            child: SerialDisplay(logs: provider.logs), 
          ),
          SizedBox(height: 16),
          SelectableText((logFile != null) ? "See logfile at $logFile" : "Initializing log"),
        ],
      ),
    );
  }
}
