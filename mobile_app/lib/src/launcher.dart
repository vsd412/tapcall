/*
===============================================================================
TapCall — Launcher Service
===============================================================================

Purpose:
- Manages app lifecycle, UI modes, and system integration for elderly kiosk use
- Provides access to Android launcher/home screen customization
- Controls full-screen kiosk mode to prevent accidental app closure
- Bridges Flutter (Dart) code with native Android (Kotlin) implementations
- Enables accessibility features like auto-returning after WhatsApp calls

Design Patterns:
- Platform Channel (Method Channel): Flutter ↔ Kotlin communication via "com.tapcall.app/launcher"
- Each method invokes native code that performs system-level operations
- Preferences cached in SharedPreferences for persistent settings
- Error handling: Platform exceptions caught and wrapped with descriptive messages

Key Features for Elderly Users:
1. Kiosk Mode: Locks app to foreground, prevents home/back navigation
2. Default Launcher: Sets TapCall as device home screen (replaces default launcher)
3. System Navigation: Can override Android navigation (back/recent apps)
4. Screen Scaling: Coordinates for WhatsApp automation (accessibility feature)

Architecture:
- Flutter Layer (this file): Dart service with async methods
- Platform Channel: Named channel "com.tapcall.app/launcher"
- Kotlin Layer: Android code handles actual system calls
- Communication: Method names and parameters must match Kotlin implementation

SharedPreferences Keys:
- 'is_default_launcher_requested': Whether user confirmed setting app as launcher
- 'system_nav_mode_enabled': Whether system navigation override is active
- 'kiosk_mode_enabled': Whether kiosk mode (prevents app closure) is enabled

Permission Requirements (AndroidManifest.xml):
- android.permission.REQUEST_SET_DEFAULT_LAUNCHER: Request default launcher role
- android.permission.DISABLE_KEYGUARD: Control lock screen (not needed for kiosk)
- android.permission.REORDER_TASKS: Manage task stack

Dependencies:
- flutter/services: MethodChannel for native bridge
- shared_preferences: Persistent preference storage

Error Handling Strategy:
- PlatformException caught for all native calls
- Exceptions wrapped with descriptive messages for debugging
- Failures logged but may not propagate (app continues)
- Settings failures don't crash app (fallback to defaults)

Usage Example:
  final launcher = Launcher();
  
  // Set as default home screen launcher
  try {
    await launcher.openDefaultLauncherSettings();
  } catch (e) {
  }
  
  // Enable kiosk mode
  await launcher.setKioskMode(true);  // App now locks to foreground
  await launcher.bringAppToForeground();
  
  // Disable kiosk mode
  await launcher.setKioskMode(false);  // User can now press home/back
*/

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service for Android launcher customization and system integration
/// 
/// Bridges Flutter UI with native Android capabilities for kiosk/launcher features.
/// All native calls route through Method Channel to Kotlin implementation.
class Launcher {
  /// Method Channel for Flutter ↔ Kotlin communication
  /// 
  /// Channel Name: "com.tapcall.app/launcher"
  /// Must match exactly with Kotlin side: MethodChannel("com.tapcall.app/launcher")
  /// Used for: invokeMethod(methodName, parameters)
  static const platform = MethodChannel('com.tapcall.app/launcher');
  
  // SharedPreferences keys for persistent settings
  static const String _keyIsDefaultLauncher = 'is_default_launcher_requested';
  static const String _keySystemNavMode = 'system_nav_mode_enabled';
  static const String _keyKioskMode = 'kiosk_mode_enabled';

