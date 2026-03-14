import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/serial_provider.dart';
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

  void _sendCommand(SerialProvider serial, TextEditingController controller) {
    if (serial.isConnected) {
      final polling = serial.isPolling;
      try {
        if(polling) {
          serial.stopPolling();
        }
        serial.sendQueuedCommand("${controller.text}\n");
        controller.clear();
      } catch (e) {
        debugPrint("SerialPortError in _sendCommand(): $e");
      } finally {
        if(polling) {
          serial.startPolling();
        }
      }  
    }
  }

  @override
  Widget build(BuildContext context) {
    final serial = Provider.of<SerialProvider>(context);
    final logFile = serial.logFilePath;

    // Ensure dropdown value is only used when present exactly once
    final ports = serial.availablePorts.toList();
    final uniquePorts = <String>[];
    final seen = <String>{};
    for (var p in ports) {
      if (seen.add(p)) uniquePorts.add(p);
    }
    final safeSelected = (serial.selectedPort != null && uniquePorts.contains(serial.selectedPort))
        ? serial.selectedPort
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
                  serial.selectPort(value);
                },
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: serial.isConnected
                  ? serial.disconnect
                  : serial.connect,
              child: Text(serial.isConnected ? "Disconnect" : "Connect"),
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
                    _sendCommand(serial, controller);
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
              onPressed: () => _sendCommand(serial, controller),
              child: Text("Send"),
            )
          ]),
          SizedBox(height: 16),
          Expanded(
            child: SerialDisplay(logs: serial.logs), 
          ),
          SizedBox(height: 16),
          SelectableText((logFile != null) ? "See logfile at $logFile" : "Initializing log"),
        ],
      ),
    );
  }
}
