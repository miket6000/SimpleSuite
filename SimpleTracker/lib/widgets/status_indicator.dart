import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
  final bool value;
  final String activeText;
  final String inactiveText;

  const StatusIndicator({
    super.key,
    required this.value,
    required this.activeText,
    required this.inactiveText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? Colors.green : Colors.red,
          ),
        ),
        SizedBox(width: 8),
        Text(
          value ? activeText : inactiveText,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}