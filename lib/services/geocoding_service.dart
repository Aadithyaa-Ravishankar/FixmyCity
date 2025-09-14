import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/reverse';
  
  // Cache to store already fetched addresses to avoid repeated API calls
  static final Map<String, String> _addressCache = {};
  
  static Future<String> getAddressFromCoordinates(double lat, double lon) async {
    // Trim coordinates to 4 decimal places for better API compatibility
    final trimmedLat = double.parse(lat.toStringAsFixed(4));
    final trimmedLon = double.parse(lon.toStringAsFixed(4));
    
    // Create a cache key from trimmed coordinates
    final cacheKey = '${trimmedLat.toStringAsFixed(4)},${trimmedLon.toStringAsFixed(4)}';
    
    // Return cached address if available
    if (_addressCache.containsKey(cacheKey)) {
      return _addressCache[cacheKey]!;
    }
    
    try {
      final url = Uri.parse('$_baseUrl?lat=$trimmedLat&lon=$trimmedLon&format=json');
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'FixmyCity/1.0 (civic engagement app)',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Check if API returned an error
        if (data['error'] != null) {
          print('Geocoding API error: ${data['error']}');
          return 'Lat: ${trimmedLat.toStringAsFixed(4)}, Long: ${trimmedLon.toStringAsFixed(4)}';
        }
        
        // Extract address components
        final displayName = data['display_name'] as String?;
        final address = data['address'] as Map<String, dynamic>?;
        
        String formattedAddress;
        
        // Simplified address parsing - prioritize display_name first
        if (displayName != null && displayName.isNotEmpty) {
          // Use display name and truncate to first 3 parts for readability
          final parts = displayName.split(', ');
          formattedAddress = parts.take(3).join(', ');
        } else if (address != null) {
          // Build a concise address from components as fallback
          List<String> addressParts = [];
          
          // Try different combinations of address components
          final possibleParts = [
            address['road'],
            address['suburb'] ?? address['neighbourhood'],
            address['city'] ?? address['town'] ?? address['village'],
            address['state']
          ];
          
          for (final part in possibleParts) {
            if (part != null && part.toString().isNotEmpty) {
              addressParts.add(part.toString());
            }
          }
          
          if (addressParts.isNotEmpty) {
            formattedAddress = addressParts.take(3).join(', ');
          } else {
            formattedAddress = 'Lat: ${trimmedLat.toStringAsFixed(4)}, Long: ${trimmedLon.toStringAsFixed(4)}';
          }
        } else {
          formattedAddress = 'Lat: ${trimmedLat.toStringAsFixed(4)}, Long: ${trimmedLon.toStringAsFixed(4)}';
        }
        
        // Cache the result
        _addressCache[cacheKey] = formattedAddress;
        return formattedAddress;
        
      } else {
        print('Geocoding API error: ${response.statusCode}');
        return 'Location unavailable';
      }
    } catch (e) {
      print('Error fetching address: $e');
      return 'Location unavailable';
    }
  }
  
  // Clear cache if needed (useful for memory management)
  static void clearCache() {
    _addressCache.clear();
  }
}
