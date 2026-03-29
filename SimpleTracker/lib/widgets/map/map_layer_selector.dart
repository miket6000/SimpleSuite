import 'package:flutter/material.dart';

import '../live_map_widget.dart';

/// Popup menu button for selecting the active map tile layer.
class MapLayerSelector extends StatelessWidget {
  final MapLayer selectedLayer;
  final ValueChanged<MapLayer> onSelected;

  const MapLayerSelector({
    super.key,
    required this.selectedLayer,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned(
      top: 8,
      right: 8,
      child: PopupMenuButton<MapLayer>(
        initialValue: selectedLayer,
        onSelected: onSelected,
        itemBuilder: (context) => MapLayer.values
            .map((layer) => PopupMenuItem(
                  value: layer,
                  child: Text(layer.label),
                ))
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.layers, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 4),
              Text(
                selectedLayer.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
