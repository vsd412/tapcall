/*
TapCall Call Detection & Auto-Return (Android/Kotlin)

Purpose:
- Detects when WhatsApp calls are active or ended by scanning UI node tree
- Automatically returns user to TapCall app after call ends
- Supports multiple languages (English, Traditional Chinese, Simplified Chinese)

Key Functions:
1. detectCallActive(node): Returns true if call UI is detected
   - Looks for call timer (MM:SS format) in text/description
   - Looks for call control indicators ("離開通話", "正在說話", "ar 特效", etc.)
   - Ignores contact names and wall clock times
   - Recursive tree traversal through all child nodes

2. detectCallEnded(node): Returns true if chat UI is detected (call ended)
   - Looks for chat indicators ("返回", "附加", "語音訊息", "輸入訊息", etc.)
   - Looks for rejected/missed call buttons ("取消", "重撥", "錄製語音訊息")
   - Returns true immediately for rejected calls (no minimum duration check)

3. returnToMainApp(): Launches TapCall app to foreground
   - Uses PackageManager to get launch intent
   - Sets NEW_TASK and BROUGHT_TO_FRONT flags
   - Called after call end is confirmed

4. logThrottled(message): Logs with cooldown to reduce logcat spam
   - Logs immediately when message changes
   - Otherwise logs at most once per 3 seconds

Detection Strategy:
- Timer detection: Matches MM:SS pattern but excludes AM/PM clock times
- Contact name filtering: Ignores short names like "tc" or "tc p" (1-3 letters)
- Recursive traversal: Searches entire UI tree for matching text/descriptions
- Multi-language support: All strings have English + Chinese variants

Configuration:
- DETECTION_ENABLED: Master switch (currently true)
- LOG_COOLDOWN_MS: 3000ms throttle for repeated log messages

Notes:
- Used by AccessibilityServices to determine call state
- Handles edge cases: rejected calls, missed calls, contact names vs UI text
- Critical for auto-return-to-app functionality
*/

package com.tapcall.app

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo

private const val TAG = "ReturnAfterEndCall"
private const val DETECTION_ENABLED = true
private var lastLogMessage = ""
private var lastLogTime = 0L
private const val LOG_COOLDOWN_MS = 3000L

fun detectCallActive(node: AccessibilityNodeInfo): Boolean {
    if (!DETECTION_ENABLED) return false
    val rawText = node.text?.toString() ?: ""
    val rawDesc = node.contentDescription?.toString() ?: ""
    val text = rawText.lowercase()
    val desc = rawDesc.lowercase()

    // Ignore contact names like "tc" or "tc p"
    fun looksLikeContactName(s: String): Boolean = s.matches(Regex("[a-z]{1,3}(\\s?p)?"))

    // Detect timers (MM:SS) but ignore wall clocks
    val timerRegex = Regex("^(0?\\d|[1-5]\\d):[0-5]\\d$")
    val clockMarkers = listOf("am", "pm", "上午", "下午", "早上", "晚上", "中午")
    fun isClockLike(s: String) = clockMarkers.any { s.contains(it) }
    if (timerRegex.containsMatchIn(text) && !isClockLike(text)) {
        logThrottled("🕐 Timer in text: '$rawText'")
        return true
    }
    if (timerRegex.containsMatchIn(desc) && !isClockLike(desc)) {
        logThrottled("🕐 Timer in desc: '$rawDesc'")
        return true
    }

    // Stable call indicators (do not rely on contact name)
    val callDescIndicators = listOf(
        "離開通話", "正在說話", "正在说话", "縮細通話", "缩细通话", "新增通話成員",
        "轉用後置鏡頭", "后置鏡頭", "ar 特效", "更多選單", "更多选单",
        "關閉鏡頭", "关闭镜头", "揀選音訊裝置", "音訊裝置", "關閉咪高峰", "关闭咪高峰"
    )
    val callTextIndicators = listOf("正在說話", "正在说话")

    if (callTextIndicators.any { text.contains(it) } && !looksLikeContactName(text.trim())) {
        logThrottled("🎛️ Call text indicator: '$rawText'")
        return true
    }
    if (callDescIndicators.any { desc.contains(it) }) {
        logThrottled("🎛️ Call desc indicator: '$rawDesc'")
        return true
    }
    
    repeat(node.childCount) { i ->
        node.getChild(i)?.let { child ->
            if (detectCallActive(child)) { child.recycle(); return true }
            child.recycle()
        }
    }
    return false
}

fun detectCallEnded(node: AccessibilityNodeInfo): Boolean {
    if (!DETECTION_ENABLED) return false
    val rawText = node.text?.toString() ?: ""
    val rawDesc = node.contentDescription?.toString() ?: ""
    val text = rawText.lowercase()
    val desc = rawDesc.lowercase()

    // Stable chat indicators (do not rely on contact name)
    val chatDescIndicators = listOf(
        "返回", "更多選項", "更多选项", "表情符號、gif 同貼圖", "附加", "相機", "語音訊息",
        "表情符號", "輸入訊息", "输入消息"
    )
    val chatTextIndicators = listOf("訊息", "消息")

    // Rejected/Missed call indicators - call ended without being answered
    val rejectedCallIndicators = listOf(
        "取消", "取消", "重撥", "重拨", "錄製語音訊息", "录制语音消息"
    )

    if (chatTextIndicators.any { text.contains(it) }) {
        logThrottled("💬 Chat text indicator: '$rawText'")
        return true
    }
    if (chatDescIndicators.any { desc.contains(it) }) {
        logThrottled("💬 Chat desc indicator: '$rawDesc'")
        return true
    }
    
    // Check for rejected/missed call indicators
    if (rejectedCallIndicators.any { text.contains(it) || desc.contains(it) }) {
        logThrottled("📵 Rejected/Missed call indicator: text='$rawText' desc='$rawDesc'")
        return true
    }
    
    repeat(node.childCount) { i ->
        node.getChild(i)?.let { child ->
            if (detectCallEnded(child)) { child.recycle(); return true }
            child.recycle()
        }
    }
    return false
}

fun AccessibilityService.returnToMainApp() {
    try {
        Log.d(TAG, "🏠 Returning to main app...")
        val intent = packageManager.getLaunchIntentForPackage(applicationContext.packageName)
        intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT)
        startActivity(intent)
        Log.d(TAG, "✅ Successfully returned to main app")
    } catch (e: Exception) {
        Log.e(TAG, "❌ Failed to return to main app: ${e.message}")
    }
}

// Throttled logger: logs immediately when message changes, otherwise at most once per 3s
private fun logThrottled(message: String) {
    val now = System.currentTimeMillis()
    if (message != lastLogMessage || now - lastLogTime >= LOG_COOLDOWN_MS) {
        Log.d(TAG, message)
        lastLogMessage = message
        lastLogTime = now
    }
}
