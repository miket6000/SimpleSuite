"""
Configuration module for GPS Tracker Log Analyzer.
Customize default settings here.
"""

# Default output directory
DEFAULT_OUTPUT_DIR = "output"

# Default quality filters (None = no filter)
DEFAULT_MIN_HDOP = None  # Lower is better (e.g., 2.0)
DEFAULT_MIN_RSSI = None  # Higher is better in dBm (e.g., -80)

# KML generation settings
KML_TRACK_WIDTH = 2  # Line width in KML
KML_INCLUDE_ALTITUDE = True  # Include 3D altitude extrusion
KML_COLOR_BY_RSSI = True  # Color lines by signal strength

# RSSI Color Thresholds
# Used to color the track from red (weak) to green (strong)
RSSI_EXCELLENT_THRESHOLD = -50  # dBm, signal is green
RSSI_GOOD_THRESHOLD = -70  # dBm, signal is yellow-green
RSSI_POOR_THRESHOLD = -90  # dBm, signal is yellow-red
RSSI_CRITICAL_THRESHOLD = -100  # dBm, signal is red

# GNGGA Sentence Validation
# Minimum fix quality to accept (0=no fix, 1=GPS, 2=DGPS, etc.)
MIN_FIX_QUALITY = 1

# Coordinate conversion precision
# Number of decimal places for coordinate conversion
COORDINATE_PRECISION = 8

# Log parsing
# Whether to skip lines with parsing errors
SKIP_INVALID_LINES = True

# Verbose output
DEFAULT_VERBOSE = False

# Icon URLs for KML (from Google Maps)
KML_START_MARKER = "http://maps.google.com/mapfiles/kml/paddle/grn-circle.png"
KML_END_MARKER = "http://maps.google.com/mapfiles/kml/paddle/red-circle.png"
