import 'package:flutter/material.dart';
import 'status_indicator.dart';

class StatusBar extends StatelessWidget {
  final bool isGpsFix;
  final bool isTrackerOnline;
  final bool isLocalGPSFix;
  final bool isConnected;

  const StatusBar({
    super.key, 
    required this.isGpsFix, 
    required this.isTrackerOnline,
    required this.isLocalGPSFix,
    required this.isConnected
  });


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8.0),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          StatusIndicator(
            value: isGpsFix,
            activeText: "Tracker GPS Fix",
            inactiveText: "No Tracker GPS Fix",
          ),
          SizedBox(width:10),
          StatusIndicator(
            value: isTrackerOnline,
            activeText: "Tracker Online",
            inactiveText: "No Tracker",
          ),
          SizedBox(width:10),
          StatusIndicator(
            value: isLocalGPSFix,
            activeText: "Local GPS Fix",
            inactiveText: "No Local GPS Fix",
          ),
          SizedBox(width:10),
          StatusIndicator(
            value: isConnected,
            activeText: "GS Connected",
            inactiveText: "No GS Connection",
          ),
        ],
      ),
    );
  }
}