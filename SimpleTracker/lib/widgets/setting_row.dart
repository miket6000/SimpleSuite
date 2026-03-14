import 'package:flutter/material.dart';
import '../settings.dart';

class SettingRow extends StatefulWidget {
  final Setting setting;
  final void Function(int?) onChanged;

  const SettingRow({
    super.key,
    required this.setting,
    required this.onChanged,
  });

  @override
  State<SettingRow> createState() => _SettingRowState();
}

class _SettingRowState extends State<SettingRow> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.setting.value.toString());
  }

  @override
  void didUpdateWidget(covariant SettingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the underlying model value changed (from outside), update controller text
    final newText = widget.setting.value.toString();
    if (_controller.text != newText) {
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(offset: newText.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Shared input decoration style
    const inputDecoration = InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );

    Widget inputWidget;

    if (widget.setting.options != null) {
      // Dropdown for settings with options
      inputWidget = SizedBox(
        height: 48,
        child: InputDecorator(
          decoration: inputDecoration,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              isDense: true,
              value: widget.setting.value,
              onChanged: widget.setting.configurable ? widget.onChanged : null,
              items: widget.setting.options!.entries.map((entry) {
                return DropdownMenuItem<int>(
                  value: entry.value,
                  child: Text(entry.key),
                );
              }).toList(),
            ),
          ),
        ),
      );
    } else {
      // TextField for manual input — persist controller and call onChanged when parse succeeds
      inputWidget = SizedBox(
        height: 48,
        child: TextField(
          enabled: widget.setting.configurable,
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(),
          decoration: inputDecoration,
          onChanged: (text) {
            try {
              final parsed = int.parse(text);
              widget.onChanged(parsed);
            } catch (_) {
              // ignore partial/invalid input until valid integer entered
            }
          },
          onSubmitted: (text) {
            try {
              final parsed = int.parse(text);
              widget.onChanged(parsed);
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Invalid value for ${widget.setting.title}')),
              );
              // restore controller to model value
              final restore = widget.setting.value.toString();
              _controller.text = restore;
              _controller.selection = TextSelection.collapsed(offset: restore.length);
            }
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Setting Title
          Expanded(
            flex: 3,
            child: Text(
              widget.setting.title,
              style: const TextStyle(fontSize: 16),
            ),
          ),

          // Input Field (Dropdown or TextField)
          Expanded(flex: 4, child: inputWidget),

          // Tooltip Icon
          Tooltip(
            message: widget.setting.hint,
            waitDuration: const Duration(milliseconds: 500),
            child: const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(Icons.info_outline, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}