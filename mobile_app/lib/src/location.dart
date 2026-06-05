/*
===============================================================================
TapCall — Geolocation Service
===============================================================================

Purpose:
- Manages GPS location access and permissions for elderly users
- Provides weather-based features that depend on current coordinates
- Handles location permission requests with user-friendly explanations
- Ensures graceful fallback when location is unavailable

Location Use Cases:
1. Weather Service: Fetches weather data for current location (temperature, rain, wind)
2. Emergency Features: Could be used for SOS location sharing (future)
3. Local Services: Foundation for location-based reminders or nearby contacts

Permission Flow (Android):
- App requests fine location (GPS) and coarse location (network-based)
- User grants/denies permission via system dialog
- If denied, app gracefully continues without location features
- User can manually enable in Settings → Permissions → Location

Location Accuracy Modes:
- BEST: High accuracy (GPS + network) - battery intensive, ~10m accuracy
- HIGH: GPS + network - moderate battery impact
- BALANCED: GPS + network with optimization - recommended for most apps
- LOW: Network-based only - low battery impact, ~100m accuracy
- LOWEST: No location (for testing)
- MEDIUM: Balanced approach used here - good for weather service

Error Handling Strategy:
- Permission denied: Returns null silently (features requiring location are disabled)
- Location service disabled: Returns false from isLocationServiceEnabled()
- Network/GPS error: Catches exception, returns null, logs error
- Timeout: Geolocator has default 30s timeout per location request

Dependencies:
- geolocator: Cross-platform GPS location access
- permission_handler: Unified permission request UI (Android/iOS)

Android Permissions (pubspec.yaml/AndroidManifest.xml):
- ACCESS_FINE_LOCATION: Precise GPS coordinates
- ACCESS_COARSE_LOCATION: Network-based location (fallback)
- ACCESS_BACKGROUND_LOCATION: Not used (not needed for this app)

Usage Example:
  final location = Location();
  
  // Check if location is available
  final enabled = await location.isLocationServiceEnabled();
  if (!enabled) {
    await location.openSettings();  // Direct user to Settings
    return;
  }
  
  // Request permission if needed
  final hasPermission = await location.checkPermission();
  if (!hasPermission) {
    final granted = await location.requestPermission();
    if (!granted) return;
  }
  
  // Get current location
  final position = await location.getCurrentLocation();
  if (position != null) {
    final weather = await weather.getWeatherDescription(position);
  }
*/

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Singleton service for GPS location access and permission management
/// 
/// Provides unified interface for:
/// - Checking location permission status
/// - Requesting location permission from user
/// - Retrieving current GPS coordinates
/// - Checking if location service is enabled on device
class Location {
  /// Static singleton instance - ensures only one location handler exists
  static final Location _instance = Location._internal();
  
  /// Factory constructor returns the singleton instance
  factory Location() => _instance;
  
  /// Private constructor prevents external instantiation
  Location._internal();

  /// Checks if app has been granted location permission
  /// 
  /// Process:
  /// 1. Queries permission_handler for current location permission status
  /// 2. Returns boolean: true if permission granted, false otherwise
  /// 3. Does NOT request permission - just checks current status
  /// 
  /// Returns:
  ///   true: User has previously granted location permission
  ///   false: Permission not yet granted or was denied
  /// 
  /// Note:
  ///   - On Android: Checks both fine (GPS) and coarse (network) location permissions
  ///   - Permission can be revoked by user in Settings at any time
  ///   - First call on new install returns false (permission never granted)
  /// 
  /// Usage:
  ///   final hasPermission = await location.checkPermission();
  ///   if (!hasPermission) {
  ///     await location.requestPermission();  // Prompt user
  ///   }
  Future<bool> checkPermission() async {
    try {
      // Query current location permission status
      // Permission.location covers both fine (GPS) and coarse (network) location
      final status = await Permission.location.status;
      
      // Check if permission is granted
      // status.isGranted is true only if user explicitly granted it
      return status.isGranted;
    } catch (e) {
      // Permission check should rarely fail, but handle gracefully
      return false;
    }
  }

  /// Requests location permission from user via system dialog
  /// 
  /// Process:
  /// 1. Check current permission status
  /// 2. If already granted, return true immediately (no dialog shown)
  /// 3. If not granted, show system permission request dialog
  /// 4. Dialog explains: "This app needs your location for weather information"
  /// 5. User taps Allow/Deny
  /// 6. Return result (true if granted, false if denied)
  /// 
  /// Returns:
  ///   true: Permission granted after this request
  ///   false: Permission denied or already denied (don't ask again)
  /// 
  /// Important Notes:
  ///   - Only shown once per install - if user denies and clears app data, shows again
  ///   - If user selects "Don't ask again", future requests silently return false
  ///   - User can always grant in Settings → Apps → TapCall → Permissions → Location
  /// 
  /// Usage:
  ///   final granted = await location.requestPermission();
  ///   if (granted) {
  ///     final position = await location.getCurrentLocation();
  ///   } else {
  ///     print('Location permission denied');
  ///   }
  Future<bool> requestPermission() async {
    try {
      // Request location permission from user
      // Shows system dialog asking for permission
      // Waits for user response (Allow/Deny/Don't Ask Again)
      final status = await Permission.location.request();
      
      // Return true only if explicitly granted
      return status.isGranted;
    } catch (e) {
      // Handle any permission request errors
      return false;
    }
  }

