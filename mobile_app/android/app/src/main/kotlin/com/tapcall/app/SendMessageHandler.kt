/*
TapCall Send Message Handler (Android/Kotlin)

Purpose:
- Auto-clicks the WhatsApp Send button after wa.me opens with a pre-filled message
- Used by SOS feature to send emergency message without manual interaction
- Monitors WhatsApp UI via accessibility events for the Send button

Flow:
  Flutter _handleSOSCall() -> AppLauncher.sendWhatsAppMessage() (opens wa.me URL)
  -> WhatsApp opens with pre-filled message
  -> AccessibilityServices detects WhatsApp UI change
  -> SendMessageHandler finds and clicks Send button

WhatsApp wa.me flow:
  1. Browser/WhatsApp shows "Continue to Chat" / "Message" button
  2. Chat opens with message pre-filled in input field
  3. Send button appears (green arrow icon)
  We need to click through both steps automatically.

Send button labels (WhatsApp, multi-language):
  - Traditional Chinese: "傳送" (send)
  - Simplified Chinese: "发送" (send)  
  - English: "Send"
*/

package com.tapcall.app

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo

class SendMessageHandler(
    private val service: AccessibilityService
) {
    companion object {
        private const val TAG = "SendMsgHandler"

        // WhatsApp Send button labels
        private val SEND_BUTTON_TEXTS = listOf(
            // Traditional Chinese
            "傳送",
            // Simplified Chinese
            "发送",
            // English
            "send"
        )

        // WhatsApp "Continue to Chat" / intermediate screen buttons
        private val CONTINUE_CHAT_TEXTS = listOf(
            // Traditional Chinese
            "繼續對話",
            "繼續",
            "傳送訊息給",
            // Simplified Chinese
            "继续聊天",
            "继续",
            "发消息给",
            // English
            "continue to chat",
            "continue",
            "message"
        )
    }

    // Flag: whether we're waiting to auto-send a message
    @Volatile
    var pendingSend = false

    // Timestamp when send was requested (timeout after 30 seconds)
    private var sendRequestTime = 0L
    private val SEND_TIMEOUT = 30_000L

    /**
     * Call this to arm the auto-send. The handler will watch for WhatsApp's
     * Send button on the next accessibility events.
     */
    fun armAutoSend() {
        pendingSend = true
        sendRequestTime = System.currentTimeMillis()
        Log.d(TAG, "🔫 Auto-send ARMED — watching for Send button")
    }

    /**
     * Called from AccessibilityServices.onAccessibilityEvent() when WhatsApp is in foreground.
     * Looks for Send button or Continue to Chat button and clicks it.
     * @return true if a button was found and clicked
     */
    fun onWhatsAppEvent(): Boolean {
        if (!pendingSend) return false

        // Check timeout
        if (System.currentTimeMillis() - sendRequestTime > SEND_TIMEOUT) {
            Log.w(TAG, "⏰ Auto-send timed out after ${SEND_TIMEOUT / 1000}s")
            pendingSend = false
            return false
        }

        val root = service.rootInActiveWindow ?: return false

        // Step 1: Try clicking "Continue to Chat" button (intermediate screen from wa.me)
        if (clickContinueButton(root)) {
            Log.d(TAG, "✅ Clicked Continue to Chat — waiting for chat to open")
            return true
        }

        // Step 2: Try clicking the Send button in the chat
        if (clickSendButton(root)) {
            Log.d(TAG, "✅ Clicked Send button — message sent!")
            pendingSend = false
            return true
        }

        return false
    }

    private fun clickContinueButton(root: AccessibilityNodeInfo): Boolean {
        for (text in CONTINUE_CHAT_TEXTS) {
            val nodes = root.findAccessibilityNodeInfosByText(text)
            for (node in nodes) {
                if (node.isClickable) {
                    if (node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                        Log.d(TAG, "Clicked: text=${node.text} desc=${node.contentDescription}")
                        return true
                    }
                }
                // Try parent if node itself isn't clickable
                var parent = node.parent
                var depth = 0
                while (parent != null && depth < 5) {
                    if (parent.isClickable) {
                        if (parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                            Log.d(TAG, "Clicked parent of: text=${node.text}")
                            return true
                        }
                    }
                    parent = parent.parent
                    depth++
                }
            }
        }
        return false
    }

    private fun clickSendButton(root: AccessibilityNodeInfo): Boolean {
        // Search by content description (WhatsApp Send button is usually an ImageButton with desc="Send"/"傳送")
        for (text in SEND_BUTTON_TEXTS) {
            val nodes = root.findAccessibilityNodeInfosByText(text)
            for (node in nodes) {
                val desc = node.contentDescription?.toString()?.lowercase() ?: ""
                val nodeText = node.text?.toString()?.lowercase() ?: ""
                val className = node.className?.toString() ?: ""
                
                Log.d(TAG, "Found: text='$nodeText' desc='$desc' class=$className clickable=${node.isClickable}")
                
                // Match on the send button (ImageButton or Button with send-related desc/text)
                val isSendButton = className.contains("ImageButton") || 
                                   className.contains("Button") ||
                                   className.contains("ImageView") ||
                                   node.isClickable

                if (isSendButton) {
                    if (node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                        Log.d(TAG, "Send clicked via ACTION_CLICK")
                        return true
                    }
                    // Try parent
                    var parent = node.parent
                    var depth = 0
                    while (parent != null && depth < 3) {
                        if (parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                            Log.d(TAG, "Send clicked via parent at depth=$depth")
                            return true
                        }
                        parent = parent.parent
                        depth++
                    }
                }
            }
        }
        
        // Also search by DFS for content description match (Send button often has desc but no text)
        return dfsFindSend(root, 0)
    }

    private fun dfsFindSend(node: AccessibilityNodeInfo, depth: Int): Boolean {
        if (depth > 10) return false

        val desc = node.contentDescription?.toString()?.lowercase() ?: ""
        
        for (pattern in SEND_BUTTON_TEXTS) {
            if (desc.contains(pattern.lowercase())) {
                Log.d(TAG, "DFS match: desc='$desc' clickable=${node.isClickable}")
                if (node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                    Log.d(TAG, "DFS: Send clicked directly")
                    return true
                }
                var parent = node.parent
                var d = 0
                while (parent != null && d < 3) {
                    if (parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                        Log.d(TAG, "DFS: Send clicked via parent at depth=$d")
                        return true
                    }
                    parent = parent.parent
                    d++
                }
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            if (dfsFindSend(child, depth + 1)) return true
        }
        return false
    }
}
