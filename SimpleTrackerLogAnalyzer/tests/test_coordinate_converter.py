"""
Unit tests for coordinate converter module.
"""

import unittest
from modules.coordinate_converter import CoordinateConverter


class TestCoordinateConversion(unittest.TestCase):
    """Test NMEA to decimal coordinate conversion."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.converter = CoordinateConverter()
    
    def test_latitude_south_conversion(self):
        """Test conversion of southern hemisphere latitude."""
        # 3733.001470,S = -37 degrees 33.001470 minutes = -37.5500245
        result = self.converter.nmea_to_decimal("3733.001470", "S")
        
        self.assertIsNotNone(result)
        self.assertAlmostEqual(result, -37.5500245, places=6)
    
    def test_latitude_north_conversion(self):
        """Test conversion of northern hemisphere latitude."""
        # 4000.000000,N = 40 degrees 0 minutes = 40.0
        result = self.converter.nmea_to_decimal("4000.000000", "N")
        
        self.assertIsNotNone(result)
        self.assertAlmostEqual(result, 40.0, places=6)
    
    def test_longitude_east_conversion(self):
        """Test conversion of eastern hemisphere longitude."""
        # 17515.618888,E = 175 degrees 15.618888 minutes = 175.2603147
        result = self.converter.nmea_to_decimal("17515.618888", "E")
        
        self.assertIsNotNone(result)
        self.assertAlmostEqual(result, 175.2603147, places=6)
    
    def test_longitude_west_conversion(self):
        """Test conversion of western hemisphere longitude."""
        # 12015.000000,W = -120 degrees 15 minutes = -120.25
        result = self.converter.nmea_to_decimal("12015.000000", "W")
        
        self.assertIsNotNone(result)
        self.assertAlmostEqual(result, -120.25, places=6)
    
    def test_invalid_direction(self):
        """Test rejection of invalid direction."""
        result = self.converter.nmea_to_decimal("3733.001470", "X")
        
        self.assertIsNone(result)
    
    def test_empty_value(self):
        """Test rejection of empty coordinate."""
        result = self.converter.nmea_to_decimal("", "S")
        
        self.assertIsNone(result)
    
    def test_non_numeric_value(self):
        """Test rejection of non-numeric coordinate."""
        result = self.converter.nmea_to_decimal("ABC0.000000", "S")
        
        self.assertIsNone(result)
    
    def test_minutes_greater_than_60(self):
        """Test handling of invalid minutes (should not occur in valid NMEA)."""
        # This should still convert, as we don't validate the range
        result = self.converter.nmea_to_decimal("3761.000000", "S")
        
        self.assertIsNotNone(result)
        # 37 + 61/60 = 38.0167
        self.assertAlmostEqual(result, -38.0167, places=4)


class TestTimeConversion(unittest.TestCase):
    """Test NMEA time string conversion."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.converter = CoordinateConverter()
    
    def test_simple_time_conversion(self):
        """Test conversion of simple time."""
        # 22:14:51.116 = (22*3600) + (14*60) + 51.116 = 80091.116 seconds
        result = self.converter.time_string_to_seconds("221451.116")
        
        self.assertIsNotNone(result)
        self.assertAlmostEqual(result, 80091.116, places=3)
    
    def test_midnight_time_conversion(self):
        """Test conversion of midnight."""
        result = self.converter.time_string_to_seconds("000000.000")
        
        self.assertIsNotNone(result)
        self.assertAlmostEqual(result, 0.0, places=3)
    
    def test_noon_time_conversion(self):
        """Test conversion of noon."""
        # 12:00:00.000 = 43200 seconds
        result = self.converter.time_string_to_seconds("120000.000")
        
        self.assertIsNotNone(result)
        self.assertAlmostEqual(result, 43200.0, places=3)
    
    def test_invalid_time_format(self):
        """Test rejection of invalid time format."""
        result = self.converter.time_string_to_seconds("12")
        
        self.assertIsNone(result)
    
    def test_empty_time(self):
        """Test rejection of empty time."""
        result = self.converter.time_string_to_seconds("")
        
        self.assertIsNone(result)
    
    def test_non_numeric_time(self):
        """Test rejection of non-numeric time."""
        result = self.converter.time_string_to_seconds("AB:CD:EF")
        
        self.assertIsNone(result)


if __name__ == '__main__':
    unittest.main()
