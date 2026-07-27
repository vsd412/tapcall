/*
===============================================================================
TapCall — Weather Service
===============================================================================

Purpose:
- Fetches real-time weather data from Open-Meteo API (free, no auth required)
- Provides localized weather descriptions for TTS announcements
- Supports Cantonese, Mandarin, and English

API Details:
- Endpoint: https://api.open-meteo.com/v1/forecast
- Parameters: latitude, longitude, current weather variables
- Returns: temperature (°C), WMO weather code, wind speed (km/h)
- No rate limits for reasonable usage

Data Flow:
1. MainCallScreen calls getWeatherDescription() with GPS coordinates
2. HTTP GET request to Open-Meteo with lat/long
3. Parse JSON response for current weather conditions
4. Map WMO weather code to human-readable description
5. Build localized sentence based on TTS language setting
6. Return formatted string for voice announcement

WMO Weather Codes (World Meteorological Organization):
- 0: Clear sky
- 1-3: Partly cloudy to overcast
- 45-48: Fog
- 51-57: Drizzle
- 61-67: Rain
- 71-77: Snow
- 80-82: Rain showers
- 85-86: Snow showers
- 95-99: Thunderstorm

Error Handling:
- Returns null if HTTP request fails
- Returns null if JSON parsing fails
- Caller (MainCallScreen) announces fallback message via TTS

Design Pattern:
- Singleton: One instance shared across app
- Factory constructor ensures single instance
- Private constructor prevents external instantiation

Dependencies:
- http: HTTP client for API requests
- geolocator: GPS Position object with lat/long
- language_helper: Current TTS language setting

Usage Example:
  final weather = Weather();
  final position = await Geolocator.getCurrentPosition();
  final description = await weather.getWeatherDescription(position);
  if (description != null) {
    await tts.speak(description);
  }
*/

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'language.dart';

/// Singleton service for fetching and formatting weather data
class Weather {
  // Singleton implementation: ensures only one instance exists
  static final Weather _instance = Weather._internal();
  
  /// Factory constructor returns the singleton instance
  factory Weather() => _instance;
  
  /// Private constructor prevents external instantiation
  Weather._internal();

  /// Open-Meteo API base URL (free tier, no API key needed)
  /// Documentation: https://open-meteo.com/en/docs
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Fetches current weather and returns a localized TTS-ready sentence
  /// 
  /// Parameters:
  ///   position: GPS coordinates from Geolocator (latitude/longitude)
  /// 
  /// Returns:
  ///   String: Localized weather announcement (e.g., "现在天气是晴天，气温25度...")
  ///   null: If HTTP request fails or response is invalid
  /// 
  /// API Response Format:
  ///   {
  ///     "current": {
  ///       "temperature_2m": 25.3,
  ///       "weathercode": 0,
  ///       "windspeed_10m": 12.5
  ///     }
  ///   }
  Future<String?> getWeatherDescription(Position position) async {
    try {
      // Build API request URL with query parameters
      // - latitude/longitude: GPS coordinates
      // - current: fields to fetch (temp, weather code, wind speed)
      // - temperature_unit: celsius (default is celsius anyway)
      // - windspeed_unit: km/h
      // - timezone: auto (uses location's timezone)
      final url = Uri.parse(
        '$_baseUrl'
        '?latitude=${position.latitude}'
        '&longitude=${position.longitude}'
        '&current=temperature_2m,weathercode,windspeed_10m'
        '&temperature_unit=celsius'
        '&windspeed_unit=kmh'
        '&timezone=auto'
      );

      // Execute HTTP GET request with 10-second timeout
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          // Return a mock response to trigger null return below
          return http.Response('Timeout', 408);
        },
      );
      
