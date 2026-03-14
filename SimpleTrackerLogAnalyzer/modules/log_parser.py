"""
Log file parser module.
Parses serial log files and extracts GPS tracking data.
"""

import re
from typing import List, Dict, Any, Optional
from dataclasses import dataclass


@dataclass
class RemoteGPSPoint:
    """Represents a GPS point from a remote tracker."""
    uid: str
    timestamp: str
    latitude: str
    latitude_dir: str
    longitude: str
    longitude_dir: str
    altitude: float
    fix_quality: int
    num_satellites: int
    hdop: float
    rssi: Optional[int] = None
    raw_line: Optional[str] = None
    is_valid: bool = True


@dataclass
class LocalGPSPoint:
    """Represents a GPS point from the local tracker."""
    timestamp: str
    latitude: str
    latitude_dir: str
    longitude: str
    longitude_dir: str
    altitude: float
    fix_quality: int
    num_satellites: int
    hdop: float
    raw_line: Optional[str] = None
    is_valid: bool = True


class LogParser:
    """Parses serial log files for GPS tracking data."""
    
    def __init__(self, log_file_path: str, verbose: bool = False):
        """
        Initialize the log parser.
        
        Args:
            log_file_path: Path to the serial log file
            verbose: Whether to print debug information
        """
        self.log_file_path = log_file_path
        self.verbose = verbose
        self.lines = []
        self.remote_responses = []
        self.local_responses = []
    
    def read_log_file(self) -> bool:
        """
        Read the log file into memory.
        
        Returns:
            True if successful, False otherwise
        """
        try:
            with open(self.log_file_path, 'r') as f:
                self.lines = f.readlines()
            
            if self.verbose:
                print(f"Read {len(self.lines)} lines from {self.log_file_path}")
            
            return True
        except FileNotFoundError:
            print(f"Error: Log file not found: {self.log_file_path}")
            return False
        except Exception as e:
            print(f"Error reading log file: {e}")
            return False
    
    def parse(self) -> bool:
        """
        Parse the log file and extract GPS data.
        
        Returns:
            True if parsing was successful, False otherwise
        """
        if not self.lines:
            print("Error: No lines to parse. Call read_log_file() first.")
            return False
        
        # Parse remote responses (> R commands)
        self.remote_responses = self._parse_remote_responses()
        
        # Parse local responses (> L commands)
        self.local_responses = self._parse_local_responses()
        
        if self.verbose:
            print(f"Found {len(self.remote_responses)} remote responses")
            print(f"Found {len(self.local_responses)} local responses")
        
        return True
    
    def _parse_remote_responses(self) -> List[Dict[str, Any]]:
        """
        Extract remote tracker responses from log.
        
        Format:
        > R
        < f49ae83e $GNGGA,221453.000,3733.001470,S,17515.618888,E,2,28,0.52,22.729,M,24.306,M,,*5B -63
        
        Returns:
            List of remote response data
        """
        responses = []
        i = 0
        
        while i < len(self.lines):
            line = self.lines[i]
            
            # Look for "> R" command
            if line.strip() == '> R':
                # Check if next line is a response (starts with '<')
                if i + 1 < len(self.lines):
                    response_line = self.lines[i + 1].strip()
                    
                    if response_line.startswith('<'):
                        # Remove the '<' prefix
                        response_data = response_line[1:].strip()
                        
                        # Try to parse the response
                        parsed = self._parse_remote_response_line(response_data)
                        if parsed:
                            responses.append(parsed)
                        elif self.verbose:
                            print(f"Warning: Could not parse remote response: {response_data}")
                        
                        i += 2
                        continue
            
            i += 1
        
        return responses
    
    def _parse_local_responses(self) -> List[Dict[str, Any]]:
        """
        Extract local tracker responses from log.
        
        Format:
        > L
        < $GNGGA,221456.000,3733.005046,S,17515.621444,E,1,7,2.12,31.202,M,24.305,M,,*68
        
        Returns:
            List of local response data
        """
        responses = []
        i = 0
        
        while i < len(self.lines):
            line = self.lines[i]
            
            # Look for "> L" command
            if line.strip() == '> L':
                # Check if next line is a response (starts with '<')
                if i + 1 < len(self.lines):
                    response_line = self.lines[i + 1].strip()
                    
                    if response_line.startswith('<'):
                        # Remove the '<' prefix
                        response_data = response_line[1:].strip()
                        
                        # Try to parse the response
                        parsed = self._parse_local_response_line(response_data)
                        if parsed:
                            responses.append(parsed)
                        elif self.verbose:
                            print(f"Warning: Could not parse local response: {response_data}")
                        
                        i += 2
                        continue
            
            i += 1
        
        return responses
    
    def _parse_remote_response_line(self, response_data: str) -> Optional[Dict[str, Any]]:
        """
        Parse a single remote response line.
        
        Format: "UID GNGGA_SENTENCE RSSI"
        Example: "f49ae83e $GNGGA,221453.000,... -63"
        
        Args:
            response_data: Response data (without '<' prefix)
            
        Returns:
            Parsed response dict or None if invalid
        """
        # Import here to avoid circular imports
        from modules.nmea_validator import (
            extract_uid_from_remote_response,
            extract_gngga_from_remote_response,
            extract_rssi_from_remote_response,
            NMEAValidator
        )
        
        # Extract components
        uid = extract_uid_from_remote_response(response_data)
        gngga = extract_gngga_from_remote_response(response_data)
        rssi = extract_rssi_from_remote_response(response_data)
        
        if not uid or not gngga:
            return None
        
        # Validate and parse GNGGA
        parsed = NMEAValidator.parse_gngga(gngga)
        if not parsed:
            return None
        
        # Build result
        return {
            'uid': uid,
            'gngga': gngga,
            'rssi': rssi,
            'parsed': parsed,
            'raw_line': response_data
        }
    
    def _parse_local_response_line(self, response_data: str) -> Optional[Dict[str, Any]]:
        """
        Parse a single local response line.
        
        Format: Just GNGGA sentence
        Example: "$GNGGA,221453.000,3733.001470,S,17515.618888,E,..."
        
        Args:
            response_data: Response data (without '<' prefix)
            
        Returns:
            Parsed response dict or None if invalid
        """
        # Import here to avoid circular imports
        from modules.nmea_validator import NMEAValidator
        
        # Validate and parse GNGGA
        parsed = NMEAValidator.parse_gngga(response_data)
        if not parsed:
            return None
        
        # Build result
        return {
            'gngga': response_data,
            'parsed': parsed,
            'raw_line': response_data
        }
    
    def get_remote_responses(self) -> List[Dict[str, Any]]:
        """Get all remote responses."""
        return self.remote_responses
    
    def get_local_responses(self) -> List[Dict[str, Any]]:
        """Get all local responses."""
        return self.local_responses
