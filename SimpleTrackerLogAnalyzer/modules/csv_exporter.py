"""
CSV export module.
Exports GPS tracking data to CSV format with calculated metrics.
"""

import csv
from typing import Optional
import pandas as pd


class CSVExporter:
    """Exports GPS tracking data to CSV format."""
    
    def __init__(self, verbose: bool = False):
        """
        Initialize the CSV exporter.
        
        Args:
            verbose: Whether to print debug information
        """
        self.verbose = verbose
    
    def export_remote_track_csv(
        self,
        remote_df: pd.DataFrame,
        output_file: str
    ) -> bool:
        """
        Export remote tracker data to CSV with calculated metrics.
        
        Args:
            remote_df: DataFrame with remote tracking data
            output_file: Output CSV file path
            
        Returns:
            True if successful, False otherwise
        """
        try:
            if remote_df.empty:
                print("Error: No remote data to export")
                return False
            
            # Get unique devices
            uids = remote_df['uid'].unique()
            
            all_data = []
            
            for uid in uids:
                device_data = remote_df[remote_df['uid'] == uid].copy()
                device_data = device_data.sort_values('timestamp').reset_index(drop=True)
                
                # Calculate vertical velocity
                device_data = self._calculate_vertical_velocity(device_data)
                
                # Add UID column
                device_data['uid'] = uid
                
                all_data.append(device_data)
            
            if all_data:
                combined_df = pd.concat(all_data, ignore_index=True)
            else:
                combined_df = pd.DataFrame()
            
            # Select and order columns
            columns = ['uid', 'timestamp', 'latitude', 'longitude', 'altitude', 'vertical_velocity',
                      'fix_quality', 'num_satellites', 'hdop', 'rssi']
            
            # Only include columns that exist
            columns = [c for c in columns if c in combined_df.columns]
            export_df = combined_df[columns]
            
            # Export to CSV
            export_df.to_csv(output_file, index=False)
            
            if self.verbose:
                print(f"CSV exported to {output_file} with {len(export_df)} points")
            
            return True
        
        except Exception as e:
            print(f"Error exporting CSV: {e}")
            return False
    
    def export_local_track_csv(
        self,
        local_df: pd.DataFrame,
        output_file: str
    ) -> bool:
        """
        Export local tracker data to CSV with calculated metrics.
        
        Args:
            local_df: DataFrame with local tracking data
            output_file: Output CSV file path
            
        Returns:
            True if successful, False otherwise
        """
        try:
            if local_df.empty:
                print("Error: No local data to export")
                return False
            
            local_df = local_df.sort_values('timestamp').reset_index(drop=True)
            
            # Calculate vertical velocity
            local_df = self._calculate_vertical_velocity(local_df)
            
            # Select and order columns
            columns = ['timestamp', 'latitude', 'longitude', 'altitude', 'vertical_velocity',
                      'fix_quality', 'num_satellites', 'hdop']
            
            # Only include columns that exist
            columns = [c for c in columns if c in local_df.columns]
            export_df = local_df[columns]
            
            # Export to CSV
            export_df.to_csv(output_file, index=False)
            
            if self.verbose:
                print(f"CSV exported to {output_file} with {len(export_df)} points")
            
            return True
        
        except Exception as e:
            print(f"Error exporting CSV: {e}")
            return False
    
    def export_comparison_csv(
        self,
        remote_df: pd.DataFrame,
        local_df: pd.DataFrame,
        output_file: str
    ) -> bool:
        """
        Export both remote and local tracking data to CSV files.
        
        Creates two files:
        - output_file_remote.csv
        - output_file_local.csv
        
        Args:
            remote_df: DataFrame with remote tracking data
            local_df: DataFrame with local tracking data
            output_file: Base output file path (without extension)
            
        Returns:
            True if successful, False otherwise
        """
        try:
            # Remove .csv extension if present
            base_file = output_file.replace('.csv', '')
            
            remote_file = f"{base_file}_remote.csv"
            local_file = f"{base_file}_local.csv"
            
            # Export remote data
            if not remote_df.empty:
                if not self.export_remote_track_csv(remote_df, remote_file):
                    return False
            else:
                if self.verbose:
                    print("No remote data to export")
            
            # Export local data
            if not local_df.empty:
                if not self.export_local_track_csv(local_df, local_file):
                    return False
            else:
                if self.verbose:
                    print("No local data to export")
            
            return True
        
        except Exception as e:
            print(f"Error exporting comparison CSV: {e}")
            return False
    
    @staticmethod
    def _calculate_vertical_velocity(df: pd.DataFrame) -> pd.DataFrame:
        """
        Calculate vertical velocity for each point.
        
        Vertical velocity is calculated as:
        (altitude_delta) / (timestamp_delta) in meters per second
        
        For the first point, vertical velocity is set to 0 (no previous point).
        
        Args:
            df: DataFrame with timestamp and altitude columns
            
        Returns:
            DataFrame with added vertical_velocity column
        """
        df = df.copy()
        
        # Initialize vertical velocity column with NaN
        df['vertical_velocity'] = float('nan')
        
        if len(df) < 2:
            # If only one point, set vertical velocity to 0
            df['vertical_velocity'] = 0.0
            return df
        
        # Calculate velocity for each point (except the first)
        for i in range(1, len(df)):
            try:
                # Convert timestamps to seconds for comparison
                # Assuming timestamp is in format HHMMSS.sss
                current_time = CSVExporter._time_to_seconds(df.iloc[i]['timestamp'])
                previous_time = CSVExporter._time_to_seconds(df.iloc[i-1]['timestamp'])
                
                current_alt = float(df.iloc[i]['altitude'])
                previous_alt = float(df.iloc[i-1]['altitude'])
                
                # Calculate time delta
                time_delta = current_time - previous_time
                
                # Handle case where time wraps around midnight
                if time_delta < 0:
                    # Assume we wrapped around midnight (24 hours = 86400 seconds)
                    time_delta += 86400
                
                # Avoid division by zero
                if time_delta > 0:
                    altitude_delta = current_alt - previous_alt
                    velocity = altitude_delta / time_delta  # m/s
                    df.at[i, 'vertical_velocity'] = velocity
                else:
                    df.at[i, 'vertical_velocity'] = 0.0
            
            except (ValueError, TypeError):
                # If calculation fails, set to NaN
                df.at[i, 'vertical_velocity'] = float('nan')
        
        # First point gets 0 velocity (no previous point to compare)
        df.at[0, 'vertical_velocity'] = 0.0
        
        # Fill any remaining NaN values with 0
        df['vertical_velocity'] = df['vertical_velocity'].fillna(0.0)
        
        return df
    
    @staticmethod
    def _time_to_seconds(time_str: str) -> float:
        """
        Convert NMEA time string to seconds since midnight.
        
        Args:
            time_str: Time string in HHMMSS.sss format
            
        Returns:
            Seconds since midnight
        """
        try:
            if not time_str or len(time_str) < 6:
                return 0.0
            
            hours = int(time_str[:2])
            minutes = int(time_str[2:4])
            seconds = float(time_str[4:])
            
            total_seconds = hours * 3600 + minutes * 60 + seconds
            return total_seconds
        except (ValueError, IndexError):
            return 0.0