      // Check if request succeeded (HTTP 200 OK)
      if (response.statusCode == 200) {
        // Parse JSON response body
        final data = json.decode(response.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>;
        
        // Extract weather metrics from response
        // temperature_2m: temperature at 2 meters above ground (°C)
        // weathercode: WMO weather interpretation code (0-99)
        // windspeed_10m: wind speed at 10 meters above ground (km/h)
        final temp = current['temperature_2m'] as num;
        final weatherCode = current['weathercode'] as int;
        final windSpeed = current['windspeed_10m'] as num;
        
        // Convert WMO code to human-readable description
        final weatherDesc = await _getWeatherDescription(weatherCode);
        
        // Get current TTS language setting to build localized sentence
        final language = await Language.getLanguage();
        
        // Build language-specific announcement sentence
        // Round decimals to whole numbers for clearer speech
        // Add elderly-specific advisories based on conditions
        final advisory = await _getElderlyAdvisory(temp.round(), weatherCode);
        
        switch (language) {
          case TTSLanguage.traditionalChinese:
            // Traditional Chinese (formal written style)
            return '現在天氣$weatherDesc，'
                   '溫度${temp.round()}度，'
                   '風速每小時${windSpeed.round()}公里。'
                   '$advisory';
          
          case TTSLanguage.simplifiedChinese:
            // Simplified Chinese (formal written style)
            return '现在天气$weatherDesc，'
                   '温度${temp.round()}度，'
                   '风速每小时${windSpeed.round()}公里。'
                   '$advisory';
          
          case TTSLanguage.english:
            // English: "The current weather is [desc]. Temperature is [X] degrees Celsius. Wind speed is [Y] kilometers per hour."
            return 'The current weather is $weatherDesc. '
                   'Temperature is ${temp.round()} degrees Celsius. '
                   'Wind speed is ${windSpeed.round()} kilometers per hour.';
        }
      }
      
      // HTTP request failed (non-200 status code)
      return null;
      
    } catch (e) {
      // Handle any errors:
      // - Network errors (no internet, DNS failure)
      // - JSON parsing errors (unexpected response format)
      // - Timeout errors
      // Error is already handled by returning null; caller will announce fallback message
      return null;
    }
  }

  /// Generates elderly-specific health advisories based on weather conditions
  /// 
  /// Parameters:
  ///   temp: Temperature in Celsius
  ///   code: WMO weather code
  /// 
  /// Returns:
  ///   String: Advisory message for elderly care (empty string if no advisory needed)
  /// 
  /// Advisory Triggers:
  ///   Temperature < 15°C: Remind to wear more clothes
  ///   Temperature > 30°C: Remind to stay hydrated
  ///   Rain/Thunderstorm: Remind to bring umbrella
  ///   Strong wind (implied by certain weather codes): Remind to be careful outdoors
  Future<String> _getElderlyAdvisory(int temp, int code) async {
    final language = await Language.getLanguage();
    final advisories = <String>[];
    
    // Temperature-based advisories
    if (temp < 15) {
      // Cold weather - remind to dress warmly
      switch (language) {
        case TTSLanguage.traditionalChinese:
          advisories.add('請注意保暖，多穿衣服');
          break;
        case TTSLanguage.simplifiedChinese:
          advisories.add('请注意保暖，多穿衣服');
          break;
        case TTSLanguage.english:
          advisories.add('Please dress warmly');
          break;
      }
    } else if (temp > 30) {
      // Hot weather - remind to stay hydrated
      switch (language) {
        case TTSLanguage.traditionalChinese:
          advisories.add('天氣炎熱，請多喝水');
          break;
        case TTSLanguage.simplifiedChinese:
          advisories.add('天气炎热，请多喝水');
          break;
        case TTSLanguage.english:
          advisories.add('Stay hydrated in the heat');
          break;
      }
    }
    
    // Weather condition-based advisories
    if (code >= 51 && code <= 67) {
      // Rain - remind to bring umbrella
      switch (language) {
        case TTSLanguage.traditionalChinese:
          advisories.add('記得帶雨傘');
          break;
        case TTSLanguage.simplifiedChinese:
          advisories.add('记得带雨伞');
          break;
        case TTSLanguage.english:
          advisories.add('Remember to bring an umbrella');
          break;
      }
    } else if (code >= 80 && code <= 82) {
      // Rain showers - remind about umbrella
      switch (language) {
        case TTSLanguage.traditionalChinese:
          advisories.add('可能有陣雨，帶雨傘較好');
          break;
        case TTSLanguage.simplifiedChinese:
          advisories.add('可能有阵雨，带雨伞较好');
          break;
        case TTSLanguage.english:
          advisories.add('Possible showers, bring an umbrella');
          break;
      }
    } else if (code >= 95) {
      // Thunderstorm - remind to stay indoors
      switch (language) {
        case TTSLanguage.traditionalChinese:
          advisories.add('有雷暴，盡量留在室內');
          break;
        case TTSLanguage.simplifiedChinese:
          advisories.add('有雷暴，尽量留在室内');
          break;
        case TTSLanguage.english:
          advisories.add('Thunderstorms expected, stay indoors if possible');
          break;
      }
    }
    
    // Return combined advisories with proper punctuation
    if (advisories.isEmpty) {
      return '';
    } else {
      return '${advisories.join('，')}。';
    }
  }

  /// Maps WMO weather code to localized human-readable description
  /// 
  /// Parameters:
  ///   code: WMO weather interpretation code (0-99)
  /// 
  /// Returns:
  ///   Localized weather condition string (e.g., "晴朗", "clear sky")
  /// 
  /// WMO Code Ranges:
  ///   0: Clear sky
  ///   1-3: Mainly clear to overcast
  ///   45-48: Fog and depositing rime fog
  ///   51-57: Drizzle (light to heavy)
  ///   61-67: Rain (slight to heavy)
  ///   71-77: Snow (slight to heavy)
  ///   80-82: Rain showers (slight to violent)
  ///   85-86: Snow showers (slight to heavy)
  ///   95-99: Thunderstorm (with or without hail)
  /// 
  /// Reference: https://open-meteo.com/en/docs (Weather Code section)
  Future<String> _getWeatherDescription(int code) async {
    // Fetch current TTS language setting
    final language = await Language.getLanguage();
    
    // Map WMO code to localized description
    // Uses range-based checks for code groups (e.g., 1-3 = cloudy)
    switch (language) {
      case TTSLanguage.traditionalChinese:
        // Traditional Chinese (formal written style)
        if (code == 0) return '晴朗';      // Clear/sunny
        if (code <= 3) return '多雲';      // Cloudy
        if (code <= 48) return '有霧';     // Foggy
        if (code <= 57) return '小雨';     // Drizzle
        if (code <= 67) return '下雨';     // Raining
        if (code <= 77) return '下雪';     // Snowing
        if (code <= 82) return '陣雨';     // Showers
        if (code <= 86) return '雪陣';     // Snow showers
        if (code <= 99) return '雷暴';     // Thunderstorm
        return '天氣不明';                 // Unknown
        
      case TTSLanguage.simplifiedChinese:
        // Simplified Chinese (formal written style)
        if (code == 0) return '晴朗';      // Clear/sunny
        if (code <= 3) return '多云';      // Cloudy
        if (code <= 48) return '有雾';     // Foggy
        if (code <= 57) return '小雨';     // Drizzle
        if (code <= 67) return '下雨';     // Raining
        if (code <= 77) return '下雪';     // Snowing
        if (code <= 82) return '阵雨';     // Showers
        if (code <= 86) return '雪阵';     // Snow showers
        if (code <= 99) return '雷暴';     // Thunderstorm
        return '天气不明';                 // Unknown
        
      case TTSLanguage.english:
        // English weather descriptions
        if (code == 0) return 'clear sky';        // Clear
        if (code <= 3) return 'partly cloudy';    // Cloudy
        if (code <= 48) return 'foggy';           // Fog
        if (code <= 57) return 'drizzling';       // Drizzle
        if (code <= 67) return 'rainy';           // Rain
        if (code <= 77) return 'snowy';           // Snow
        if (code <= 82) return 'showery';         // Showers
        if (code <= 86) return 'snowy showers';   // Snow showers
        if (code <= 99) return 'thunderstorms';   // Thunderstorm
        return 'unknown conditions';              // Unknown
    }
  }
}
