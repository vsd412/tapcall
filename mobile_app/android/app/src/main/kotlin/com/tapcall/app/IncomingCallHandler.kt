package com.tapcall.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo

class IncomingCallHandler(private val service: AccessibilityService) {

    companion object {
        private const val TAG = "IncomingCallHandler"

        // Strictly Accept texts only. Decline is handled entirely by EndCallHandler.kt
        private val ACCEPT_CALL_TEXTS = listOf("接聽", "接受", "接听", "accept", "answer", "視像", "视像", "video", "語音", "语音", "voice")
    }

    // We keep the isAccept boolean so we don't break your AccessibilityServices.kt file,
    // but we ignore it internally since this file is now purely for accepting calls.
    fun handleCall(isAccept: Boolean): Boolean {
        Log.e(TAG, "=========================================================")
        Log.e(TAG, "📱 INCOMING CALL HANDLER TRIGGERED! Action: ACCEPT")
        
        // result: 0 = Failed, 1 = Clicked Popup, 2 = Swiped Full-Screen
        val result = processWindows()

        if (result == 1) {
            // We clicked a popup. We MUST wait for WhatsApp to expand to full screen.
            Log.e(TAG, "⏱️ Popup clicked! Waiting 1.2s for WhatsApp full-screen expansion...")
            Handler(Looper.getMainLooper()).postDelayed({
                Log.e(TAG, "🔄 Follow-up scan triggered for full-screen UI!")
                processWindows()
            }, 1200)
            return true
        } else if (result == 2) {
            // We swiped the full screen. The call is answered! DO NOT trigger the follow-up.
            Log.e(TAG, "✅ Full-screen answered immediately. No follow-up needed.")
            return true
        }

        return false
    }

    private fun processWindows(): Int {
        val windows = service.windows
        if (windows.isNullOrEmpty()) {
            Log.e(TAG, "❌ FAILURE: No windows available!")
            return 0
        }

        for (window in windows) {
            val root = window.root ?: continue
            val packageName = root.packageName?.toString() ?: "UNKNOWN"
            
            val interactionResult = findAndInteract(root, ACCEPT_CALL_TEXTS, packageName)
            if (interactionResult > 0) {
                Log.e(TAG, "✅ SUCCESS: Interacted with package: $packageName")
                return interactionResult
            }
        }
        return 0
    }

    // Returns: 0 (Not Found), 1 (Clicked Popup), 2 (Swiped Full-Screen)
    private fun findAndInteract(root: AccessibilityNodeInfo, texts: List<String>, packageName: String): Int {
        val foundNodes = mutableListOf<AccessibilityNodeInfo>()
        manualSearch(root, texts, foundNodes)

        if (foundNodes.isEmpty()) return 0

        val screenHeight = service.resources.displayMetrics.heightPixels

        for (node in foundNodes) {
            Log.e(TAG, "🔎 Found target node manually: text='${node.text}' desc='${node.contentDescription}'")

            // SCENARIO A: We are in the WhatsApp Full-Screen UI
            if (packageName == "com.whatsapp" || packageName == "com.whatsapp.w4b") {
                val rect = Rect()
                node.getBoundsInScreen(rect)
                
                // Make sure we are swiping the button at the BOTTOM of the screen
                if (rect.centerY() > (screenHeight / 2)) {
                    Log.e(TAG, "👉 WhatsApp Full-Screen UI detected! Forcing SWIPE UP on the button.")
                    performSwipe(rect.centerX().toFloat(), rect.centerY().toFloat())
                    return 2 // Return 2 so the main loop knows NOT to do a follow-up scan
                } else {
                    Log.e(TAG, "⏭️ Ignoring text at the top of the screen (Disclaimer).")
                    continue
                }
            }

            // SCENARIO B: We are in the System UI Popup (Heads-up Notification)
            if (node.isClickable) {
                Log.e(TAG, "👆 Popup Node is clickable! Performing ACTION_CLICK.")
                node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                return 1 // Return 1 so the main loop triggers the 1.2s delay
            }

            var parent = node.parent
            var depth = 0
            while (parent != null && depth < 5) {
                if (parent.isClickable) {
                    Log.e(TAG, "👆 Popup Parent container is clickable! Performing ACTION_CLICK.")
                    parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    return 1 // Return 1 so the main loop triggers the 1.2s delay
                }
                parent = parent.parent
                depth++
            }
        }
        return 0
    }

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

    private fun performSwipe(startX: Float, startY: Float) {
        // Swipe UP exactly 800 pixels from the center of the button
        val endY = (startY - 800f).coerceAtLeast(50f)

        Log.e(TAG, "🚀 Dispatching swipe: Start(X:$startX, Y:$startY) -> End(X:$startX, Y:$endY)")

        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(startX, endY)
        }

        val gesture = GestureDescription.Builder()
            // 300ms is the perfect speed for a natural finger flick
            .addStroke(GestureDescription.StrokeDescription(path, 0, 300))
            .build()

        service.dispatchGesture(gesture, null, null)
    }
}