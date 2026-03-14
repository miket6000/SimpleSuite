# GPS Tracker Log Analyzer

A Python application for parsing serial logs from GPS tracking devices and generating KML visualizations compatible with Google Earth.

## Features

- **NMEA Sentence Validation**: Validates GNGGA sentences with checksum verification
- **Corruption Recovery**: Handles corrupted log data gracefully
- **Flexible Filtering**: Filter GPS points by HDOP and RSSI thresholds
- **KML Generation**: Creates 3D KML files viewable in Google Earth
- **RSSI-based Coloring**: Visual indication of signal strength (red = weak, green = strong)
- **Multiple Device Support**: Visualize tracks from multiple remote trackers simultaneously
- **Comparison Mode**: Compare remote and local tracker paths side-by-side

## Installation

### Prerequisites
- Python 3.8 or higher
- pip (Python package manager)

### Setup

1. Clone or download the project
2. Install dependencies:
```bash
pip install -r requirements.txt
```

## Usage

### Basic Usage

Parse a log file and generate KML:
```bash
python main.py serial_log.txt output.kml
```

### Advanced Usage

With filtering and verbose output:
```bash
python main.py serial_log.txt output.kml -v --min-hdop 2.0 --min-rssi -80
```

Compare remote and local tracker tracks:
```bash
python main.py remote_log.txt output.kml --comparison local_log.txt -v
```

Disable RSSI-based coloring:
```bash
python main.py serial_log.txt output.kml --no-color-rssi
```

### Command Line Options

```
positional arguments:
  log_file              Input serial log file
  output_file           Output KML file (default: output/<log_file_base>.kml)

optional arguments:
  -h, --help            Show help message and exit
  -v, --verbose         Enable verbose output
  --min-hdop HDOP       Minimum HDOP threshold (lower is better, default: no filter)
  --min-rssi RSSI       Minimum RSSI threshold in dBm (higher is better, default: no filter)
  --comparison FILE     Local tracker log file for comparison visualization
  --no-color-rssi       Disable RSSI-based coloring in KML
```

## Log File Format

The application expects serial log files with the following format:

```
> R
< f49ae83e $GNGGA,221453.000,3733.001470,S,17515.618888,E,2,28,0.52,22.729,M,24.306,M,,*5B -63
> L
< $GNGGA,221456.000,3733.005046,S,17515.621444,E,1,7,2.12,31.202,M,24.305,M,,*68
```

- `> R` - Remote GPS command (queries remote tracker)
- `> L` - Local GPS command (queries local tracker)
- `< response` - Device response

### Remote Response Format
```
UID GNGGA_SENTENCE RSSI
f49ae83e $GNGGA,221453.000,3733.001470,S,17515.618888,E,2,28,0.52,22.729,M,24.306,M,,*5B -63
```

- **UID**: 8-character hex device identifier
- **GNGGA Sentence**: Standard NMEA format GPS data with checksum
- **RSSI**: Signal strength in dBm (negative value)

## GNGGA Sentence Structure

The GNGGA (Global Navigation Satellite System) sentence format:

```
$GNGGA,time,lat,lat_dir,lon,lon_dir,fix,sats,hdop,altitude,alt_unit,geoid,geoid_unit,,checksum*
```

- **Message ID**: `$GNGGA`
- **UTC Time**: `HHMMSS.sss` format
- **Latitude**: `DDMM.MMMM` (degrees and minutes)
- **Latitude Direction**: `N` (North) or `S` (South)
- **Longitude**: `DDDMM.MMMM` (degrees and minutes)
- **Longitude Direction**: `E` (East) or `W` (West)
- **Fix Quality**: 0=No Fix, 1=GPS Fix, 2=DGPS Fix, etc.
- **Number of Satellites**: Count of satellites used
- **HDOP**: Horizontal Dilution of Precision (lower is better, < 2.0 is good)
- **Altitude**: Height above sea level in meters
- **Altitude Unit**: `M` (meters)
- **Geoid Height**: Height of geoid above WGS84 ellipsoid
- **Checksum**: XOR of all characters between `$` and `*`

## Data Quality Filtering

### HDOP (Horizontal Dilution of Precision)
- < 1.0: Excellent
- 1.0 - 2.0: Good
- 2.0 - 5.0: Moderate
- 5.0 - 10.0: Fair
- > 10.0: Poor

### RSSI (Received Signal Strength Indicator)
- -30 dBm to -50 dBm: Excellent
- -50 dBm to -70 dBm: Good
- -70 dBm to -90 dBm: Fair
- -90 dBm to -120 dBm: Poor