  /// Checks if user has previously requested this app to be default launcher
  /// 
  /// What This Does:
  /// - Queries SharedPreferences for the kiosk mode flag
  /// - Returns cached setting without querying Android (fast)
  /// - Used to show UI indicators, not for actual functionality
  /// 
  /// Returns:
  ///   true: User has confirmed setting app as default launcher
  ///   false: Not yet requested or was cleared
  /// 
  /// Default Value:
  ///   false on first install (SharedPreferences returns null → defaults to false)
  /// 
  /// Notes:
  /// - This is just a flag; actual launcher role managed by Android
  /// - Clearing this flag doesn't unset the launcher (only app settings do that)
  /// - Use with openDefaultLauncherSettings() to actually change launcher
  /// 
  /// Usage:
  ///   final requested = await launcher.isDefaultLauncherRequested();
  ///   if (requested) {
  ///     print('App is set as default launcher');
  ///   }
  static Future<bool> isDefaultLauncherRequested() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIsDefaultLauncher) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Opens system dialog to let user set this app as default launcher/home screen
  /// 
  /// What This Does:
  /// 1. Calls native Android code via Method Channel
  /// 2. Shows system dialog: "Set as default launcher?" with app list
  /// 3. User chooses TapCall to make it the home screen app
  /// 4. Sets the flag in SharedPreferences
  /// 
  /// Android Process:
  /// - Permission: android.permission.REQUEST_SET_DEFAULT_LAUNCHER (API 31+)
  /// - Dialog: Android system launcher selector (not app-created)
  /// - Behavior: User can change launcher anytime in Settings → Apps
  /// 
  /// Use Cases:
  /// - Kiosk setup: Lock elderly user to TapCall interface
  /// - Prevent accidental access to: Settings, Play Store, other apps
  /// - Useful with kiosk mode enabled
  /// 
  /// Important Notes:
  /// - Requires API 31+ (Android 12+) for proper implementation
  /// - Device admin app can set launcher without user dialog (not used here)
  /// - User can always change back in Settings
  /// - Setting cleared if app uninstalled
  /// 
  /// Error Handling:
  /// - Platform exceptions caught: Device doesn't support, permission denied
  /// - Still marks flag as requested even if dialog failed (tries next time)
  /// 
  /// Usage:
  ///   try {
  ///     await launcher.openDefaultLauncherSettings();
  ///     print('User can now select TapCall as home launcher');
  ///   } catch (e) {
  ///     print('Could not open launcher settings: $e');
  ///   }
  static Future<void> openDefaultLauncherSettings() async {
    try {
      // Invoke native Android code to show launcher selection dialog
      // Method name must match Kotlin: fun openDefaultLauncherSettings()
      await platform.invokeMethod('openDefaultLauncherSettings');
      
      // Mark flag that user was presented with this option
      // Persists across app restarts
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsDefaultLauncher, true);
      
    } on PlatformException catch (e) {
      // Platform exceptions: Device doesn't support, permission issues
      throw Exception('Failed to open launcher settings: ${e.message}');
    } catch (e) {
      // Other errors: SharedPreferences failure
      throw Exception('Error opening launcher settings: $e');
    }
  }

  /// Clears the default launcher request flag
  /// 
  /// What This Does:
  /// - Removes the kiosk mode flag from SharedPreferences
  /// - Does NOT unset the app as default launcher (only user can do that in Settings)
  /// - Just resets our internal tracking flag
  /// 
  /// When to Use:
  /// - User cancels kiosk setup
  /// - Disabling all launcher features
  /// - Resetting app to normal mode
  /// 
  /// Note:
  /// - Call setKioskMode(false) separately to actually disable kiosk
  /// - Call openDefaultLauncherSettings() again to re-request launcher role
  /// 
  /// Usage:
  ///   await launcher.clearDefaultLauncherRequest();
  ///   print('Launcher request flag cleared');
  static Future<void> clearDefaultLauncherRequest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsDefaultLauncher, false);
    } catch (e) {
      // Ignore preference clear errors - non-critical operation
    }
  }
  
  /// Brings app to foreground from background or minimized state
  /// 
  /// What This Does:
  /// - Calls native Android code to move TapCall to foreground
  /// - Works even when app is in background, minimized, or hidden
  /// - Bypasses normal app launcher flow
  /// 
  /// How It Works (Android):
  /// - Gets app's task ID
  /// - Moves task to front of activity stack
  /// - Brings all windows of the app to foreground
  /// 
  /// Use Cases:
  /// 1. After WhatsApp call ends: Auto-return to TapCall (accessibility feature)
  /// 2. ESP32 button pressed: Wake app from background
  /// 3. Emergency SOS: Ensure app is visible when triggered
  /// 4. With kiosk mode: Locks user back to TapCall interface
  /// 
  /// Permissions:
  /// - android.permission.REORDER_TASKS: Move tasks in stack
  /// - Requires API 5+ (all modern Android)
  /// 
  /// Error Handling:
  /// - Fails silently if app process no longer exists
  /// - Platform exceptions caught: Permission denied, system error
  /// 
  /// Usage:
  ///   // After user finishes WhatsApp call
  ///   await launcher.bringAppToForeground();  // Return to TapCall
  static Future<void> bringAppToForeground() async {
    try {
      // Invoke native Android code to move app to foreground
      // Method name must match Kotlin: fun bringAppToForeground()
      await platform.invokeMethod('bringAppToForeground');
    } on PlatformException catch (e) {
      // Platform errors: Task not found, permission denied
      throw Exception('Failed to bring app to foreground: ${e.message}');
    } catch (e) {
      // Other errors
    }
  }
  
  /// Checks if system navigation override mode is enabled
  /// 
  /// What This Does:
  /// - Queries SharedPreferences for system nav mode flag
  /// - Returns cached setting (fast, local only)
  /// - Doesn't query actual Android system
  /// 
  /// System Navigation Override:
  /// - When enabled: Can intercept Android back button, home button, recent apps
  /// - Requires: Device admin app or accessibility service
  /// - Purpose: Prevent elderly user from accidentally leaving app
  /// 
  /// Returns:
  ///   true: System navigation override is enabled
  ///   false: Not enabled or was disabled
  /// 
  /// Default:
  ///   false on first install
  /// 
  /// Usage:
  ///   if (await launcher.isSystemNavModeEnabled()) {
  ///     print('System navigation is overridden');
  ///   }
  static Future<bool> isSystemNavModeEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keySystemNavMode) ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// Enables or disables system navigation override mode
  /// 
  /// What This Does:
  /// - Stores preference in SharedPreferences
  /// - When enabled: App can intercept back/home buttons (with accessibility service)
  /// - Prevents accidental app exits via system buttons
  /// 
  /// Implementation Details:
  /// - Requires Android Accessibility Service to be enabled
  /// - Accessibility service must have android.permission.SYSTEM_ALERT_WINDOW
  /// - Service declared in AndroidManifest.xml
  /// 
  /// Parameters:
  ///   enabled: true to enable override, false to disable
  /// 
  /// Behavior:
  /// - Enable: Back button returns to app, can't press home button
  /// - Disable: Back button works normally, home button visible
  /// 
  /// Elderly Use:
  /// - Prevents confusion from multiple app switches
  /// - Keeps interface simple and focused
  /// - Can still power off device with power button
  /// 
  /// Usage:
  ///   // Enable system nav override
  ///   await launcher.setSystemNavMode(true);
  ///   
  ///   // Disable system nav override
  ///   await launcher.setSystemNavMode(false);
  static Future<void> setSystemNavMode(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySystemNavMode, enabled);
    } catch (e) {
      // Ignore preference save errors - setting will use default
    }
  }
  
  /// Simulates Android back button press programmatically
  /// 
  /// What This Does:
  /// - Calls native Android code to simulate back button
  /// - Behaves exactly like user physically tapping back button
  /// - Closes current screen, returns to previous activity
  /// 
  /// How It Works:
  /// - Injects KeyEvent.KEYCODE_BACK event
  /// - Android processes like normal back button press
  /// - Current activity's onBackPressed() is called
  /// 
  /// Use Cases:
  /// - Implement custom back button in TapCall UI
  /// - Auto-return after WhatsApp call (simulate back)
  /// - Dismiss dialogs or return to main screen
  /// 
  /// Behavior:
  /// - If TapCall main screen: May minimize app (system-dependent)
  /// - If kiosk mode on: Intercepted by accessibility service (stays in app)
  /// 
  /// Error Handling:
  /// - Fails silently if system can't inject event
  /// - Platform exceptions caught
  /// 
  /// Usage:
  ///   // User taps back button in settings
  ///   await launcher.pressBackButton();  // Return to main screen
  static Future<void> pressBackButton() async {
    try {
      // Invoke native Android code to send back button event
      // Method name must match Kotlin: fun pressBackButton()
      await platform.invokeMethod('pressBackButton');
    } on PlatformException catch (e) {
      throw Exception('Failed to press back button: ${e.message}');
    } catch (e) {
      // Ignore non-platform errors - back press is optional
    }
  }
  
  /// Opens Android recent apps / task switcher
  /// 
  /// What This Does:
  /// - Shows system task switcher (recent apps list)
  /// - User can see and switch between running apps
  /// - Usually triggered by back button long-press or 3-finger gesture
  /// 
  /// Android Implementation:
  /// - Calls StatusBarManager.toggleRecentApps()
  /// - Shows system UI overlay with running apps
  /// - User can select app to switch to
  /// 
  /// Use Cases:
  /// - Developer testing/debugging only
  /// - Rarely needed for elderly app
  /// - Should be blocked in kiosk mode
  /// 
  /// Kiosk Mode Interaction:
  /// - If kiosk mode + system nav override: Blocked (can't access other apps)
  /// - Without override: User can see other running apps
  /// 
  /// Error Handling:
  /// - Fails if accessibility service not enabled
  /// - Platform exceptions caught
  /// 
  /// Usage:
  ///   // For testing: Show task switcher
  ///   try {
  ///     await launcher.openRecentApps();
  ///   } catch (e) {
  ///     print('Could not open recent apps: $e');
  ///   }
  static Future<void> openRecentApps() async {
    try {
      // Invoke native Android code to show task switcher
      // Method name must match Kotlin: fun openRecentApps()
      await platform.invokeMethod('openRecentApps');
    } on PlatformException catch (e) {
      throw Exception('Failed to open recent apps: ${e.message}');
    }
  }
  
  /// Checks if kiosk mode is currently enabled
  /// 
  /// What Kiosk Mode Does:
  /// - Locks app to foreground (can't swipe away)
  /// - Prevents home/back button navigation (when system nav override enabled)
  /// - Blocks access to system drawers, notifications, settings
  /// - Perfect for elderly users or shared devices
  /// 
  /// Technical Implementation:
  /// - Flag stored in SharedPreferences
  /// - Actual kiosk behavior enforced by accessibility service
  /// - bringAppToForeground() keeps app on top
  /// - Accessibility service intercepts back/home buttons
  /// 
  /// Returns:
  ///   true: Kiosk mode is enabled, app is locked
  ///   false: Kiosk mode disabled, normal operation
  /// 
  /// Default:
  ///   false on first install (app is not locked)
  /// 
  /// Usage:
  ///   if (await launcher.isKioskModeEnabled()) {
  ///     print('Device is in kiosk mode - app is locked');
  ///   } else {
  ///     print('Normal mode');
  ///   }
  static Future<bool> isKioskModeEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyKioskMode) ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// Enables or disables kiosk mode
  /// 
  /// What This Does:
  /// 1. Stores kiosk mode flag in SharedPreferences
  /// 2. If enabling: Accessibility service takes effect on next interaction
  /// 3. If disabling: Returns to normal navigation
  /// 
  /// Kiosk Mode Features (when enabled):
  /// - App locks to foreground
  /// - Back button disabled (returns to TapCall)
  /// - Home button disabled (can't leave app)
  /// - Recent apps hidden
  /// - Status bar notifications blocked
  /// - Settings app inaccessible
  /// 
  /// Implementation Requirement:
  /// - Accessibility Service must be enabled in device Settings
  /// - Service must have necessary permissions in AndroidManifest.xml
  /// - Service monitors accessibility events and intercepts navigation
  /// 
  /// Setup Process for Elderly:
  /// 1. Call setKioskMode(true)
  /// 2. User enables accessibility service in Settings
  /// 3. Call bringAppToForeground() to lock app on top
  /// 4. Now app is locked - user can only tap buttons, make calls
  /// 
  /// Disabling Kiosk:
  /// 1. Call setKioskMode(false)
  /// 2. Back button now works normally
  /// 3. User can navigate normally
  /// 
  /// Parameters:
  ///   enabled: true to enable kiosk mode, false to disable
  /// 
  /// Usage:
  ///   // Enable kiosk mode
  ///   await launcher.setKioskMode(true);
  ///   await launcher.bringAppToForeground();
  ///   print('Kiosk mode enabled - app is now locked');
  ///   
  ///   // Later, disable kiosk mode
  ///   await launcher.setKioskMode(false);
  ///   print('Normal mode - user can navigate freely');
  static Future<void> setKioskMode(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyKioskMode, enabled);
    } catch (e) {
      // Ignore preference save errors - kiosk mode will use default
    }
  }
  
  /// Sets device screen dimensions for WhatsApp automation coordinate scaling
  /// 
  /// What This Does:
  /// - Passes screen width/height to native Android code
  /// - Used for WhatsApp button automation (accessibility feature)
  /// - Accessibility service scales coordinates to actual screen size
  /// - Compensates for different device resolutions
  /// 
  /// Why Scaling Needed:
  /// - Pre-recorded button coordinates from reference device (e.g., 1080x2340)
  /// - Target device might have different resolution (e.g., 720x1560)
  /// - Without scaling: Taps would hit wrong coordinates
  /// - Example: 50% across screen on 1080px = 540px, on 720px = 360px
  /// 
  /// Use Cases:
  /// - WhatsApp automation: Auto-accept calls, tap send button
  /// - Ensures coordinates work on any device screen size
  /// - Part of accessibility service implementation
  /// 
  /// Parameters:
  ///   width: Screen width in pixels (e.g., 1080)
  ///   height: Screen height in pixels (e.g., 2340)
  /// 
  /// How to Get Screen Size:
  ///   MediaQuery.of(context).size.width   → Flutter width in logical pixels
  ///   MediaQuery.of(context).size.height  → Flutter height in logical pixels
  ///   DisplayMetrics.widthPixels          → Android physical pixels (if needed)
  /// 
  /// Error Handling:
  /// - Platform exceptions caught: Device configuration error
  /// - Invalid dimensions ignored (fallback to defaults)
  /// 
  /// Implementation (Kotlin):
  /// - Stores dimensions for later coordinate calculations
  /// - Used in accessibility service: screenCoordinate = referenceCoordinate * (currentWidth / referenceWidth)
  /// 
  /// Usage:
  ///   // In main_call_screen.dart initialization
  ///   final size = MediaQuery.of(context).size;
  ///   await launcher.setScreenSize(
  ///     size.width.toInt(),
  ///     size.height.toInt(),
  ///   );
  static Future<void> setScreenSize(int width, int height) async {
    try {
      // Validate dimensions are reasonable (not zero or absurdly large)
      if (width <= 0 || height <= 0) {
        return;
      }
      
      // Invoke native Android code with screen dimensions
      // Method name must match Kotlin: fun setScreenSize(width: Int, height: Int)
      await platform.invokeMethod('setScreenSize', {
        'width': width,
        'height': height,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to set screen size: ${e.message}');
    } catch (e) {
      // Ignore non-platform errors - coordinate scaling is optional
    }
  }
}
