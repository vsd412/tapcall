/*
TapCall MainActivity (Android/Kotlin)

Purpose:
- Flutter activity that bridges Flutter Dart code with Android native functionality
- Exposes two platform method channels for accessibility and screen configuration

Method Channels:
1. "com.tapcall.app/accessibility" - Manages accessibility service state
   - isAccessibilityEnabled(): Checks if TapCall's accessibility service is active
   - openAccessibilitySettings(): Launches Android accessibility settings screen
   - resetCallState(): Reserved for future call state reset logic

2. "com.tapcall.app/launcher" - Handles screen size configuration
   - setScreenSize(width, height): Stores reference screen dimensions for coordinate scaling

Accessibility Integration:
- TapCall requires accessibility permissions to auto-tap buttons in WhatsApp/WeChat
- Service class: AccessibilityServices
- Must be manually enabled by user in Android Settings → Accessibility

Notes:
- Extends FlutterActivity for seamless Flutter embedding
- Uses CoordinateScaler for cross-device tap coordinate translation
*/

package com.tapcall.app

import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.tapcall.app/accessibility"
    private val LAUNCHER_CHANNEL = "com.tapcall.app/launcher"
    private val SCREEN_CHANNEL = "com.tapcall.app/screen"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Accessibility channel - exposes Android accessibility service status and controls
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> {
                    // Check if our accessibility service is currently enabled in system settings
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    // Launch Android Settings to let user enable/disable accessibility service
                    openAccessibilitySettings()
                    result.success(null)
                }
                "resetCallState" -> {
                    // Placeholder for future call state reset functionality
                    result.success(null)
                }
                "endCall" -> {
                    // End active call by clicking end call button via accessibility service
                    val success = endActiveCall()
                    result.success(success)
                }
                "acceptCall" -> {
                    // Accept incoming call by clicking accept button via accessibility service
                    val success = acceptIncomingCall()
                    result.success(success)
                }
                "armAutoSend" -> {
                    // Arm auto-send: accessibility service will watch for and click Send button
                    val service = AccessibilityServices.getInstance()
                    if (service != null) {
                        service.armAutoSendMessage()
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // Launcher channel - handles screen size configuration for coordinate scaling
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAUNCHER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setScreenSize" -> {
                    // Store reference screen dimensions from Flutter (for tap coordinate scaling)
                    val width = call.argument<Int>("width")
                    val height = call.argument<Int>("height")
                    if (width != null && height != null) {
                        val scaler = CoordinateScaler(this)
                        scaler.setReferenceScreen(width, height)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "width and height must be provided", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // Screen wake channel - actually turns on the device screen when PIR detects motion
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "wakeScreen" -> {
                    wakeDeviceScreen()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    // Wakes the device screen using PowerManager
    // Requires android.permission.WAKE_LOCK in AndroidManifest.xml
    private fun wakeDeviceScreen() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            
            // Create a wake lock that turns on the screen and keeps it on
            val wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "TapCall::ScreenWake"
            )
            
            // Turn on screen for 3 seconds
            wakeLock.acquire(3000)  // 3000ms = 3 seconds
        } catch (e: Exception) {
            android.util.Log.e("TapCall", "Failed to wake screen: ${e.message}")
        }
    }

    // Check if TapCall's accessibility service is enabled in Android system settings
    private fun isAccessibilityServiceEnabled(): Boolean {
        val service = "${packageName}/${AccessibilityServices::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
        return enabledServices.contains(service)
    }

    // Open Android Settings → Accessibility so user can enable TapCall's service
    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }
    
    // End active call by triggering the accessibility service to click end call button
    private fun endActiveCall(): Boolean {
        return try {
            val service = AccessibilityServices.getInstance()
            if (service != null) {
                service.clickEndCallButton()
                android.util.Log.d("TapCall", "📴 End call command sent to accessibility service")
                true
            } else {
                android.util.Log.e("TapCall", "❌ Accessibility service not available")
                false
            }
        } catch (e: Exception) {
            android.util.Log.e("TapCall", "❌ Failed to end call: ${e.message}")
            false
        }
    }
    
    // Accept incoming call by triggering the accessibility service to click accept button
    private fun acceptIncomingCall(): Boolean {
        return try {
            val service = AccessibilityServices.getInstance()
            if (service != null) {
                service.acceptIncomingCall()
                android.util.Log.d("TapCall", "📞 Accept call command sent to accessibility service")
                true
            } else {
                android.util.Log.e("TapCall", "❌ Accessibility service not available")
                false
            }
        } catch (e: Exception) {
            android.util.Log.e("TapCall", "❌ Failed to accept call: ${e.message}")
            false
        }
    }
}