/*
TapCall End Call Handler (Android/Kotlin)

Purpose:
- Ends active WhatsApp calls or declines incoming calls via physical button press
- Triggered when GPIO 9 (slot 252) is pressed on ESP32 device
- Uses manual DFS tree traversal to reliably find buttons across overlapping windows and popups
*/

package com.tapcall.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo

class EndCallHandler(
    private val service: AccessibilityService
) {
    companion object {
        private const val TAG = "EndCallHandler"

        // Comprehensive list of end call and decline text variants across languages
        private val END_CALL_TEXTS = listOf(
            "離開通話", "离开通话", "leave call", "end call",
            "拒絕", "拒接", "拒绝", "reject", "decline", "end", "結束", "结束"
        )
    }

    /**
     * Attempt to end an active call or decline an incoming call.
     * @return true if a button was found and acted upon
     */
    fun endCall(): Boolean {
        Log.e(TAG, "=========================================================")
        Log.e(TAG, "📴 END CALL HANDLER TRIGGERED!")
        Log.e(TAG, "=========================================================")

        val success = processWindows()

        if (success) {
            // Wait 1.2s to handle any popup-to-full-screen animations and retry if needed
            Log.e(TAG, "⏱️ Waiting 1.2s to check if UI expanded...")
            Handler(Looper.getMainLooper()).postDelayed({
                processWindows()
            }, 1200)
            return true
        }

        Log.e(TAG, "❌ FAILURE: Could not find any end/decline buttons across available windows.")
        return false
    }

    private fun processWindows(): Boolean {
        val windows = service.windows
        if (windows.isNullOrEmpty()) {
            Log.e(TAG, "❌ FAILURE: No windows available!")
            return false
        }

        for (window in windows) {
            val root = window.root ?: continue
            val packageName = root.packageName?.toString() ?: "UNKNOWN"

            if (findAndInteract(root, packageName)) {
                Log.e(TAG, "✅ SUCCESS: Interacted with package: $packageName")
                return true
            }
        }
        return false
    }

    private fun findAndInteract(root: AccessibilityNodeInfo, packageName: String): Boolean {
        val foundNodes = mutableListOf<AccessibilityNodeInfo>()
        manualSearch(root, END_CALL_TEXTS, foundNodes)

        if (foundNodes.isEmpty()) return false

        val screenHeight = service.resources.displayMetrics.heightPixels

        for (node in foundNodes) {
            Log.e(TAG, "🔎 Found target node manually: text='${node.text}' desc='${node.contentDescription}'")

            // SCENARIO A: WhatsApp Full-Screen UI (Active Call or Full-Screen Decline)
            if (packageName == "com.whatsapp" || packageName == "com.whatsapp.w4b") {
                val rect = Rect()
                node.getBoundsInScreen(rect)

                // Active call "Leave Call" buttons are natively clickable
                if (node.isClickable) {
                    Log.e(TAG, "👆 WhatsApp node is clickable! Performing ACTION_CLICK.")
                    node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    return true
                }

                var parent = node.parent
                var depth = 0
                while (parent != null && depth < 5) {
                    if (parent.isClickable) {
                        Log.e(TAG, "👆 WhatsApp parent container is clickable! Performing ACTION_CLICK.")
                        parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                        return true
                    }
                    parent = parent.parent
                    depth++
                }

                // Incoming call decline button requires a swipe up if found in the bottom half
                if (rect.centerY() > (screenHeight / 2) || rect.top > (screenHeight / 2)) {
                    Log.e(TAG, "👉 WhatsApp bottom decline button detected! Forcing SWIPE UP.")
                    return performSwipe(rect.centerX().toFloat(), rect.centerY().toFloat())
                }
            }

            // SCENARIO B: System UI Popup (Heads-up Notification for incoming call)
            if (node.isClickable) {
                Log.e(TAG, "👆 Popup Node is clickable! Performing ACTION_CLICK.")
                node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                return true
            }

            var parent = node.parent
            var depth = 0
            while (parent != null && depth < 5) {
                if (parent.isClickable) {
                    Log.e(TAG, "👆 Popup Parent container is clickable! Performing ACTION_CLICK.")
                    parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    return true
                }
                parent = parent.parent
                depth++
            }
        }
        return false
    }

    /**
     * Manual DFS traversal to bypass Android's broken text-search index on system notifications/popups.
     */
    private fun manualSearch(node: AccessibilityNodeInfo, texts: List<String>, result: MutableList<AccessibilityNodeInfo>) {
        val nodeText = node.text?.toString() ?: ""
        val nodeDesc = node.contentDescription?.toString() ?: ""

        for (target in texts) {
            if (nodeText.contains(target, ignoreCase = true) || nodeDesc.contains(target, ignoreCase = true)) {
                result.add(node)
                break
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            manualSearch(child, texts, result)
        }
    }

    private fun performSwipe(startX: Float, startY: Float): Boolean {
        val endY = (startY - 800f).coerceAtLeast(50f)

        Log.e(TAG, "🚀 Dispatching swipe: Start(X:$startX, Y:$startY) -> End(X:$startX, Y:$endY)")

        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(startX, endY)
        }

        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 300))
            .build()

        service.dispatchGesture(gesture, null, null)
        return true
    }
}