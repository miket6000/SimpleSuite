import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'serial_parser.dart';
import 'serial_wrapper.dart';

class SerialConnectionWidget extends StatefulWidget {
  final String title;
  final SerialMessage sharedMessage;
  final void Function() onMessageReceived;
  final ValueChanged<bool> onConnectionChange;

  const SerialConnectionWidget({
    super.key,
    required this.title,
    required this.sharedMessage,
    required this.onMessageReceived,
    required this.onConnectionChange,
  });

  @override
  SerialConnectionWidgetState createState() => SerialConnectionWidgetState();
}

class SerialConnectionWidgetState extends State<SerialConnectionWidget> {
  List<String> availablePorts = SerialPortWrapper.availablePorts;
  String? selectedPort;
  String uid = "";
  SerialPortWrapper? serial;
  List<String> receivedDataList = [];
  RandomAccessFile? logFile;
  bool isConnected = false;
  Timer? communicationTimer;
  bool isCommunicating = false;
  Timer? pollingTimer;

  void startPolling(SerialPortWrapper serial) {
    pollingTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      try {
        String response = await serial.sendCommand("L\n");
        widget.sharedMessage.parse(response, widget.title);
        setState((){
          receivedDataList.add(response);
          widget.onMessageReceived();
          isCommunicating = true;
          widget.onConnectionChange(isCommunicating);
        });

        logFile?.writeStringSync("$response\n");
        logFile?.flushSync();
        
        communicationTimer?.cancel();
        communicationTimer = Timer(Duration(seconds: 6), () {
          setState(() {
            isCommunicating = false;
            widget.onConnectionChange(isCommunicating);
          });
        });
      } catch (e) {
        debugPrint("Error: $e");
        //stopPolling(); // Stop polling if there's an issue
      }
    });
  }

  void stopPolling() {
    pollingTimer?.cancel();
  }

  void connect() async {
    if (selectedPort == null) return;
    
    serial = SerialPortWrapper(selectedPort!);

    String logFileName =
        "${widget.title}_serial_${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}.log";
    logFile = File(logFileName).openSync(mode: FileMode.write);
  
    if (serial != null && serial!.open()){
      uid = await serial!.sendCommand("UID\n");
      debugPrint(uid);
      startPolling(serial!);
    }
  }

  void disconnect() {
    stopPolling();
    serial?.close();
    logFile?.closeSync();
    logFile = null;
  }

  void toggleConnection() {
    if (selectedPort == null) return;
    setState(() {
      if (!isConnected) {
        connect();
        isConnected = true;
      } else {
        disconnect();
        isConnected = false;
      }
      widget.onConnectionChange(isConnected);
    });
  }

  @override
  void dispose() {
    communicationTimer?.cancel();
    disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(widget.title),
      Row(
        children: [
          DropdownButton<String>(
            hint: Text("Select a Port"),
            value: selectedPort,
            onChanged: (String? newValue) {
              setState(() {
                selectedPort = newValue;
              });
            },
            onTap: () {
              setState(() {
                availablePorts = SerialPortWrapper.availablePorts;
              });
            },
            items: availablePorts.map((String port) {
              return DropdownMenuItem<String>(
                value: port,
                child: Text(port),
              );
            }).toList(),
          ),
          SizedBox(width: 9),
          ElevatedButton(
            style: ButtonStyle(
              fixedSize: WidgetStateProperty.all(
                  Size.fromWidth(180)), // Width: 200, Height: 50
            ),
            onPressed: toggleConnection,
            child: Text(isConnected ? "Disconnect" : "Connect"),
          ),
        ],
      )
    ]);
  }
}
