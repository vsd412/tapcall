/*
TapCall Call Launcher Helpers (Android/Kotlin)

Purpose:
- Helper functions for detecting and clicking call-related buttons in WhatsApp UI
- Supports multiple languages (English, Traditional Chinese, Simplified Chinese)
- Uses accessibility node traversal to find clickable elements

Functions:
1. clickCallButton(root): Finds and clicks "call" buttons
   - Searches for text: "voice call", "video call", "視像通話", "通話", etc.
   - Returns true if button found and clicked

2. clickConfirmButton(root): Finds and clicks "confirm call" buttons
   - Searches for text: "進行通話", "进行通话", "call"
   - Used for secondary confirmation dialogs

3. clickNode(node): Attempts to click a node or its clickable parent
   - Tries node itself first, then traverses up to 3 levels of parents
   - Returns true if click action succeeded

Node Traversal Strategy:
- Some buttons have non-clickable text children inside clickable parents
- Algorithm walks up parent hierarchy (max 3 levels) to find clickable container
- Checks both isClickable and isEnabled before attempting click

Notes:
- Uses Android AccessibilityNodeInfo API
- Requires accessibility service to be enabled
- Logs all successful clicks to logcat with TAG="CallLauncher"
*/

package com.tapcall.app

import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo

private const val TAG = "CallLauncher"

// Search for and click WhatsApp call buttons (voice/video call)
// Returns true if a button was found and clicked successfully
fun clickCallButton(root: AccessibilityNodeInfo): Boolean {
    // Multi-language button texts to search for
    val callButtonTexts = listOf(
        "voice call", "video call", "call", "audio",  // English
        "視像通話", "通話", "视像通话", "通话", "视频通话", "语音通话", "語音通話"  // Chinese variants
    )
    
    for (text in callButtonTexts) {
        val nodes = root.findAccessibilityNodeInfosByText(text)
        for (node in nodes) {
            if (clickNode(node)) {
                Log.d(TAG, "✓ Clicked call button: '$text'")
                return true
            }
        }
    }
    return false
}

// Search for and click WhatsApp call confirmation buttons
// Returns true if a button was found and clicked successfully
fun clickConfirmButton(root: AccessibilityNodeInfo): Boolean {
    // Multi-language confirmation button texts
    val confirmTexts = listOf("進行通話", "进行通话", "call")  // Traditional/Simplified Chinese + English
    
    for (text in confirmTexts) {
        val nodes = root.findAccessibilityNodeInfosByText(text)
        for (node in nodes) {
            if (clickNode(node)) {
                Log.d(TAG, "✓ Clicked confirm button: '$text'")
                return true
            }
        }
    }
    return false
}

// Attempt to click a node or traverse up to find a clickable parent (max 3 levels)
// Returns true if click action was performed successfully
private fun clickNode(node: AccessibilityNodeInfo?): Boolean {
    if (node == null) return false
    
    // Try clicking the node itself if it's clickable and enabled
    if (node.isClickable && node.isEnabled) return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
    
    // Walk up parent hierarchy to find a clickable container
    var parent = node.parent
    repeat(3) {  // Try up to 3 parent levels
        if (parent?.isClickable == true && parent.isEnabled) return parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        parent = parent?.parent
    }
    return false
}