Example filtering by quality:
```bash
# High quality GPS fixes only
python main.py log.txt output.kml --min-hdop 2.0 --min-rssi -80
```

## Output

The application generates KML files that can be opened in:
- **Google Earth** (Desktop application - free)
- **Google Earth Pro** (Commercial version)
- **Google Maps** (Limited KML support)
- Any KML-compatible mapping application

### KML Features

- **3D Altitude Visualization**: Tracks are displayed with altitude extrusion
- **Color Coding**: 
  - Remote tracks: Colored by RSSI strength (red to green)
  - Local track: Cyan/blue
- **Markers**:
  - Green circle: Track start point
  - Red circle: Track end point
- **Folders**: Organized by device UID for easy navigation

## Project Structure

```
SimpleTrackerLogAnalyzer/
├── main.py                          # CLI entry point
├── requirements.txt                 # Python dependencies
├── README.md                        # This file
├── modules/
│   ├── __init__.py
│   ├── nmea_validator.py           # GNGGA parsing and validation
│   ├── coordinate_converter.py      # NMEA to decimal degree conversion
│   ├── log_parser.py               # Serial log file parser
│   ├── data_processor.py           # Data filtering and processing
│   └── kml_generator.py            # KML file generation
├── tests/
│   ├── __init__.py
│   ├── test_nmea_validator.py      # NMEA validation tests
│   └── test_coordinate_converter.py # Coordinate conversion tests
└── output/                          # Generated KML files (auto-created)
```

## Module Documentation

### nmea_validator.py
Validates NMEA sentences and handles data corruption:
- Checksum validation using XOR algorithm
- GNGGA sentence parsing with field extraction
- Corruption recovery for malformed sentences
- UID, GNGGA, and RSSI extraction from remote responses

### coordinate_converter.py
Converts NMEA format coordinates to decimal degrees:
- NMEA to decimal degree conversion for latitude/longitude
- Support for hemisphere indicators (N/S, E/W)
- UTC time to seconds since midnight conversion

### log_parser.py
Parses serial log files:
- Reads and extracts remote (R) and local (L) responses
- Matches command-response pairs
- Handles malformed lines gracefully

### data_processor.py
Processes and filters GPS data:
- Converts parsed data to Pandas DataFrames
- Applies HDOP and RSSI filtering
- Provides track statistics (min/max altitude, etc.)
- Supports per-device data extraction

### kml_generator.py
Generates KML files:
- Creates LineString tracks with altitude
- Supports RSSI-based color gradients
- Adds start/end markers
- Generates comparison KML files

## Testing

Run the test suite:
```bash
python -m pytest tests/ -v
```

Or run individual test modules:
```bash
python -m unittest tests.test_nmea_validator -v
python -m unittest tests.test_coordinate_converter -v
```

## Troubleshooting

### "No remote data to visualize"
- Check that your log file contains `> R` commands with responses
- Verify the GNGGA sentences have valid checksums
- Use `-v` flag to see which responses were rejected

### Corrupted data causing parsing failures
- The parser is designed to handle corruption gracefully
- Invalid sentences are skipped with warnings in verbose mode
- Use `--min-hdop` and `--min-rssi` to filter low-quality data

### KML file won't open in Google Earth
- Ensure the KML file is valid (should be saved if no errors)
- Try opening with a text editor to check for corruption
- Check that the output path exists and is writable

## Performance

The application is optimized for log files with thousands of GPS points:
- Linear parsing time: O(n) where n = number of log lines
- Memory efficient: Uses streaming parsing where possible
- Typical processing: ~1-5 seconds for 100,000 log entries

## Dependencies

- **simplekml** (1.3.6): KML file generation
- **pynmea2** (1.20.0): NMEA sentence parsing utilities
- **pandas** (2.0.3): Data processing and filtering
- **numpy** (1.24.3): Numerical operations

## Known Limitations

1. Only GNGGA sentences are supported (not other NMEA sentence types)
2. Comparison mode requires both remote and local log files
3. KML coloring is based on mean RSSI per track
4. No real-time processing (batch processing only)

## Future Enhancements

- Support for other NMEA sentence types (RMC, GSA, etc.)
- Web-based visualization using Folium/Leaflet
- Speed and acceleration analysis
- Interactive HTML output
- Filtering by time range
- Track smoothing using Kalman filters
- GeoJSON output format

## License

This project is provided as-is for GPS tracking analysis purposes.

## Support

For issues, questions, or feature requests, please check the verbose output:
```bash
python main.py -v log.txt output.kml
```

This will provide detailed information about parsing progress and any issues encountered.
