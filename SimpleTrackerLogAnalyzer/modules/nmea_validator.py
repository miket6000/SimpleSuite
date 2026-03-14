"""
NMEA sentence parsing and validation module.
Handles GNGGA sentence parsing, checksum validation, and corrupted data recovery.
"""

import re
from typing import Optional, Dict, Any


class NMEAValidator:
    """Validates and parses GNGGA (GPS) sentences."""
    
    @staticmethod
    def validate_checksum(sentence: str) -> bool:
        """
        Validate NMEA sentence checksum.
        
        Args:
            sentence: NMEA sentence (e.g., "$GNGGA,221451.116,,,,,0,0,,,M,,M,,*51")
            
        Returns:
            True if checksum is valid, False otherwise
        """
        # Remove any whitespace
        sentence = sentence.strip()
        
        # Check format
        if not sentence.startswith('$') or '*' not in sentence:
            return False
        
        try:
            # Extract checksum portion
            data_part, checksum_part = sentence.rsplit('*', 1)
            data_part = data_part[1:]  # Remove '$'
            
            # Calculate expected checksum
            calculated_checksum = 0
            for char in data_part:
                calculated_checksum ^= ord(char)
            
            calculated_hex = f"{calculated_checksum:02X}"
            
            # Compare
            return calculated_hex == checksum_part.upper()
        except (ValueError, IndexError):
            return False
    
    @staticmethod
    def parse_gngga(sentence: str) -> Optional[Dict[str, Any]]:
        """
        Parse a GNGGA sentence into its components.
        
        Args:
            sentence: GNGGA sentence string
            
        Returns:
            Dictionary with parsed fields or None if invalid
        """
        sentence = sentence.strip()
        
        # Validate checksum first
        if not NMEAValidator.validate_checksum(sentence):
            return None
        
        try:
            # Remove checksum
            sentence_data = sentence.split('*')[0][1:]  # Remove '$' and checksum
            fields = sentence_data.split(',')
            
            # Basic field count check (GNGGA has at least 14 fields)
            if len(fields) < 14:
                return None
            
            # Extract fields
            result = {
                'message_id': fields[0],
                'utc_time': fields[1],
                'latitude': fields[2],
                'lat_direction': fields[3],
                'longitude': fields[4],
                'lon_direction': fields[5],
                'fix_quality': fields[6],
                'num_satellites': fields[7],
                'hdop': fields[8],
                'altitude': fields[9],
                'altitude_unit': fields[10],
                'geoid_height': fields[11],
                'geoid_unit': fields[12],
            }
            
            # Validate required fields
            if not result['message_id'].startswith('GNGGA'):
                return None
            
            # Check that position fields exist
            if not result['latitude'] or not result['longitude']:
                return None
            
            # Check fix quality (must be >= 1 for valid fix)
            try:
                fix_quality = int(result['fix_quality'])
                if fix_quality < 1:
                    return None
            except ValueError:
                return None
            
            # Validate altitude exists and is a valid number
            if not result['altitude']:
                return None
            
            try:
                float(result['altitude'])
            except ValueError:
                return None
            
            return result
        except Exception:
            return None
    
    @staticmethod
    def attempt_recovery(corrupted_line: str) -> Optional[str]:
        """
        Attempt to recover a valid GNGGA sentence from a corrupted line.
        
        Handles:
        - Extra spaces within the sentence
        - Newlines in the middle
        - Partial corruption
        
        Args:
            corrupted_line: The potentially corrupted line
            
        Returns:
            Recovered sentence or None if recovery failed
        """
        # Remove extra whitespace between fields but preserve structure
        # Match $GNGGA pattern and capture until checksum
        pattern = r'\$GNGGA[^$]*?\*[0-9A-Fa-f]{2}'
        match = re.search(pattern, corrupted_line)
        
        if match:
            sentence = match.group()
            # Clean up spaces around commas
            sentence = re.sub(r'\s+,', ',', sentence)
            sentence = re.sub(r',\s+', ',', sentence)
            return sentence
        
        return None


def extract_gngga_from_remote_response(response_line: str) -> Optional[str]:
    """
    Extract GNGGA sentence from a remote tracker response.
    
    Remote response format: "UID GNGGA_SENTENCE RSSI"
    Example: "f49ae83e $GNGGA,221453.000,3733.001470,S,... -63"
    
    Args:
        response_line: The remote response line
        
    Returns:
        GNGGA sentence or None if not found
    """
    # Pattern to match GNGGA sentence
    pattern = r'(\$GNGGA[^$]*?\*[0-9A-Fa-f]{2})'
    match = re.search(pattern, response_line)
    
    if match:
        return match.group(1)
    
    return None


def extract_rssi_from_remote_response(response_line: str) -> Optional[int]:
    """
    Extract RSSI (signal strength) from a remote tracker response.
    
    Args:
        response_line: The remote response line
        
    Returns:
        RSSI value (dBm) or None if not found
    """
    # RSSI is typically a negative number at the end
    match = re.search(r'(-\d+)\s*$', response_line.strip())
    
    if match:
        try:
            return int(match.group(1))
        except ValueError:
            return None
    
    return None


def extract_uid_from_remote_response(response_line: str) -> Optional[str]:
    """
    Extract UID from a remote tracker response.
    
    Args:
        response_line: The remote response line
        
    Returns:
        UID (hex string) or None if not found
    """
    # UID is typically the first field (8 hex characters)
    match = re.match(r'^([0-9a-fA-F]{8})', response_line.strip())
    
    if match:
        return match.group(1).lower()
    
    return None
