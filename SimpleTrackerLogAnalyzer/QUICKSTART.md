# Quick Start Guide

## Installation (First Time Only)

### 1. Create and activate virtual environment
```bash
cd /home/mike/Projects/SimpleSuite/SimpleTrackerLogAnalyzer
python3 -m venv venv
source venv/bin/activate
```

### 2. Install dependencies
```bash
pip install -r requirements.txt
```

## Basic Usage

### Generate KML from log file
```bash
python main.py /path/to/serial_log.txt output.kml
```

### Examples

**Simple processing:**
```bash
python main.py ~/Documents/serial_log_2026-03-08_11-14-23.txt output/my_track.kml
```

**With quality filtering (only good GPS fixes):**
```bash
python main.py ~/Documents/serial_log_2026-03-08_11-14-23.txt output/my_track.kml \
  --min-hdop 2.0 --min-rssi -80
```

**Verbose output to see what's happening:**
```bash
python main.py ~/Documents/serial_log_2026-03-08_11-14-23.txt output/my_track.kml -v
```

**Compare remote and local tracker tracks:**
```bash
python main.py remote_log.txt output/comparison.kml --comparison local_log.txt -v
```

## Opening the KML File

### Google Earth (Recommended)
1. Download Google Earth from https://www.google.com/earth/
2. Open the .kml file directly with Google Earth
3. The track will display in 3D with altitude visualization

### Google Maps
1. Go to https://maps.google.com
2. Click the menu (☰) > "Your Places"
3. Click "Create Map"
4. Click "Import" and select the .kml file

## Understanding the Output

The generated KML file contains:
- **Track Line**: 3D path of the remote tracker colored by signal strength
  - Red = Weak signal (RSSI < -85 dBm)
  - Yellow = Fair signal (-85 to -70 dBm)
  - Green = Strong signal (RSSI > -70 dBm)
- **Start Marker**: Green circle (beginning of track)
- **End Marker**: Red circle (end of track)
- **Altitude**: Automatically displayed in Google Earth

## Troubleshooting

### "No remote data to visualize"
- Check your log file has `> R` commands
- Use `-v` flag to see detailed parsing information
- Some lines may be corrupted, try with different HDOP/RSSI filters

### "Log file not found"
- Use absolute paths: `/home/mike/Documents/log.txt`
- Or relative paths from current directory

### KML file is very small or empty
- Use `-v` flag to see if responses are being rejected
- Check that timestamps and fix quality are valid
- Try removing HDOP/RSSI filters to accept all data

## Testing

Run the unit tests to verify everything is working:
```bash
python -m unittest discover tests/ -v
```

All tests should pass with `OK` status.

## Command Reference

```
usage: main.py [-h] [-v] [--min-hdop HDOP] [--min-rssi RSSI] 
               [--comparison FILE] [--no-color-rssi]
               log_file [output_file]

positional arguments:
  log_file              Input serial log file (required)
  output_file           Output KML file (optional, default: output/<log_name>.kml)

optional arguments:
  -h, --help            Show help message and exit
  -v, --verbose         Print detailed progress information
  --min-hdop HDOP       Filter by minimum HDOP (lower is better, e.g., 2.0)
  --min-rssi RSSI       Filter by minimum RSSI in dBm (higher is better, e.g., -80)
  --comparison FILE     Include local tracker data for comparison
  --no-color-rssi       Disable RSSI-based coloring (use solid blue)
```

## File Locations

- **Source code**: `/home/mike/Projects/SimpleSuite/SimpleTrackerLogAnalyzer/modules/`
- **Tests**: `/home/mike/Projects/SimpleSuite/SimpleTrackerLogAnalyzer/tests/`
- **Output**: `/home/mike/Projects/SimpleSuite/SimpleTrackerLogAnalyzer/output/`
- **Log files**: `/home/mike/Documents/`

## Next Steps

- Explore the generated KML files in Google Earth
- Experiment with different filtering options
- Check README.md for detailed technical documentation
- Examine test files to understand data format expectations

## For Developers

To activate the virtual environment in a new terminal:
```bash
cd /home/mike/Projects/SimpleSuite/SimpleTrackerLogAnalyzer
source venv/bin/activate
```

To deactivate:
```bash
deactivate
```
