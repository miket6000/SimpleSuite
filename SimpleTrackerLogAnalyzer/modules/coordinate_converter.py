"""
Coordinate conversion module.
Converts NMEA format coordinates to decimal degrees.
"""

from typing import Optional


class CoordinateConverter:
    """Converts NMEA format coordinates to decimal degrees."""
    
    @staticmethod
    def nmea_to_decimal(value: str, direction: str) -> Optional[float]:
        """
        Convert NMEA format coordinate to decimal degrees.
        
        NMEA format: DDMM.MMMM (for latitude) or DDDMM.MMMM (for longitude)
        Example latitude: "3733.001470" + "S" = -37.5500245
        Example longitude: "17515.618888" + "E" = 175.2603147
        
        Args:
            value: Coordinate string in NMEA format
            direction: Direction indicator (N/S for latitude, E/W for longitude)
            
        Returns:
            Decimal degree coordinate or None if invalid
        """
        try:
            if not value or not direction:
                return None
            
            # Determine if latitude or longitude based on direction
            is_latitude = direction in ['N', 'S']
            is_longitude = direction in ['E', 'W']
            
            if not (is_latitude or is_longitude):
                return None
            
            # Determine the split point
            # Latitude: DDMM.MMMM (2 digit degrees)
            # Longitude: DDDMM.MMMM (3 digit degrees)
            if is_latitude:
                deg_length = 2
            else:  # longitude
                deg_length = 3
            
            # Extract degrees and minutes
            degrees = float(value[:deg_length])
            minutes = float(value[deg_length:])
            
            # Convert to decimal
            decimal = degrees + (minutes / 60.0)
            
            # Apply direction
            if direction in ['S', 'W']:
                decimal = -decimal
            
            return decimal
        except (ValueError, IndexError):
            return None
    
    @staticmethod
    def time_string_to_seconds(time_str: str) -> Optional[float]:
        """
        Convert NMEA time string to seconds since midnight.
        
        NMEA format: HHMMSS.sss
        Example: "221451.116" = 79451.116 seconds
        
        Args:
            time_str: Time string in NMEA format
            
        Returns:
            Seconds since midnight or None if invalid
        """
        try:
            if not time_str or len(time_str) < 6:
                return None
            
            hours = int(time_str[:2])
            minutes = int(time_str[2:4])
            seconds = float(time_str[4:])
            
            total_seconds = hours * 3600 + minutes * 60 + seconds
            
            return total_seconds
        except (ValueError, IndexError):
            return None
