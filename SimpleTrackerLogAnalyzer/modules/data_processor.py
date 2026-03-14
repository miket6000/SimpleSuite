"""
Data processing module.
Cleans, filters, and processes GPS tracking data.
"""

from typing import List, Dict, Any, Optional
import pandas as pd
from modules.coordinate_converter import CoordinateConverter


class DataProcessor:
    """Processes and validates GPS tracking data."""
    
    def __init__(self, verbose: bool = False):
        """
        Initialize the data processor.
        
        Args:
            verbose: Whether to print debug information
        """
        self.verbose = verbose
        self.converter = CoordinateConverter()
    
    def process_remote_responses(
        self,
        remote_responses: List[Dict[str, Any]],
        min_hdop: Optional[float] = None,
        min_rssi: Optional[int] = None
    ) -> pd.DataFrame:
        """
        Process remote tracker responses into a dataframe.
        
        Args:
            remote_responses: List of remote response dicts from LogParser
            min_hdop: Minimum HDOP threshold (lower is better, e.g., 2.0)
            min_rssi: Minimum RSSI threshold (higher is better, e.g., -80)
            
        Returns:
            DataFrame with columns: uid, timestamp, latitude, longitude, altitude, rssi, hdop, etc.
        """
        data = []
        skipped = 0
        
        for response in remote_responses:
            try:
                parsed = response.get('parsed', {})
                
                # Convert coordinates
                lat = self.converter.nmea_to_decimal(
                    parsed.get('latitude'),
                    parsed.get('lat_direction')
                )
                lon = self.converter.nmea_to_decimal(
                    parsed.get('longitude'),
                    parsed.get('lon_direction')
                )
                
                if lat is None or lon is None:
                    skipped += 1
                    continue
                
                # Extract altitude
                try:
                    altitude = float(parsed.get('altitude', 0))
                except (ValueError, TypeError):
                    skipped += 1
                    continue
                
                # Extract other metrics
                try:
                    fix_quality = int(parsed.get('fix_quality', 0))
                    num_sats = int(parsed.get('num_satellites', 0))
                    hdop = float(parsed.get('hdop', 999))
                except (ValueError, TypeError):
                    skipped += 1
                    continue
                
                # Apply filters
                if min_hdop is not None and hdop > min_hdop:
                    skipped += 1
                    continue
                
                rssi = response.get('rssi')
                if min_rssi is not None and rssi is not None and rssi < min_rssi:
                    skipped += 1
                    continue
                
                # Add to data
                data.append({
                    'uid': response.get('uid'),
                    'timestamp': parsed.get('utc_time'),
                    'latitude': lat,
                    'longitude': lon,
                    'altitude': altitude,
                    'fix_quality': fix_quality,
                    'num_satellites': num_sats,
                    'hdop': hdop,
                    'rssi': rssi,
                    'raw_gngga': response.get('gngga')
                })
            
            except Exception as e:
                if self.verbose:
                    print(f"Error processing response: {e}")
                skipped += 1
        
        if self.verbose:
            print(f"Processed {len(data)} valid responses, skipped {skipped}")
        
        # Create dataframe
        if not data:
            return pd.DataFrame()
        
        df = pd.DataFrame(data)
        
        # Sort by UID and timestamp
        if not df.empty:
            df = df.sort_values(['uid', 'timestamp']).reset_index(drop=True)
            
            # Remove duplicate points
            duplicates_before = len(df)
            df = self._remove_duplicate_points(df)
            duplicates_removed = duplicates_before - len(df)
            
            if self.verbose and duplicates_removed > 0:
                print(f"Removed {duplicates_removed} duplicate points")
        
        return df
    
    def process_local_responses(
        self,
        local_responses: List[Dict[str, Any]],
        min_hdop: Optional[float] = None
    ) -> pd.DataFrame:
        """
        Process local tracker responses into a dataframe.
        
        Args:
            local_responses: List of local response dicts from LogParser
            min_hdop: Minimum HDOP threshold
            
        Returns:
            DataFrame with columns: timestamp, latitude, longitude, altitude, etc.
        """
        data = []
        skipped = 0
        
        for response in local_responses:
            try:
                parsed = response.get('parsed', {})
                
                # Convert coordinates
                lat = self.converter.nmea_to_decimal(
                    parsed.get('latitude'),
                    parsed.get('lat_direction')
                )
                lon = self.converter.nmea_to_decimal(
                    parsed.get('longitude'),
                    parsed.get('lon_direction')
                )
                
                if lat is None or lon is None:
                    skipped += 1
                    continue
                
                # Extract altitude
                try:
                    altitude = float(parsed.get('altitude', 0))
                except (ValueError, TypeError):
                    skipped += 1
                    continue
                
                # Extract other metrics
                try:
                    fix_quality = int(parsed.get('fix_quality', 0))
                    num_sats = int(parsed.get('num_satellites', 0))
                    hdop = float(parsed.get('hdop', 999))
                except (ValueError, TypeError):
                    skipped += 1
                    continue
                
                # Apply filters
                if min_hdop is not None and hdop > min_hdop:
                    skipped += 1
                    continue
                
                # Add to data
                data.append({
                    'timestamp': parsed.get('utc_time'),
                    'latitude': lat,
                    'longitude': lon,
                    'altitude': altitude,
                    'fix_quality': fix_quality,
                    'num_satellites': num_sats,
                    'hdop': hdop,
                    'raw_gngga': response.get('gngga')
                })
            
            except Exception as e:
                if self.verbose:
                    print(f"Error processing local response: {e}")
                skipped += 1
        
        if self.verbose:
            print(f"Processed {len(data)} valid local responses, skipped {skipped}")
        
        # Create dataframe
        if not data:
            return pd.DataFrame()
        
        df = pd.DataFrame(data)
        
        # Sort by timestamp
        if not df.empty:
            df = df.sort_values('timestamp').reset_index(drop=True)
            
            # Remove duplicate points
            duplicates_before = len(df)
            df = self._remove_duplicate_points(df)
            duplicates_removed = duplicates_before - len(df)
            
            if self.verbose and duplicates_removed > 0:
                print(f"Removed {duplicates_removed} duplicate local points")
        
        return df
    
    def get_devices(self, df: pd.DataFrame) -> List[str]:
        """
        Get list of unique device UIDs in dataframe.
        
        Args:
            df: Remote responses dataframe
            
        Returns:
            List of unique UIDs
        """
        if 'uid' not in df.columns:
            return []
        
        return sorted(df['uid'].unique().tolist())
    
    def get_device_data(self, df: pd.DataFrame, uid: str) -> pd.DataFrame:
        """
        Get data for a specific device.
        
        Args:
            df: Remote responses dataframe
            uid: Device UID
            
        Returns:
            Filtered dataframe for the device
        """
        if 'uid' not in df.columns:
            return pd.DataFrame()
        
        return df[df['uid'] == uid].copy()
    
    def get_track_statistics(self, df: pd.DataFrame) -> Dict[str, Any]:
        """
        Get statistics about a track.
        
        Args:
            df: Track dataframe (from get_device_data or local responses)
            
        Returns:
            Dictionary with statistics
        """
        if df.empty:
            return {
                'num_points': 0,
                'min_altitude': None,
                'max_altitude': None,
                'mean_altitude': None
            }
        
        stats = {
            'num_points': len(df),
            'min_altitude': df['altitude'].min(),
            'max_altitude': df['altitude'].max(),
            'mean_altitude': df['altitude'].mean(),
            'min_latitude': df['latitude'].min(),
            'max_latitude': df['latitude'].max(),
            'min_longitude': df['longitude'].min(),
            'max_longitude': df['longitude'].max(),
            'mean_hdop': df['hdop'].mean(),
            'mean_rssi': df['rssi'].mean() if 'rssi' in df.columns else None,
            'num_satellites_mean': df['num_satellites'].mean(),
        }
        
        return stats
    
    def _remove_duplicate_points(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Remove completely duplicate GPS points.
        
        Duplicate points are those where ALL fields in the response are identical.
        When duplicates are found, the first occurrence is kept and subsequent
        duplicates are removed.
        
        Args:
            df: DataFrame with GPS points
            
        Returns:
            DataFrame with duplicates removed
        """
        if df.empty or len(df) < 2:
            return df
        
        # Mark duplicates (keep first occurrence) based on all columns
        # This removes rows that are completely identical
        df_copy = df.copy()
        df_copy['is_duplicate'] = df_copy.duplicated(keep='first')
        
        # Remove the duplicate flag
        result = df_copy[~df_copy['is_duplicate']].copy()
        result = result.drop(columns=['is_duplicate'])
        result = result.reset_index(drop=True)
        
        return result
