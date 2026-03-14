"""
Integration tests for the full GPS tracker parsing pipeline.
"""

import unittest
import tempfile
import os
from pathlib import Path
import pandas as pd

from modules.log_parser import LogParser
from modules.data_processor import DataProcessor
from modules.kml_generator import KMLGenerator


class TestIntegration(unittest.TestCase):
    """Integration tests for the complete pipeline."""
    
    def setUp(self):
        """Set up test fixtures."""
        # Create a temporary directory for test files
        self.test_dir = tempfile.mkdtemp()
        
        # Create a sample log file with known data
        self.log_file = os.path.join(self.test_dir, 'test_log.txt')
        self._create_test_log_file()
    
    def tearDown(self):
        """Clean up test files."""
        import shutil
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)
    
    def _create_test_log_file(self):
        """Create a test log file with sample data."""
        log_content = """
> i
> UID
< 85a3f70c
> R
< f49ae83e $GNGGA,221453.000,3733.001470,S,17515.618888,E,2,28,0.52,22.729,M,24.306,M,,*5B -63
> L
< $GNGGA,221456.000,3733.005046,S,17515.621444,E,1,7,2.12,31.202,M,24.305,M,,*68
> R
< f49ae83e $GNGGA,221455.000,3733.001476,S,17515.618900,E,2,28,0.52,22.809,M,24.305,M,,*54 -62
> L
< $GNGGA,221458.000,3733.002940,S,17515.622206,E,1,7,1.78,30.011,M,24.305,M,,*63
> R
< f49ae83e $GNGGA,221457.000,3733.001488,S,17515.618912,E,2,28,0.52,22.926,M,24.306,M,,*5B -61
> L
< $GNGGA,221500.000,3733.000834,S,17515.620988,E,1,7,1.78,28.586,M,24.306,M,,*61
> R
< f49ae83e $GNGGA,221459.000,3733.001512,S,17515.618942,E,2,28,0.52,22.996,M,24.305,M,,*5A -63
> L
< $GNGGA,221502.000,3732.999850,S,17515.619932,E,1,8,1.40,29.125,M,24.306,M,,*6A
"""
        with open(self.log_file, 'w') as f:
            f.write(log_content)
    
    def test_full_pipeline_remote_only(self):
        """Test full pipeline with remote data only."""
        # Parse log file
        parser = LogParser(self.log_file, verbose=False)
        self.assertTrue(parser.read_log_file())
        self.assertTrue(parser.parse())
        
        # Get responses
        remote_responses = parser.get_remote_responses()
        self.assertGreater(len(remote_responses), 0)
        
        # Process data
        processor = DataProcessor(verbose=False)
        remote_df = processor.process_remote_responses(remote_responses)
        
        self.assertFalse(remote_df.empty)
        self.assertIn('uid', remote_df.columns)
        self.assertIn('latitude', remote_df.columns)
        self.assertIn('longitude', remote_df.columns)
        self.assertIn('altitude', remote_df.columns)
        self.assertIn('rssi', remote_df.columns)
        
        # Generate KML
        output_file = os.path.join(self.test_dir, 'output.kml')
        kml_gen = KMLGenerator(verbose=False)
        success = kml_gen.generate_remote_track_kml(remote_df, output_file)
        
        self.assertTrue(success)
        self.assertTrue(os.path.exists(output_file))
        
        # Verify KML is valid XML
        with open(output_file, 'r') as f:
            content = f.read()
            self.assertTrue(content.startswith('<?xml'))
            self.assertIn('<kml', content)
            self.assertIn('</kml>', content)
    
    def test_full_pipeline_with_filtering(self):
        """Test full pipeline with quality filtering."""
        # Parse log file
        parser = LogParser(self.log_file, verbose=False)
        parser.read_log_file()
        parser.parse()
        
        # Process data with filtering
        processor = DataProcessor(verbose=False)
        remote_df = processor.process_remote_responses(
            parser.get_remote_responses(),
            min_hdop=2.0,
            min_rssi=-80
        )
        
        # Verify filtering was applied
        if not remote_df.empty:
            self.assertTrue(all(remote_df['hdop'] <= 2.0))
            self.assertTrue(all(remote_df['rssi'] >= -80))
    
    def test_full_pipeline_with_local_data(self):
        """Test full pipeline with both local and remote data."""
        # Parse log file
        parser = LogParser(self.log_file, verbose=False)
        parser.read_log_file()
        parser.parse()
        
        # Process both remote and local data
        processor = DataProcessor(verbose=False)
        remote_df = processor.process_remote_responses(parser.get_remote_responses())
        local_df = processor.process_local_responses(parser.get_local_responses())
        
        # Both should have data
        self.assertFalse(remote_df.empty)
        self.assertFalse(local_df.empty)
        
        # Generate comparison KML
        output_file = os.path.join(self.test_dir, 'comparison.kml')
        kml_gen = KMLGenerator(verbose=False)
        success = kml_gen.generate_comparison_kml(remote_df, local_df, output_file)
        
        self.assertTrue(success)
        self.assertTrue(os.path.exists(output_file))
    
    def test_duplicate_point_removal(self):
        """Test that completely duplicate GPS points (entire response identical) are removed."""
        processor = DataProcessor(verbose=False)
        
        # Create test data with duplicate points (entire row identical)
        data = {
            'uid': ['device001', 'device001', 'device001', 'device001'],
            'timestamp': ['100000.000', '100000.000', '100002.000', '100003.000'],
            'latitude': [-37.55, -37.55, -37.56, -37.56],
            'longitude': [175.26, 175.26, 175.27, 175.27],
            'altitude': [100.0, 100.0, 105.0, 110.0],  # Last point different
            'fix_quality': [1, 1, 1, 1],
            'num_satellites': [10, 10, 10, 10],
            'hdop': [1.0, 1.0, 1.0, 1.0],
            'rssi': [-70, -70, -70, -70],
            'raw_gngga': ['', '', '', '']
        }
        df = pd.DataFrame(data)
        
        # Remove duplicates
        result = processor._remove_duplicate_points(df)
        
        # Should have 3 points (duplicate at index 1 removed)
        # Rows 0 and 1 are identical, so one is removed
        self.assertEqual(len(result), 3)
        # The first occurrence is kept, so timestamps should be 100000, 100002, 100003
        self.assertEqual(result.iloc[0]['timestamp'], '100000.000')
        self.assertEqual(result.iloc[1]['timestamp'], '100002.000')
        self.assertEqual(result.iloc[2]['timestamp'], '100003.000')


if __name__ == '__main__':
    unittest.main()
