import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

enum MapLayer {
  openStreetMap('OSM', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
  satellite('Satellite', 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'),
  dark('Dark', 'https://cartodb-basemaps-{s}.a.ssl.fastly.net/dark_all/{z}/{x}/{y}.png'),
  terrain('Terrain', 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}');

  final String label;
  final String urlTemplate;

  const MapLayer(this.label, this.urlTemplate);
}

class LiveMapWidget extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String? trackerLabel;
  final double? localLatitude;
  final double? localLongitude;
  final String? localLabel;

  const LiveMapWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    this.trackerLabel,
    this.localLatitude,
    this.localLongitude,
    this.localLabel,
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
    if (widget.latitude == null || widget.longitude == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('No tracker position available'),
        ),
      );
    }

    final remoteCenter = LatLng(widget.latitude!, widget.longitude!);
    
    // Determine map center: use local position if available, otherwise use remote position
    final LatLng mapCenter;
    if (widget.localLatitude != null && widget.localLongitude != null) {
      mapCenter = LatLng(widget.localLatitude!, widget.localLongitude!);
    } else {
      mapCenter = remoteCenter;
    }

    // Build list of markers
    final List<Marker> markers = [];
    
    // Remote tracker marker (red location pin)
    markers.add(
      Marker(
        point: remoteCenter,
        width: 120,
        height: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_on,
              color: Colors.red,
              size: 40,
            ),
            if (widget.trackerLabel != null && widget.trackerLabel!.isNotEmpty)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    widget.trackerLabel!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    
    // Local ground station marker (blue location pin)
    if (widget.localLatitude != null && widget.localLongitude != null) {
      markers.add(
        Marker(
          point: LatLng(widget.localLatitude!, widget.localLongitude!),
          width: 120,
          height: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_on,
                color: Colors.blue,
                size: 40,
              ),
              if (widget.localLabel != null && widget.localLabel!.isNotEmpty)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      widget.localLabel!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<CachedTileProvider>(
      future: _tileProviderFuture,
      builder: (context, snapshot) {
        final tileProvider = snapshot.data;

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
                      flags: InteractiveFlag.all,
                      enableMultiFingerGestureRace: false,
                    ),
                    onPositionChanged: (MapPosition position, bool hasGesture) {},
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _selectedLayer.urlTemplate,
                      userAgentPackageName: 'com.example.gps_tracker',
                      maxNativeZoom: 18,
                      subdomains: const ['a', 'b', 'c'],
                      tileProvider: tileProvider ?? NetworkTileProvider(),
                    ),
                    MarkerLayer(
                      markers: markers,
                    ),
                  ],
                ),
              ),
              // Layer selector button (top-right)
              Positioned(
                top: 8,
                right: 8,
                child: PopupMenuButton<MapLayer>(
                  initialValue: _selectedLayer,
                  onSelected: (layer) {
                    setState(() => _selectedLayer = layer);
                  },
                  itemBuilder: (context) => MapLayer.values
                      .map((layer) => PopupMenuItem(
                        value: layer,
                        child: Text(layer.label),
                      ))
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                        const Icon(Icons.layers, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          _selectedLayer.label,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Center on tracker button (bottom-left)
              Positioned(
                bottom: 16,
                left: 16,
                child: FloatingActionButton.small(
                  onPressed: () {
                    _mapController.move(remoteCenter, _mapController.camera.zoom);
                  },
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                ),
              ),
              // Center on ground station button (bottom-center)
              if (widget.localLatitude != null && widget.localLongitude != null)
                Positioned(
                  bottom: 16,
                  left: 80,
                  child: FloatingActionButton.small(
                    onPressed: () {
                      final localCenter = LatLng(widget.localLatitude!, widget.localLongitude!);
                      _mapController.move(localCenter, _mapController.camera.zoom);
                    },
                    backgroundColor: Colors.blue,
                    child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
