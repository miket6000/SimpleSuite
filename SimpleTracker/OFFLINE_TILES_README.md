# Offline Map Tile Caching

## Overview

The application now supports **offline map tile caching**, allowing previously downloaded map tiles to be used when the device is offline or has limited connectivity.

## How It Works

### Implementation Details

The caching system uses:
- **flutter_map_cache**: Provides intelligent tile caching via HTTP interceptors
- **http_cache_file_store**: Stores cached tiles in the device's temporary directory
- **Automatic cache management**: Tiles are cached with a 30-day expiration (configurable)

### Cache Location

Cached tiles are stored in:
- **Android**: `/data/data/com.example.gps_tracker/cache/flutter_map_tiles/` (app-specific cache)
- **Linux Desktop**: `~/.cache/gps_tracker/flutter_map_tiles/` (or system temp directory)

The cache uses the app's temporary directory (`getTemporaryDirectory()`), which:
- Can be cleared by the system if storage is low
- Is automatically managed by the OS
- Persists across app restarts until the OS cleans it

## User Experience

1. **First Visit**: When you view a map area, tiles are automatically downloaded and cached
2. **Offline Mode**: If you later visit the same area without internet, cached tiles display instantly
3. **Automatic Updates**: Cached tiles are refreshed if available online (within 30 days)

## Configuration

To adjust cache expiration time, edit `lib/widgets/live_map_widget.dart`:

```dart
return CachedTileProvider(
  store: store,
  maxStale: const Duration(days: 30),  // Change this value
);
```

Increase the duration for longer offline availability; decrease for fresher tiles.

## Cache Size Considerations

- Each map tile is typically **10-50 KB** (varies by layer/zoom)
- A typical region at zoom level 16 requires ~100-500 tiles
- Cache size grows as you explore new areas

The app uses the temporary cache directory, which:
- Android: Typically cleared when storage is needed
- Linux: System-managed temporary directory

## Supported Map Layers

All four map layers support offline caching:
- **OSM** (OpenStreetMap) - Free, community-maintained
- **Satellite** (ArcGIS World Imagery) - High-resolution satellite imagery
- **Dark** (CartoDB Dark) - Dark mode base map
- **Terrain** (ArcGIS Topo) - Topographic map with elevation

## Technical Notes

- Caching is **transparent**—no user action required
- The app falls back to `NetworkTileProvider` if cache initialization fails
- Cache headers respect tile server policies
- Tiles are only cached if the server allows it (Cache-Control headers)

## Benefits

✅ **Faster Performance**: Cached tiles load instantly  
✅ **Offline Capability**: View previously explored areas without internet  
✅ **Reduced Data Usage**: Tiles aren't re-downloaded on repeat visits  
✅ **Cost Savings**: Lower bandwidth consumption, especially for mobile users  
✅ **Better UX**: Smooth map experience even with slow/unreliable connections
