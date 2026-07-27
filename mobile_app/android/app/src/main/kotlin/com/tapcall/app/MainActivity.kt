package com.tapcall.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import androidx.annotation.NonNull
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.tapcall.app/accessibility"
    private val LAUNCHER_CHANNEL = "com.tapcall.app/launcher"
    private val SCREEN_CHANNEL = "com.tapcall.app/screen"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Allow the app to turn on the screen and show over the lock screen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Accessibility channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> result.success(isAccessibilityServiceEnabled())
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(null)
                }
                "resetCallState" -> result.success(null)
                "endCall" -> result.success(endActiveCall())
                "acceptIncomingCall" -> result.success(acceptIncomingCall())
                "armAutoSend" -> {
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
        
        // Launcher channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAUNCHER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setScreenSize" -> {
                    val width = call.argument<Int>("width")
                    val height = call.argument<Int>("height")
                    if (width != null && height != null) {
                        CoordinateScaler(this).setReferenceScreen(width, height)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "width and height must be provided", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // Screen wake channel
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
    
    /**
     * Robust screen wake mechanism for modern Android:
     * Posts a high-priority notification with a FullScreenIntent to bypass 
     * Android's background activity restrictions and force the display to turn on.
     */
    /**
     * BRUTE FORCE SCREEN WAKE
     * Uses a direct hardware WakeLock + FullScreenIntent Notification
     */
    private fun wakeDeviceScreen() {
        try {
            val context = applicationContext
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            
            if (powerManager.isInteractive) {
                android.util.Log.d("TapCall", "💡 Screen is already ON. Ignoring PIR wake request.")
                return // Exit the function instantly. No notifications, no wake locks!
            }

            // 1. HARDWARE WAKE LOCK
            @Suppress("DEPRECATION")
            val wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or 
                PowerManager.ACQUIRE_CAUSES_WAKEUP or 
                PowerManager.ON_AFTER_RELEASE,
                "TapCall::PIRWakeLock"
            )
            wakeLock.acquire(5000) 

            // 2. LAUNCH ACTIVITY
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or 
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            startActivity(intent)

            // 3. NOTIFICATION FALLBACK
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelId = "tapcall_wake_channel"
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "Screen Wake Alerts",
                    NotificationManager.IMPORTANCE_HIGH
                )
                notificationManager.createNotificationChannel(channel)
            }

            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val notification = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(android.R.drawable.ic_menu_call)
                .setContentTitle("TapCall")
                .setContentText("Motion detected")
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setFullScreenIntent(pendingIntent, true)
                .setAutoCancel(true)
                .build()

            notificationManager.notify(8888, notification)
            android.util.Log.d("TapCall", "☀️ Screen wake forced via WakeLock & Notification")
            
        } catch (e: Exception) {
            android.util.Log.e("TapCall", "❌ Failed to wake screen: ${e.message}")
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val service = "${packageName}/${AccessibilityServices::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
        return enabledServices.contains(service)
    }

    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
    
    private fun endActiveCall(): Boolean {
        return try {
            val service = AccessibilityServices.getInstance()
            if (service != null) {
                service.clickEndCallButton()
                true
            } else false
        } catch (e: Exception) {
            false
        }
    }
    
    private fun acceptIncomingCall(): Boolean {
        return try {
            val service = AccessibilityServices.getInstance()
            if (service != null) {
                service.acceptIncomingCall()
                true
            } else false
        } catch (e: Exception) {
            false
        }
    }
}