  /// Opens device Settings app to location permission screen
  /// 
  /// When to Use:
  /// - User denied location permission and needs to enable it
  /// - Direct user to Settings where they can manually grant permission
  /// - After user enables in Settings, they must re-launch app
  /// 
  /// Process:
  /// 1. Opens device Settings app
  /// 2. Attempts to navigate directly to app's permission settings
  /// 3. User taps Location permission toggle
  /// 4. Returns to TapCall app (user must trigger location again)
  /// 
  /// Android Behavior:
  /// - Navigates to: Settings → Apps → TapCall → Permissions → Location
  /// - User can toggle Location on/off
  /// - Some devices show custom permission dialogs
  /// 
  /// iOS Behavior:
  /// - Opens: Settings → Privacy → Location Services
  /// - User selects app and chooses: Never/While Using/Always
  /// 
  /// Usage:
  ///   if (!await location.checkPermission()) {
  ///     await location.openSettings();  // User manually enables
  ///   }
  Future<void> openSettings() async {
    try {
      // Opens device settings app to location permission screen
      // Handles platform differences (Android/iOS) automatically
      await openAppSettings();
    } catch (e) {
      // Settings might fail on some devices - log and continue
    }
  }

  /// Retrieves current device location (latitude/longitude)
  /// 
  /// Full Permission & Location Workflow:
  /// 1. Check if location permission is granted
  /// 2. If not granted, return null (skip location features)
  /// 3. Call Geolocator.getCurrentPosition() with MEDIUM accuracy
  /// 4. Wait up to ~30 seconds for GPS fix
  /// 5. Return Position object with lat/long or null if timeout
  /// 
  /// Returns:
  ///   Position object containing:
  ///     - latitude: Decimal degrees (-90 to 90)
  ///     - longitude: Decimal degrees (-180 to 180)
  ///     - altitude: Height above sea level (meters)
  ///     - accuracy: Estimated accuracy radius (meters)
  ///     - speed: Current speed (m/s) if device is moving
  ///     - heading: Direction of movement (degrees)
  ///   null: If permission denied, location service disabled, or GPS timeout
  /// 
  /// Accuracy Mode: LocationAccuracy.medium
  ///   - Balanced between battery consumption and accuracy
  ///   - Uses GPS + network triangulation if available
  ///   - Typical accuracy: 10-100 meters
  ///   - Sufficient for weather data (OpenMeteo works with ±1km accuracy)
  /// 
  /// Error Cases Handled:
  ///   - Permission denied: Returns null silently
  ///   - Location service disabled on device: Returns null silently
  ///   - GPS timeout (no satellite fix for 30s): Returns null
  ///   - Network error: Returns null
  ///   - No available location (in tunnel, underground): Returns null
  /// 
  /// Performance:
  ///   - First location request: May take 5-30 seconds (acquiring GPS fix)
  ///   - Subsequent requests: Often faster (cached satellite signals)
  ///   - Outdoor/clear sky: Typically 10-15 seconds
  ///   - Indoor/urban canyon: May timeout (uses network fallback)
  /// 
  /// Usage:
  ///   final position = await location.getCurrentLocation();
  ///   if (position != null) {
  ///     print('Lat: ${position.latitude}, Lon: ${position.longitude}');
  ///     final weather = await weather.getWeatherDescription(position);
  ///   } else {
  ///     print('Location unavailable');
  ///   }
  Future<Position?> getCurrentLocation() async {
    try {
      // First check: Do we have permission to access location?
      // Skip entire location request if permission denied (saves battery)
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        return null;
      }

      // Request current device position from Geolocator
      // Parameters:
      // - desiredAccuracy: MEDIUM = 100-500m accuracy (balanced for weather)
      // - Other options: LOWEST, LOW, HIGH, BEST (lower = faster, higher = accurate)
      // Timeout is handled by Geolocator default (typically 30 seconds)
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      
      // Return Position object with coordinates
      return position;
      
    } catch (e) {
      // Catch all location errors:
      // - Permission actually denied at OS level (shouldn't happen if checkPermission passed)
      // - Location service disabled on device
      // - GPS timeout (no satellite fix)
      // - Network unavailable
      // - Device in airplane mode
      return null;
    }
  }

  /// Checks if location service is enabled on device
  /// 
  /// What This Checks:
  /// - NOT whether permission is granted
  /// - Whether location services are turned ON in device Settings
  /// - On Android: Settings → Location → Location Services toggle
  /// - On iOS: Settings → Privacy → Location Services toggle
  /// 
  /// Why Check This:
  /// - Even with permission, location might be disabled in Settings
  /// - Geolocator.getCurrentPosition() will timeout if service disabled
  /// - Useful to warn user before attempting location request
  /// 
  /// Returns:
  ///   true: Location services enabled on device
  ///   false: Location services disabled (user must enable in Settings)
  /// 
  /// Error Handling:
  /// - Platform errors: Catches and returns false
  /// - Rare failures: Treats as "disabled" to be safe
  /// 
  /// Usage:
  ///   final enabled = await location.isLocationServiceEnabled();
  ///   if (!enabled) {
  ///     // Show dialog: "Please enable Location in Settings"
  ///     await location.openSettings();
  ///     return;
  ///   }
  Future<bool> isLocationServiceEnabled() async {
    try {
      // Query Geolocator for location service status
      // Returns true if GPS/network location is enabled on device
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      // If we can't check, assume disabled to avoid errors
      return false;
    }
  }
}
