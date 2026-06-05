/*
TapCall Incoming Call Handler (Android/Kotlin)

Purpose:
- Accepts incoming WhatsApp calls via physical button press
- Triggered when GPIO 10 (slot 251) is pressed on ESP32 device
- Also handles case where WhatsApp incoming call overlay appears over another app

Tested WhatsApp UI (HK Chinese):
- Accept button: desc contains "接聽" (confirmed)
- Accept gesture: swipe UP from node center, 429px over 500ms (confirmed via adb)
- ACTION_CLICK does NOT work on incoming call buttons (they are swipe-style)

Call Flow:
  ESP32 GPIO 10 -> BLE "BTN:251\n" -> Flutter _handleAcceptCall()
  -> MethodChannel acceptCall -> AccessibilityServices.acceptIncomingCall()
  -> IncomingCallHandler.acceptCall()

Notes:
- WhatsApp incoming calls show a full-screen overlay activity even when
  the user is in another app. The accessibility service receives events
  for this overlay because packageNames filter includes WhatsApp.
- The rootInActiveWindow will show the WhatsApp incoming call UI when
  the overlay is displayed.
*/

package com.tapcall.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Accepts incoming WhatsApp calls by finding and clicking the accept/answer button.
 */
class IncomingCallHandler(
    private val service: AccessibilityService
) {
    companion object {
        private const val TAG = "IncomingCallHandler"

        private const val WHATSAPP_PACKAGE = "com.whatsapp"
        private const val WHATSAPP_BUSINESS = "com.whatsapp.w4b"

        // Accept/answer call button labels across WhatsApp language variants.
        private val ACCEPT_CALL_TEXTS = listOf(
            // Traditional Chinese (confirmed on device)
            "接聽",        // "accept/answer"
            "接受",        // "accept"
            "接聽來電",    // "accept incoming call"
            // Simplified Chinese
            "接听",
            "接受",
            "接听来电",
            // English
            "accept",
            "answer",
            "accept call",
            "answer call"
        )
    }

    /**
     * Attempt to accept an incoming WhatsApp call.
     * @return true if the accept button was found and clicked
     */
    fun acceptCall(): Boolean {
        Log.d(TAG, "Attempting to accept incoming call...")

        val root = service.rootInActiveWindow
        if (root == null) {
            Log.e(TAG, "No root window available")
            return false
        }

        val packageName = root.packageName?.toString() ?: ""
        Log.d(TAG, "Foreground package: $packageName")

        if (packageName != WHATSAPP_PACKAGE && packageName != WHATSAPP_BUSINESS) {
            Log.w(TAG, "Not in WhatsApp ($packageName) - cannot accept call")
            return false
        }

        // Search for accept button by text + contentDescription
        if (findAndClickByText(root)) {
            Log.d(TAG, "Accept call button clicked")
            return true
        }

        // Fallback: DFS scan
        Log.w(TAG, "Text search failed - running DFS scan...")
        if (findAndClickByDFS(root)) {
            Log.d(TAG, "Accept call button found via DFS")
            return true
        }

        // Dump tree for diagnosis
        Log.w(TAG, "DFS failed - dumping UI tree for diagnosis")
        dumpNodeTree(root, 0)
        return false
    }

    // =========================================================================
    // Text search
    // =========================================================================

    private fun findAndClickByText(root: AccessibilityNodeInfo): Boolean {
        for (text in ACCEPT_CALL_TEXTS) {
            val nodes = root.findAccessibilityNodeInfosByText(text)
            for (node in nodes) {
                Log.d(TAG, "Hit: text=${node.text} desc=${node.contentDescription} class=${node.className} clickable=${node.isClickable}")
                // Incoming call buttons are swipe-style (not clickable) — go straight to swipe
                if (swipeNodeUp(node)) return true
            }
        }
        return false
    }

    // =========================================================================
    // DFS scan (fallback)
    // =========================================================================

    private fun findAndClickByDFS(root: AccessibilityNodeInfo): Boolean = dfsFind(root, 0)

    private fun dfsFind(node: AccessibilityNodeInfo, depth: Int): Boolean {
        if (depth > 15) return false

        val text = node.text?.toString()?.lowercase() ?: ""
        val desc = node.contentDescription?.toString()?.lowercase() ?: ""

        for (pattern in ACCEPT_CALL_TEXTS) {
            val p = pattern.lowercase()
            if ((text.isNotEmpty() && text.contains(p)) ||
                (desc.isNotEmpty() && desc.contains(p))) {
                Log.d(TAG, "DFS match: text=$text desc=$desc clickable=${node.isClickable}")
                // Incoming call buttons are swipe-style — go straight to swipe
                if (swipeNodeUp(node)) return true
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            if (dfsFind(child, depth + 1)) return true
        }
        return false
    }

    // =========================================================================
    // Swipe gesture (only method that works for incoming call buttons)
    // =========================================================================

    /**
     * Swipe UP from the node's center using dispatchGesture.
     * Requires android:canPerformGestures="true" in accessibility_service_config.xml.
     * Confirmed working: swipe UP 429px from node center over 500ms.
     */
    private fun swipeNodeUp(node: AccessibilityNodeInfo): Boolean {
        val rect = Rect()
        node.getBoundsInScreen(rect)
        val x = rect.centerX().toFloat()
        val startY = rect.centerY().toFloat()
        val endY = (startY - 429f).coerceAtLeast(50f)

        if (x <= 0 || startY <= 0) {
            Log.w(TAG, "Invalid node bounds: $rect")
            return false
        }

        Log.d(TAG, "dispatchGesture swipe UP: ($x, $startY) -> ($x, $endY) 500ms")

        val path = Path().apply {
            moveTo(x, startY)
            lineTo(x, endY)
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 500))
            .build()

        service.dispatchGesture(gesture, object : AccessibilityService.GestureResultCallback() {
            override fun onCompleted(g: GestureDescription?) {
                Log.d(TAG, "Swipe gesture COMPLETED")
            }
            override fun onCancelled(g: GestureDescription?) {
                Log.w(TAG, "Swipe gesture CANCELLED")
            }
        }, null)
        return true
    }

    // =========================================================================
    // Debug: UI tree dump
    // =========================================================================

    private fun dumpNodeTree(node: AccessibilityNodeInfo, depth: Int) {
        if (depth > 10) return
        val indent = "  ".repeat(depth)
        val text = node.text?.toString() ?: ""
        val desc = node.contentDescription?.toString() ?: ""
        val cls = node.className?.toString()?.substringAfterLast('.') ?: ""
        val click = if (node.isClickable) " click" else ""

        if (text.isNotEmpty() || desc.isNotEmpty() || node.isClickable) {
            Log.d(TAG, "DUMP${indent}[$cls] text=$text desc=$desc$click")
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            dumpNodeTree(child, depth + 1)
        }
    }
}
