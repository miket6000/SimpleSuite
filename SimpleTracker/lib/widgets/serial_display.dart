import 'package:flutter/material.dart';

class SerialDisplay extends StatefulWidget {
  final List<String> logs;
  final bool alwaysScroll;

  const SerialDisplay({
    super.key,
    required this.logs,
    this.alwaysScroll = true,
  });

  @override
  State<SerialDisplay> createState() => _SerialDisplayState();
}

class _SerialDisplayState extends State<SerialDisplay> {
  final ScrollController _scrollController = ScrollController();
  List<String> _previousLogs = [];

  @override
  void didUpdateWidget(covariant SerialDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if logs list changed (by length or contents)
    if (widget.logs.length != _previousLogs.length ||
        !_listEquals(widget.logs, _previousLogs)) {
      final shouldScroll = _isUserAtBottom() ||  widget.alwaysScroll;
      _previousLogs = List.from(widget.logs);

      if (shouldScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }
  }

  bool _isUserAtBottom() {
    if (!_scrollController.hasClients) return false;
    const threshold = 100.0;
    return _scrollController.offset >=
        _scrollController.position.maxScrollExtent - threshold;
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    if (animate) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16.0),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: widget.logs.length,
        itemBuilder: (context, index) {
          return Text(
            widget.logs[index],
            style: const TextStyle(color: Colors.white70),
          );
        },
      ),
    );
  }

  /// Utility: compare two lists of strings
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
