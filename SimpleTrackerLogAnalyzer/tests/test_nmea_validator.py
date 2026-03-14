"""
Unit tests for NMEA validator module.
"""

import unittest
from modules.nmea_validator import (
    NMEAValidator,
    extract_gngga_from_remote_response,
    extract_rssi_from_remote_response,
    extract_uid_from_remote_response
)


class TestNMEAChecksum(unittest.TestCase):
    """Test NMEA checksum validation."""
    
    def test_valid_checksum(self):
        """Test validation of valid GNGGA sentence."""
        sentence = "$GNGGA,221451.116,,,,,0,0,,,M,,M,,*51"
        self.assertTrue(NMEAValidator.validate_checksum(sentence))
    
    def test_valid_checksum_with_data(self):
        """Test validation of valid GNGGA with position data."""
        sentence = "$GNGGA,221453.000,3733.001470,S,17515.618888,E,2,28,0.52,22.729,M,24.306,M,,*5B"
        self.assertTrue(NMEAValidator.validate_checksum(sentence))
    
    def test_invalid_checksum(self):
        """Test detection of invalid checksum."""
        sentence = "$GNGGA,221451.116,,,,,0,0,,,M,,M,,*00"
        self.assertFalse(NMEAValidator.validate_checksum(sentence))
    
    def test_missing_checksum(self):
        """Test rejection of sentence without checksum."""
        sentence = "$GNGGA,221451.116,,,,,0,0,,,M,,M,,"
        self.assertFalse(NMEAValidator.validate_checksum(sentence))
    
    def test_malformed_sentence(self):
        """Test rejection of malformed sentence."""
        sentence = "invalid data"
        self.assertFalse(NMEAValidator.validate_checksum(sentence))


class TestNMEAParsing(unittest.TestCase):
    """Test NMEA sentence parsing."""
    
    def test_parse_valid_sentence(self):
        """Test parsing of valid GNGGA sentence."""
        sentence = "$GNGGA,221453.000,3733.001470,S,17515.618888,E,2,28,0.52,22.729,M,24.306,M,,*5B"
        result = NMEAValidator.parse_gngga(sentence)
        
        self.assertIsNotNone(result)
        self.assertEqual(result['message_id'], 'GNGGA')
        self.assertEqual(result['utc_time'], '221453.000')
        self.assertEqual(result['latitude'], '3733.001470')
        self.assertEqual(result['lat_direction'], 'S')
        self.assertEqual(result['longitude'], '17515.618888')
        self.assertEqual(result['lon_direction'], 'E')
        self.assertEqual(result['fix_quality'], '2')
        self.assertEqual(result['num_satellites'], '28')
        self.assertEqual(result['altitude'], '22.729')
    
    def test_parse_no_fix_sentence(self):
        """Test rejection of sentence with no fix."""
        sentence = "$GNGGA,221451.116,,,,,0,0,,,M,,M,,*51"
        result = NMEAValidator.parse_gngga(sentence)
        
        # Should be rejected because fix_quality is 0 (no fix)
        self.assertIsNone(result)
    
    def test_parse_invalid_checksum(self):
        """Test rejection due to invalid checksum."""
        sentence = "$GNGGA,221453.000,3733.001470,S,17515.618888,E,2,28,0.52,22.729,M,24.306,M,,*00"
        result = NMEAValidator.parse_gngga(sentence)
        
        self.assertIsNone(result)
    
    def test_parse_missing_altitude(self):
        """Test rejection of sentence without altitude."""
        sentence = "$GNGGA,221453.000,3733.001470,S,17515.618888,E,2,28,0.52,,M,24.306,M,,*5B"
        result = NMEAValidator.parse_gngga(sentence)
        
        # Should be rejected because altitude is empty
        self.assertIsNone(result)


class TestRemoteResponseExtraction(unittest.TestCase):
    """Test extraction of data from remote responses."""
    
    def test_extract_gngga_from_remote(self):
        """Test GNGGA extraction from remote response."""
        response = "f49ae83e $GNGGA,221453.000,3733.001470,S,17515.618888,E,2,28,0.52,22.729,M,24.306,M,,*5B -63"
        gngga = extract_gngga_from_remote_response(response)
        
        self.assertIsNotNone(gngga)
        self.assertTrue(gngga.startswith('$GNGGA'))
        self.assertTrue('*5B' in gngga)
    
    def test_extract_rssi_from_remote(self):
        """Test RSSI extraction from remote response."""
        response = "f49ae83e $GNGGA,221453.000,3733.001470,S,17515.618888,E,2,28,0.52,22.729,M,24.306,M,,*5B -63"
        rssi = extract_rssi_from_remote_response(response)
        
        self.assertEqual(rssi, -63)
    
    def test_extract_rssi_no_value(self):
        """Test RSSI extraction when no RSSI present."""
        response = "f49ae83e $GNGGA,221453.000,3733.001470,S,17515.618888,E,2,28,0.52,22.729,M,24.306,M,,*5B"
        rssi = extract_rssi_from_remote_response(response)
        
        self.assertIsNone(rssi)
    
    def test_extract_uid_from_remote(self):
        """Test UID extraction from remote response."""
        response = "f49ae83e $GNGGA,221453.000,3733.001470,S,17515.618888,E,2,28,0.52,22.729,M,24.306,M,,*5B -63"
        uid = extract_uid_from_remote_response(response)
        
        self.assertEqual(uid, "f49ae83e")
    
    def test_extract_components_complete_response(self):
        """Test extraction of all components from complete response."""
        response = "f49ae83e $GNGGA,221453.000,3733.001470,S,17515.618888,E,2,28,0.52,22.729,M,24.306,M,,*5B -63"
        
        uid = extract_uid_from_remote_response(response)
        gngga = extract_gngga_from_remote_response(response)
        rssi = extract_rssi_from_remote_response(response)
        
        self.assertEqual(uid, "f49ae83e")
        self.assertIsNotNone(gngga)
        self.assertEqual(rssi, -63)


if __name__ == '__main__':
    unittest.main()
