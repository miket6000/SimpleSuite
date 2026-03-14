"""
KML generator module.
Creates KML files for viewing GPS tracks in Google Earth.
"""

from typing import List, Dict, Any, Optional
import pandas as pd
import simplekml


class KMLGenerator:
    """Generates KML files from GPS tracking data."""
    
    def __init__(self, verbose: bool = False):
        """
        Initialize the KML generator.
        
        Args:
            verbose: Whether to print debug information
        """
        self.verbose = verbose
    
    def generate_remote_track_kml(
        self,
        remote_df: pd.DataFrame,
        output_file: str,
        title: str = "Remote Tracker",
        color_by_rssi: bool = True
    ) -> bool:
        """
        Generate KML file for remote tracker(s).
        
        Args:
            remote_df: DataFrame with remote tracking data (from DataProcessor)
            output_file: Output KML file path
            title: Title for the KML document
            color_by_rssi: Whether to color lines by RSSI strength
            
        Returns:
            True if successful, False otherwise
        """
        try:
            kml = simplekml.Kml()
            kml.name = title
            
            if remote_df.empty:
                print("Error: No remote data to process")
                return False
            
            # Get unique devices
            uids = remote_df['uid'].unique()
            
            for uid in uids:
                device_data = remote_df[remote_df['uid'] == uid].copy()
                device_data = device_data.sort_values('timestamp').reset_index(drop=True)
                
                # Create folder for device
                device_folder = kml.newfolder(name=f"Device {uid}")
                
                # Add track as LineString
                self._add_track_to_folder(
                    device_folder,
                    device_data,
                    f"Track - {uid}",
                    color_by_rssi
                )
                
                # Add start and end markers
                if len(device_data) > 0:
                    first_point = device_data.iloc[0]
                    last_point = device_data.iloc[-1]
                    
                    # Start marker (green)
                    start_pm = device_folder.newpoint(
                        name="Start",
                        coords=[(first_point['longitude'], first_point['latitude'], first_point['altitude'])]
                    )
                    start_pm.style.iconstyle.icon.href = "http://maps.google.com/mapfiles/kml/paddle/grn-circle.png"
                    
                    # End marker (red)
                    end_pm = device_folder.newpoint(
                        name="End",
                        coords=[(last_point['longitude'], last_point['latitude'], last_point['altitude'])]
                    )
                    end_pm.style.iconstyle.icon.href = "http://maps.google.com/mapfiles/kml/paddle/red-circle.png"
                
                if self.verbose:
                    print(f"Added track for device {uid} with {len(device_data)} points")
            
            # Save KML
            kml.save(output_file)
            
            if self.verbose:
                print(f"KML saved to {output_file}")
            
            return True
        
        except Exception as e:
            print(f"Error generating KML: {e}")
            return False
    
    def generate_local_track_kml(
        self,
        local_df: pd.DataFrame,
        output_file: str,
        title: str = "Local Tracker"
    ) -> bool:
        """
        Generate KML file for local tracker.
        
        Args:
            local_df: DataFrame with local tracking data
            output_file: Output KML file path
            title: Title for the KML document
            
        Returns:
            True if successful, False otherwise
        """
        try:
            kml = simplekml.Kml()
            kml.name = title
            
            if local_df.empty:
                print("Error: No local data to process")
                return False
            
            local_df = local_df.sort_values('timestamp').reset_index(drop=True)
            
            # Add track as LineString
            self._add_track_to_folder(
                kml,
                local_df,
                "Local Track",
                color_by_rssi=False
            )
            
            # Add start and end markers
            if len(local_df) > 0:
                first_point = local_df.iloc[0]
                last_point = local_df.iloc[-1]
                
                # Start marker (green)
                start_pm = kml.newpoint(
                    name="Start",
                    coords=[(first_point['longitude'], first_point['latitude'], first_point['altitude'])]
                )
                start_pm.style.iconstyle.icon.href = "http://maps.google.com/mapfiles/kml/paddle/grn-circle.png"
                
                # End marker (red)
                end_pm = kml.newpoint(
                    name="End",
                    coords=[(last_point['longitude'], last_point['latitude'], last_point['altitude'])]
                )
                end_pm.style.iconstyle.icon.href = "http://maps.google.com/mapfiles/kml/paddle/red-circle.png"
            
            # Save KML
            kml.save(output_file)
            
            if self.verbose:
                print(f"KML saved to {output_file}")
            
            return True
        
        except Exception as e:
            print(f"Error generating KML: {e}")
            return False
    
    def _add_track_to_folder(
        self,
        folder,
        track_df: pd.DataFrame,
        track_name: str,
        color_by_rssi: bool = True
    ) -> None:
        """
        Add a track (LineString) to a KML folder.
        
        Args:
            folder: KML folder to add track to
            track_df: DataFrame with track points
            track_name: Name for the track
            color_by_rssi: Whether to color line based on RSSI
        """
        # Create coordinates list with altitude
        coords = [
            (row['longitude'], row['latitude'], row['altitude'])
            for _, row in track_df.iterrows()
        ]
        
        if not coords:
            return
        
        # Create LineString
        ls = folder.newlinestring(name=track_name, coords=coords)
        ls.altitudemode = simplekml.AltitudeMode.absolute
        ls.extrude = 1
        
        # Set style
        if color_by_rssi and 'rssi' in track_df.columns:
            # Color based on RSSI strength
            # RSSI values are negative (e.g., -60, -80, -100)
            # Convert to 0-100 scale: higher RSSI = better = green
            # Typical range: -30 (excellent) to -100 (poor)
            
            # Calculate mean RSSI for style
            mean_rssi = track_df['rssi'].mean()
            
            # Determine color: red (poor) -> yellow (fair) -> green (good)
            if pd.notna(mean_rssi):
                color = self._rssi_to_color(mean_rssi)
            else:
                color = '00FF00'  # Green default
            
            ls.style.linestyle.color = f'{color}FF'  # Add full opacity
            ls.style.linestyle.width = 2
        else:
            # Default blue
            ls.style.linestyle.color = '00FF00FF'  # AABBGGRR format (cyan)
            ls.style.linestyle.width = 2
        
        # Add altitude extrusion
        ls.style.polystyle.fill = 1
        ls.style.polystyle.outline = 1
    
    def _rssi_to_color(self, rssi: float) -> str:
        """
        Convert RSSI value to KML color.
        
        RSSI is negative (e.g., -60 dBm is good, -100 dBm is poor)
        Returns color in AABBGGRR format (without alpha)
        
        Args:
            rssi: RSSI value in dBm
            
        Returns:
            Color string in BBGGRR format
        """
        # Normalize RSSI to 0-100 scale
        # -30 dBm = 100 (excellent)
        # -100 dBm = 0 (poor)
        normalized = max(0, min(100, (rssi + 100) * 2))
        
        # Create color gradient: red (poor) -> yellow (fair) -> green (good)
        if normalized < 50:
            # Red to Yellow
            ratio = normalized / 50
            r = 255
            g = int(255 * ratio)
            b = 0
        else:
            # Yellow to Green
            ratio = (normalized - 50) / 50
            r = int(255 * (1 - ratio))
            g = 255
            b = 0
        
        # Return in BBGGRR format (KML uses BGR)
        return f'{b:02X}{g:02X}{r:02X}'
    
    def generate_comparison_kml(
        self,
        remote_df: pd.DataFrame,
        local_df: pd.DataFrame,
        output_file: str,
        title: str = "Remote vs Local Tracker"
    ) -> bool:
        """
        Generate KML comparing remote and local tracks.
        
        Args:
            remote_df: DataFrame with remote tracking data
            local_df: DataFrame with local tracking data
            output_file: Output KML file path
            title: Title for the KML document
            
        Returns:
            True if successful, False otherwise
        """
        try:
            kml = simplekml.Kml()
            kml.name = title
            
            # Add remote tracks
            if not remote_df.empty:
                remote_folder = kml.newfolder(name="Remote Trackers")
                
                for uid in remote_df['uid'].unique():
                    device_data = remote_df[remote_df['uid'] == uid].sort_values('timestamp')
                    device_folder = remote_folder.newfolder(name=f"Device {uid}")
                    self._add_track_to_folder(device_folder, device_data, f"Track - {uid}", color_by_rssi=True)
            
            # Add local track
            if not local_df.empty:
                local_folder = kml.newfolder(name="Local Tracker")
                local_df_sorted = local_df.sort_values('timestamp')
                self._add_track_to_folder(local_folder, local_df_sorted, "Local Track", color_by_rssi=False)
            
            # Save KML
            kml.save(output_file)
            
            if self.verbose:
                print(f"Comparison KML saved to {output_file}")
            
            return True
        
        except Exception as e:
            print(f"Error generating comparison KML: {e}")
            return False
