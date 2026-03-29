import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import 'map/bearing_overlay.dart';
import 'map/map_center_buttons.dart';
import 'map/map_layer_selector.dart';
import 'map/map_marker.dart';
import 'map/info_overlay.dart';

enum MapLayer {
  satellite('Satellite', 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'),
  openStreetMap('OSM', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
  terrain('Terrain', 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}');

  final String label;
  final String urlTemplate;

  const MapLayer(this.label, this.urlTemplate);
}

class LiveMapWidget extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final double? trackerAltitude;
  final String? trackerLabel;
  final double? localLatitude;
  final double? localLongitude;
  final double? localAltitude;
  final String? localLabel;
  final int? trackerRssi;
  final double? trackerVerticalVelocity;

  const LiveMapWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    this.trackerAltitude,
    this.trackerLabel,
    this.localLatitude,
    this.localLongitude,
    this.localAltitude,
    this.localLabel,
    this.trackerRssi,
    this.trackerVerticalVelocity,
  });

  @override
  State<LiveMapWidget> createState() => _LiveMapWidgetState();
}

class _LiveMapWidgetState extends State<LiveMapWidget> {
  late final MapController _mapController;
  MapLayer _selectedLayer = MapLayer.openStreetMap;
  late Future<CachedTileProvider> _tileProviderFuture;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Initialize the file-based cache store for offline tile support
    _tileProviderFuture = _initializeTileProvider();
  }

  Future<CachedTileProvider> _initializeTileProvider() async {
    final cacheDir = await getTemporaryDirectory();
    final store = FileCacheStore('${cacheDir.path}/flutter_map_tiles');
    return CachedTileProvider(
      store: store,
      maxStale: const Duration(days: 30),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRemote = widget.latitude != null && widget.longitude != null;
    final hasLocal =
        widget.localLatitude != null && widget.localLongitude != null;

    if (!hasRemote && !hasLocal) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('No position available'),
        ),
      );
    }

    // Determine map center: prefer local position, fall back to remote
    final LatLng mapCenter;
    if (hasLocal) {
      mapCenter = LatLng(widget.localLatitude!, widget.localLongitude!);
    } else {
      mapCenter = LatLng(widget.latitude!, widget.longitude!);
    }

    // Build markers — ground station first (behind), remote tracker last (on top)
    final List<Marker> markers = [
      if (hasLocal)
        MapMarker.build(
          point: LatLng(widget.localLatitude!, widget.localLongitude!),
          color: Colors.blue,
          label: widget.localLabel,
        ),
      if (hasRemote)
        MapMarker.build(
          point: LatLng(widget.latitude!, widget.longitude!),
          color: Colors.red,
          label: widget.trackerLabel,
        ),
    ];

    final LatLng? remotePosition =
        hasRemote ? LatLng(widget.latitude!, widget.longitude!) : null;
    final LatLng? localPosition =
        hasLocal ? LatLng(widget.localLatitude!, widget.localLongitude!) : null;

    return FutureBuilder<CachedTileProvider>(
      future: _tileProviderFuture,
      builder: (context, snapshot) {
        final tileProvider = snapshot.data;

        // Format vertical velocity
        String vsValue;
        if (widget.trackerVerticalVelocity != null) {
          final v = widget.trackerVerticalVelocity!;
          final sign = v > 0 ? '+' : (v < 0 ? '−' : '');
          vsValue = '$sign${v.abs().toStringAsFixed(1)} m/s';
        } else {
          vsValue = '—';
        }

        // Format RSSI
        String rssiValue = widget.trackerRssi != null ? '${widget.trackerRssi} dBm' : '—';

        return SizedBox.expand(
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                clipBehavior: Clip.antiAlias,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 16,
                    minZoom: 1,
                    maxZoom: 19,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      enableMultiFingerGestureRace: false,
                    ),
                    onPositionChanged:
                        (MapPosition position, bool hasGesture) {},
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _selectedLayer.urlTemplate,
                      userAgentPackageName: 'com.example.gps_tracker',
                      maxNativeZoom: 18,
                      subdomains: const ['a', 'b', 'c'],
                      tileProvider: tileProvider ?? NetworkTileProvider(),
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),
              ),
              MapLayerSelector(
                selectedLayer: _selectedLayer,
                onSelected: (layer) => setState(() => _selectedLayer = layer),
              ),
              MapCenterButtons(
                remotePosition: remotePosition,
                localPosition: localPosition,
                mapController: _mapController,
              ),
              if (hasRemote && hasLocal)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BearingOverlay(
                        localLatitude: widget.localLatitude,
                        localLongitude: widget.localLongitude,
                        remoteLatitude: widget.latitude,
                        remoteLongitude: widget.longitude,
                        localAltitude: widget.localAltitude,
                        remoteAltitude: widget.trackerAltitude,
                      ),
                      if (hasRemote) ...[
                        const SizedBox(height: 8),
                        InfoOverlay(
                          label: 'V/S:',
                          value: vsValue,
                        ),
                        const SizedBox(height: 8),
                        InfoOverlay(
                          label: 'RSSI:',
                          value: rssiValue,
                        ),
                        const SizedBox(height: 8),
                        // Altitude delta overlay
                        InfoOverlay(
                          label: 'Alt:',
                          value: () {
                            if (widget.trackerAltitude != null && widget.localAltitude != null) {
                              final diff = widget.trackerAltitude! - widget.localAltitude!;
                              final sign = diff > 0 ? '+' : (diff < 0 ? '−' : '');
                              return '$sign${diff.abs().toStringAsFixed(1)} m';
                            } else {
                              return '—';
                            }
                          }(),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
