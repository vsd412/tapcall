/*
TapCall End Call Handler (Android/Kotlin)

Purpose:
- Ends active WhatsApp calls or declines incoming calls via physical button press
- Triggered when GPIO 9 (slot 252) is pressed on ESP32 device
- Searches the accessibility UI tree for the end/decline button by text/contentDescription

Tested WhatsApp UI (HK Chinese):
- Active call end button: contentDescription = "離開通話" (confirmed)
- Incoming call decline: desc contains "拒絕" (confirmed)
- Decline gesture: swipe UP from node center, 429px over 800ms (confirmed via adb)

Call Flow:
  ESP32 GPIO 9 -> BLE "BTN:252\n" -> Flutter _handleEndCall()
  -> MethodChannel endCall -> AccessibilityServices.clickEndCallButton()
  -> EndCallHandler.endCall()
*/

package com.tapcall.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Ends active calls or declines incoming calls in WhatsApp.
 *
 * Uses findAccessibilityNodeInfosByText() which searches both text and
 * contentDescription fields of accessibility nodes.
 */
class EndCallHandler(
    private val service: AccessibilityService
) {
    companion object {
        private const val TAG = "EndCallHandler"

        private const val WHATSAPP_PACKAGE = "com.whatsapp"
        private const val WHATSAPP_BUSINESS = "com.whatsapp.w4b"

        // End call / decline button labels across WhatsApp language variants.
        // findAccessibilityNodeInfosByText() matches against both text and contentDescription.
        private val END_CALL_TEXTS = listOf(
            // Traditional Chinese (confirmed on device)
            "離開通話",     // active call end button (confirmed)
            "拒絕",        // incoming call decline button (confirmed)
            // Simplified Chinese
            "离开通话",
            "拒绝",
            // English
            "leave call",
            "decline",
            "end call"
        )

        // Max parent levels to walk up when finding a clickable container
        private const val MAX_PARENT_DEPTH = 5
    }

    /**
     * Attempt to end an active call or decline an incoming call.
     * @return true if a button was found and clicked
     */
    fun endCall(): Boolean {
        Log.d(TAG, "Attempting to end/decline call...")

        val root = service.rootInActiveWindow
        if (root == null) {
            Log.e(TAG, "No root window available")
            return false
        }

        val packageName = root.packageName?.toString() ?: ""
        Log.d(TAG, "Foreground package: $packageName")

        if (packageName != WHATSAPP_PACKAGE && packageName != WHATSAPP_BUSINESS) {
            Log.w(TAG, "Not in WhatsApp ($packageName) - cannot end call")
            return false
        }

        // Search for end/decline button by text + contentDescription
        if (findAndClickByText(root)) {
            Log.d(TAG, "End/decline call button clicked")
            return true
        }

        // Fallback: DFS scan (catches nodes the API text search might miss)
        Log.w(TAG, "Text search failed - running DFS scan...")
        if (findAndClickByDFS(root)) {
            Log.d(TAG, "End/decline call button found via DFS")
            return true
        }

        // Last resort: dump tree so we can see what is there
        Log.w(TAG, "DFS failed - dumping UI tree for diagnosis")
        dumpNodeTree(root, 0)
        return false
    }

    // =========================================================================
    // Text search (primary strategy)
    // =========================================================================

    private fun findAndClickByText(root: AccessibilityNodeInfo): Boolean {
        for (text in END_CALL_TEXTS) {
            val nodes = root.findAccessibilityNodeInfosByText(text)
            for (node in nodes) {
                Log.d(TAG, "Hit: text=${node.text} desc=${node.contentDescription} class=${node.className} clickable=${node.isClickable}")
                if (clickNodeOrParent(node)) return true
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

        for (pattern in END_CALL_TEXTS) {
            val p = pattern.lowercase()
            if ((text.isNotEmpty() && text.contains(p)) ||
                (desc.isNotEmpty() && desc.contains(p))) {
                Log.d(TAG, "DFS match: text=$text desc=$desc clickable=${node.isClickable}")
                if (clickNodeOrParent(node)) return true
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            if (dfsFind(child, depth + 1)) return true
        }
        return false
    }

    // =========================================================================
    // Node click helper
    // =========================================================================

    private fun clickNodeOrParent(node: AccessibilityNodeInfo): Boolean {
        // For clickable nodes (e.g., active call "離開通話" button): use ACTION_CLICK
        if (node.isClickable) {
            if (node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                Log.d(TAG, "ACTION_CLICK on clickable node succeeded")
                return true
            }
        }

        // For non-clickable nodes (e.g., incoming call "拒絕" swipe button):
        // skip ACTION_CLICK attempts and go straight to swipe gesture
        if (!node.isClickable) {
            Log.d(TAG, "Node not clickable — using swipe gesture directly")
            return swipeNodeUp(node)
        }

        // Fallback: walk up parent hierarchy for clickable container
        var parent = node.parent
        var depth = 0
        while (parent != null && depth < MAX_PARENT_DEPTH) {
            if (parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                Log.d(TAG, "Clicked parent at depth=$depth")
                return true
            }
            parent = parent.parent
            depth++
        }

        // Last resort: swipe gesture
        return swipeNodeUp(node)
    }

    /**
     * Swipe UP from the node's center using dispatchGesture.
     * Requires android:canPerformGestures="true" in accessibility_service_config.xml.
     * Used for incoming call decline ("拒絕") which is a swipe-style button.
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
    // Debug: UI tree dump (only runs when both strategies fail)
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
