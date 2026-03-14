"""
Unit tests for CSV exporter module.
"""

import unittest
import tempfile
import os
import csv
import pandas as pd

from modules.csv_exporter import CSVExporter


class TestCSVExporter(unittest.TestCase):
    """Test CSV exporter functionality."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.exporter = CSVExporter(verbose=False)
        self.temp_dir = tempfile.mkdtemp()
    
    def tearDown(self):
        """Clean up test files."""
        import shutil
        if os.path.exists(self.temp_dir):
            shutil.rmtree(self.temp_dir)
    
    def test_vertical_velocity_calculation(self):
        """Test vertical velocity calculation between two points."""
        # Create test data: 2 seconds apart, 10m altitude change
        data = {
            'timestamp': ['100000.000', '100002.000'],
            'altitude': [100.0, 110.0],
            'latitude': [-37.55, -37.55],
            'longitude': [175.26, 175.26],
            'fix_quality': [1, 1],
            'num_satellites': [10, 10],
            'hdop': [1.0, 1.0]
        }
        df = pd.DataFrame(data)
        
        result = self.exporter._calculate_vertical_velocity(df)
        
        # First point should have 0 velocity
        self.assertEqual(result.iloc[0]['vertical_velocity'], 0.0)
        
        # Second point: (110-100) / (2) = 5 m/s
        self.assertAlmostEqual(result.iloc[1]['vertical_velocity'], 5.0, places=1)
    
    def test_vertical_velocity_descending(self):
        """Test vertical velocity calculation for descending track."""
        # Descending 20m over 4 seconds = -5 m/s
        data = {
            'timestamp': ['100000.000', '100004.000'],
            'altitude': [100.0, 80.0],
            'latitude': [-37.55, -37.55],
            'longitude': [175.26, 175.26],
            'fix_quality': [1, 1],
            'num_satellites': [10, 10],
            'hdop': [1.0, 1.0]
        }
        df = pd.DataFrame(data)
        
        result = self.exporter._calculate_vertical_velocity(df)
        
        # Second point: (80-100) / 4 = -5 m/s
        self.assertAlmostEqual(result.iloc[1]['vertical_velocity'], -5.0, places=1)
    
    def test_vertical_velocity_midnight_wrap(self):
        """Test vertical velocity calculation when time wraps around midnight."""
        # From 235959.000 to 000001.000 (2 seconds forward with wrap)
        data = {
            'timestamp': ['235959.000', '000001.000'],
            'altitude': [100.0, 102.0],
            'latitude': [-37.55, -37.55],
            'longitude': [175.26, 175.26],
            'fix_quality': [1, 1],
            'num_satellites': [10, 10],
            'hdop': [1.0, 1.0]
        }
        df = pd.DataFrame(data)
        
        result = self.exporter._calculate_vertical_velocity(df)
        
        # Should handle midnight wrap: 2m / 2s = 1 m/s
        self.assertAlmostEqual(result.iloc[1]['vertical_velocity'], 1.0, places=1)
    
    def test_time_to_seconds_conversion(self):
        """Test time string to seconds conversion."""
        # 10:30:45.5 = 10*3600 + 30*60 + 45.5 = 37845.5
        result = self.exporter._time_to_seconds('103045.500')
        self.assertAlmostEqual(result, 37845.5, places=1)
    
    def test_time_to_seconds_midnight(self):
        """Test midnight time conversion."""
        result = self.exporter._time_to_seconds('000000.000')
        self.assertEqual(result, 0.0)
    
    def test_time_to_seconds_end_of_day(self):
        """Test end of day time conversion."""
        # 23:59:59.999 = 23*3600 + 59*60 + 59.999
        result = self.exporter._time_to_seconds('235959.999')
        self.assertAlmostEqual(result, 86399.999, places=2)
    
    def test_export_remote_track_csv(self):
        """Test remote track CSV export."""
        # Create test data
        data = {
            'uid': ['device001', 'device001', 'device001'],
            'timestamp': ['100000.000', '100002.000', '100004.000'],
            'latitude': [-37.55, -37.56, -37.57],
            'longitude': [175.26, 175.27, 175.28],
            'altitude': [100.0, 105.0, 110.0],
            'fix_quality': [1, 1, 1],
            'num_satellites': [10, 10, 10],
            'hdop': [1.0, 1.0, 1.0],
            'rssi': [-70, -70, -70]
        }
        df = pd.DataFrame(data)
        
        output_file = os.path.join(self.temp_dir, 'test_remote.csv')
        result = self.exporter.export_remote_track_csv(df, output_file)
        
        self.assertTrue(result)
        self.assertTrue(os.path.exists(output_file))
        
        # Verify CSV content
        with open(output_file, 'r') as f:
            reader = csv.DictReader(f)
            rows = list(reader)
            
            self.assertEqual(len(rows), 3)
            self.assertEqual(rows[0]['uid'], 'device001')
            self.assertIn('vertical_velocity', rows[0])
    
    def test_export_local_track_csv(self):
        """Test local track CSV export."""
        # Create test data
        data = {
            'timestamp': ['100000.000', '100002.000'],
            'latitude': [-37.55, -37.56],
            'longitude': [175.26, 175.27],
            'altitude': [100.0, 105.0],
            'fix_quality': [1, 1],
            'num_satellites': [10, 10],
            'hdop': [1.0, 1.0]
        }
        df = pd.DataFrame(data)
        
        output_file = os.path.join(self.temp_dir, 'test_local.csv')
        result = self.exporter.export_local_track_csv(df, output_file)
        
        self.assertTrue(result)
        self.assertTrue(os.path.exists(output_file))
        
        # Verify CSV content
        with open(output_file, 'r') as f:
            reader = csv.DictReader(f)
            rows = list(reader)
            
            self.assertEqual(len(rows), 2)
            self.assertIn('vertical_velocity', rows[0])
    
    def test_export_comparison_csv(self):
        """Test comparison CSV export (remote and local)."""
        # Create test data
        remote_data = {
            'uid': ['device001', 'device001'],
            'timestamp': ['100000.000', '100002.000'],
            'latitude': [-37.55, -37.56],
            'longitude': [175.26, 175.27],
            'altitude': [100.0, 105.0],
            'fix_quality': [1, 1],
            'num_satellites': [10, 10],
            'hdop': [1.0, 1.0],
            'rssi': [-70, -70]
        }
        remote_df = pd.DataFrame(remote_data)
        
        local_data = {
            'timestamp': ['100000.000', '100002.000'],
            'latitude': [-37.55, -37.56],
            'longitude': [175.26, 175.27],
            'altitude': [100.0, 105.0],
            'fix_quality': [1, 1],
            'num_satellites': [10, 10],
            'hdop': [1.0, 1.0]
        }
        local_df = pd.DataFrame(local_data)
        
        output_file = os.path.join(self.temp_dir, 'test_comparison.csv')
        result = self.exporter.export_comparison_csv(remote_df, local_df, output_file)
        
        self.assertTrue(result)
        
        # Check both files were created
        remote_file = output_file.replace('.csv', '_remote.csv')
        local_file = output_file.replace('.csv', '_local.csv')
        
        self.assertTrue(os.path.exists(remote_file))
        self.assertTrue(os.path.exists(local_file))


if __name__ == '__main__':
    unittest.main()
