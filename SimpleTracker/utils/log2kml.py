import re
from xml.etree.ElementTree import Element, SubElement, ElementTree

def parse_lat_lon(lat_str, lat_dir, lon_str, lon_dir):
    """Convert NMEA lat/lon to decimal degrees."""
    try:
        lat_deg = int(lat_str[:2])
        lat_min = float(lat_str[2:])
        lat = lat_deg + lat_min / 60
        if lat_dir == 'S':
            lat = -lat

        lon_deg = int(lon_str[:3])
        lon_min = float(lon_str[3:])
        lon = lon_deg + lon_min / 60
        if lon_dir == 'W':
            lon = -lon

        return lat, lon
    except (ValueError, IndexError):
        return None, None

def is_valid_nmea_checksum(sentence):
    """Verify the checksum of an NMEA sentence."""
    match = re.match(r'^\$(.*)\*([0-9A-Fa-f]{2})$', sentence)
    if not match:
        return False
    data, checksum = match.groups()
    calc_checksum = 0
    for char in data:
        calc_checksum ^= ord(char)
    return f"{calc_checksum:02X}" == checksum.upper()

def convert_log_to_kml(input_path, output_path):
    with open(input_path, "r", encoding="latin1") as file:
        lines = file.readlines()

    # Create base KML structure
    kml = Element("kml", xmlns="http://www.opengis.net/kml/2.2")
    document = SubElement(kml, "Document")

    for line in lines:
        if line.startswith("<") and ("$GNGGA" in line or "$GPGGA" in line):
            parts = line.strip().split(" ", 1)
            if len(parts) != 2:
                continue
            tracker_id, gga = parts

            if not is_valid_nmea_checksum(gga):
                continue  # Skip invalid checksums

            fields = gga.split(",")
            if len(fields) < 6:
                continue

            lat_str = fields[2]
            lat_dir = fields[3]
            lon_str = fields[4]
            lon_dir = fields[5]

            lat, lon = parse_lat_lon(lat_str, lat_dir, lon_str, lon_dir)
            if lat is None or lon is None:
                continue

            # Create a Placemark
            placemark = SubElement(document, "Placemark")
            SubElement(placemark, "name").text = tracker_id.strip("< ")
            point = SubElement(placemark, "Point")
            SubElement(point, "coordinates").text = f"{lon},{lat},0"

    # Write KML to file
    ElementTree(kml).write(output_path, encoding="utf-8", xml_declaration=True)
    print(f"KML file created: {output_path}")

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Convert GPS log to KML with checksum validation")
    parser.add_argument("input", help="Path to input log file")
    parser.add_argument("output", help="Path to output KML file")

    args = parser.parse_args()
    convert_log_to_kml(args.input, args.output)

