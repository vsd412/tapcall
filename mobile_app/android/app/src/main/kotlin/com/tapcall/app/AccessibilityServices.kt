/*
TapCall Accessibility Service (Android/Kotlin)

Purpose:
- System-level service that monitors WhatsApp and WeChat UI for automated call handling
- Auto-clicks call buttons and detects call start/end to return user to TapCall app
- Performs coordinate-based taps for WeChat call initiation

Key Behaviors:
1. WhatsApp Call Automation:
   - Scans UI nodes for "call" buttons (multiple languages supported)
   - Auto-clicks "call" and "confirm" buttons when detected
   - Tracks call state via timer detection in UI (MM:SS format)
   - Returns to TapCall app after call ends (with confirmation delay)

2. WeChat Call Automation:
   - Uses absolute pixel coordinate taps (3-tap sequence)
   - Tap 1 (86, 287): "Try" button to open contact
   - Tap 2 (1015, 1844): Contact button to select recipient
   - Tap 3 (663, 1318): Call button to initiate call
   - First tap is 20ms duration, subsequent taps 50ms

3. Call State Detection:
   - Call active: Detects timers (MM:SS) and Chinese call UI elements
   - Call ended: Detects chat UI elements (back button, message input, etc.)
   - Rejected/missed: Detects "cancel", "redial" buttons → immediate return
   - Minimum call duration: 3 seconds before allowing end detection
   - Confirmation time: 1.5 seconds of consistent "ended" state before returning

Configuration Constants:
- MIN_CALL_DURATION: 3000ms - ignore premature end detections
- CALL_END_CONFIRMATION_TIME: 1500ms - wait for stable end state
- DEBUG flags for coordinate logging and UI tree dumping

Notes:
- Requires accessibility permission from user
- Runs as system service in background
- Monitors TYPE_WINDOW_CONTENT_CHANGED events for real-time UI tracking
*/

package com.tapcall.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class AccessibilityServices : AccessibilityService() {
    
    companion object {
        private const val TAG = "A11yServices"
        // Target app package names
        private const val WHATSAPP_PACKAGE = "com.whatsapp"
        private const val WHATSAPP_BUSINESS = "com.whatsapp.w4b"
        private const val WECHAT_PACKAGE = "com.tencent.mm"
        
        // Call state timing constants
        private const val MIN_CALL_DURATION = 3000L  // Minimum 3 seconds before considering call "ended"
        private const val CALL_END_CONFIRMATION_TIME = 1500L  // Wait 1.5s for consistent end state
        
        // Debug configuration
        private const val DEBUG_DUMP_ENABLED = false  // Enable periodic UI tree dumps to logcat
        private const val DEBUG_DUMP_INTERVAL_MS = 1000L  // Dump interval (1 second)
        private const val DEBUG_MAX_NODES = 120  // Max nodes to dump per cycle
        private const val DEBUG_MAX_DEPTH = 6  // Max tree depth to traverse
        private const val DETECTION_ENABLED = true  // Master switch for call detection
        private const val DEBUG_COORDINATE_LOGGING = true  // Log coordinate tap actions
        
        // WeChat tap coordinates (absolute pixel positions for reference device)
        private const val WECHAT_TAP1_X = 86  // X coordinate for first tap ("Try" button)
        private const val WECHAT_TAP1_Y = 287  // Y coordinate for first tap
        private const val WECHAT_TAP2_X = 1015  // X coordinate for second tap (contact button)
        private const val WECHAT_TAP2_Y = 1844  // Y coordinate for second tap
        private const val WECHAT_TAP3_X = 663  // X coordinate for third tap (call button)
        private const val WECHAT_TAP3_Y = 1318  // Y coordinate for third tap
        
        // Static instance for cross-component communication
        private var instance: AccessibilityServices? = null
        
        fun getInstance(): AccessibilityServices? = instance
    }
    
    // Runtime state tracking
    private var isCallOngoing = false  // Whether a call is currently active
    private var callEndStartTime = 0L  // Timestamp when call end was first detected
    private var lastStateLogTime = 0L  // Last time we logged call state (throttling)
    private var callStartTime = 0L  // Timestamp when call started
    private var lastDumpTime = 0L  // Last time we dumped UI tree (debug)
    private var isWeChatSession = false  // Whether we're currently in WeChat app
    private var weChatTapStartTime = 0L  // Timestamp when WeChat session started
    private lateinit var coordinateScaler: CoordinateScaler  // Helper for coordinate scaling
    private lateinit var endCallHandler: EndCallHandler  // Dedicated handler for ending calls
    private lateinit var incomingCallHandler: IncomingCallHandler  // Dedicated handler for accepting incoming calls
    private lateinit var sendMessageHandler: SendMessageHandler  // Dedicated handler for auto-sending WhatsApp messages
    private var screenWidth = 0  // Current device screen width
    private var screenHeight = 0  // Current device screen height
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        
        // Store static instance for cross-component access
        instance = this
        
        // Initialize coordinate scaler
        coordinateScaler = CoordinateScaler(this)
        
        // Log screen size for coordinate scaling
        val displayMetrics = resources.displayMetrics
        screenWidth = displayMetrics.widthPixels
        screenHeight = displayMetrics.heightPixels
        Log.d(TAG, "📱 Screen size: ${screenWidth} x ${screenHeight} pixels")
        
        // Initialize end call handler
        endCallHandler = EndCallHandler(this)
        
        // Initialize incoming call handler
        incomingCallHandler = IncomingCallHandler(this)
        
        // Initialize send message handler
        sendMessageHandler = SendMessageHandler(this)
        
        // Store reference screen if not already set
        val (refWidth, refHeight) = coordinateScaler.getReferenceScreen()
        Log.d(TAG, "📍 Reference screen: ${refWidth} x ${refHeight} pixels")
        
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or 
                         AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                         AccessibilityEvent.TYPE_VIEW_CLICKED or
                         AccessibilityEvent.TYPE_TOUCH_INTERACTION_START
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                    AccessibilityServiceInfo.FLAG_REQUEST_TOUCH_EXPLORATION_MODE
            packageNames = arrayOf(WHATSAPP_PACKAGE, WHATSAPP_BUSINESS, WECHAT_PACKAGE)
        }
        serviceInfo = info
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val packageName = event.packageName?.toString() ?: return
        
        // Track if we're in WeChat
        if (packageName == WECHAT_PACKAGE) {
            if (!isWeChatSession) {
                isWeChatSession = true
                weChatTapStartTime = System.currentTimeMillis()
                if (DEBUG_COORDINATE_LOGGING) {
                    Log.d(TAG, "🟢 WeChat session started - starting tap sequence")
                }
                // Start the tap sequence
                performWeChatTapSequence()
            }
            return  // Don't process WeChat events further for now
        } else if (isWeChatSession) {
            isWeChatSession = false
            weChatTapStartTime = 0L
            if (DEBUG_COORDINATE_LOGGING) {
                Log.d(TAG, "🔴 WeChat session ended")
            }
        }
        
        // Only process WhatsApp events
        if (packageName != WHATSAPP_PACKAGE && packageName != WHATSAPP_BUSINESS) return
        
        rootInActiveWindow?.let { root ->
            // Check if we need to auto-send a message (SOS feature)
            if (sendMessageHandler.pendingSend) {
                sendMessageHandler.onWhatsAppEvent()
            }
            
            dumpUiOncePerSecond(root)
            if (!DETECTION_ENABLED) return

            // Only try to click call buttons if not already in a call
            if (!isCallOngoing) {
                clickCallButton(root)
                clickConfirmButton(root)
            }
            
            val callActive = detectCallActive(root)
            val callEnded = if (isCallOngoing) detectCallEnded(root) else false
            val currentTime = System.currentTimeMillis()
            
            if (currentTime - lastStateLogTime >= 1000) {
                Log.d(TAG, "📡 State: callActive=$callActive, callEnded=$callEnded, isCallOngoing=$isCallOngoing")
                lastStateLogTime = currentTime
            }
            
            when {
                callActive && !isCallOngoing -> {
                    isCallOngoing = true
                    callEndStartTime = 0L
                    callStartTime = currentTime
                    Log.d(TAG, "📞 Call started")
                }
                callEnded && isCallOngoing -> {
                    val callDuration = currentTime - callStartTime
                    
                    // If rejected/missed call was detected early, return immediately
                    val rejectedIndicators = listOf("取消", "取消", "重撥", "重拨", "錄製語音訊息", "录制语音消息")
                    val hasRejectedIndicator = root.findAccessibilityNodeInfosByText("取消").isNotEmpty() ||
                                               root.findAccessibilityNodeInfosByText("重撥").isNotEmpty()
                    
                    if (hasRejectedIndicator) {
                        isCallOngoing = false
                        callEndStartTime = 0L
                        Log.d(TAG, "📵 Rejected/Missed call - Returning to app immediately")
                        returnToMainApp()
                        return@let
                    }
                    
                    // For normal call ends, apply MIN_CALL_DURATION check
                    if (callDuration < MIN_CALL_DURATION) {
                        Log.d(TAG, "⏭️ Ignoring early call end detection (call duration: ${callDuration}ms, need ${MIN_CALL_DURATION}ms)")
                        return@let
                    }
                    
                    if (callEndStartTime == 0L) {
                        callEndStartTime = currentTime
                        Log.d(TAG, "⏳ Call end detected - waiting for confirmation...")
                    }
                    
                    val timeSinceCallEnded = currentTime - callEndStartTime
                    if (timeSinceCallEnded >= CALL_END_CONFIRMATION_TIME) {
                        isCallOngoing = false
                        callEndStartTime = 0L
                        Log.d(TAG, "📞 Call ended confirmed - Returning to app")
                        returnToMainApp()
                    }
                }
                callActive && isCallOngoing && callEndStartTime > 0L -> {
                    Log.d(TAG, "✓ Call UI detected - Reset end detection")
                    callEndStartTime = 0L
                }
            }
        }
    }
    
    override fun onInterrupt() {}
    
    // Dump all clickable/tappable elements with their coordinates
    private fun dumpClickableNodesWithCoordinates(node: android.view.accessibility.AccessibilityNodeInfo, depth: Int, maxDepth: Int = 8) {
        if (depth >= maxDepth) return
        
        val rect = android.graphics.Rect()
        node.getBoundsInScreen(rect)
        
        // Log any node that is clickable, focusable, or has text/description
        val isInteresting = node.isClickable || node.isFocusable || node.isLongClickable ||
                           !node.text.isNullOrEmpty() || !node.contentDescription.isNullOrEmpty()
        
        if (isInteresting) {
            val centerX = rect.centerX()
            val centerY = rect.centerY()
            val text = node.text?.toString()?.take(30) ?: ""
            val desc = node.contentDescription?.toString()?.take(30) ?: ""
            val className = node.className?.toString()?.split(".")?.lastOrNull() ?: "?"
            
            val flags = buildString {
                if (node.isClickable) append("C")
                if (node.isFocusable) append("F")
                if (node.isLongClickable) append("L")
            }
            
            val indent = "  ".repeat(depth)
            Log.d(TAG, "$indent📍 [$flags] X=$centerX Y=$centerY | $className | '$text' '$desc'")
        }
        
        // Recurse through children
        repeat(node.childCount) { i ->
            node.getChild(i)?.let { child ->
                dumpClickableNodesWithCoordinates(child, depth + 1, maxDepth)
                child.recycle()
            }
        }
    }

    // Temporary debug helper: dumps visible node texts/descriptions once per second.
    private fun dumpUiOncePerSecond(root: android.view.accessibility.AccessibilityNodeInfo) {
        if (!DEBUG_DUMP_ENABLED) return
        val now = System.currentTimeMillis()
        if (now - lastDumpTime < DEBUG_DUMP_INTERVAL_MS) return
        lastDumpTime = now
        var seen = 0
        fun walk(node: android.view.accessibility.AccessibilityNodeInfo, depth: Int) {
            if (seen >= DEBUG_MAX_NODES || depth >= DEBUG_MAX_DEPTH) return
            val rawText = node.text?.toString()?.trim().orEmpty()
            val rawDesc = node.contentDescription?.toString()?.trim().orEmpty()
            if (rawText.isNotEmpty() || rawDesc.isNotEmpty()) {
                val indent = " ".repeat(depth * 2)
                Log.d(TAG, "$indent• text='$rawText' desc='$rawDesc'")
                seen++
            }
            repeat(node.childCount) { i ->
                node.getChild(i)?.let { child ->
                    walk(child, depth + 1)
                    child.recycle()
                }
            }
        }
        Log.d(TAG, "===== UI DUMP (${DEBUG_MAX_NODES} nodes max) =====")
        walk(root, 0)
    }
    
    // Perform WeChat tap sequence to open contact and start call
    private fun performWeChatTapSequence() {
        // Tap sequence using absolute pixel coordinates
        // Tap 1: Try button (X=86, Y=287)
        // Tap 2: Contact button (X=1015, Y=1844)
        // Tap 3: Call button (X=663, Y=1318)
        
        Thread {
            try {
                // Wait 2 seconds for WeChat to load
                Log.d(TAG, "⏳ Waiting 2 seconds before tap 1...")
                Thread.sleep(2000)
                
                // Tap 1: Try button
                tapAtCoordinate(WECHAT_TAP1_X, WECHAT_TAP1_Y, 20)  // Quick 20ms tap
                Log.d(TAG, "✅ WeChat tap 1: X=$WECHAT_TAP1_X, Y=$WECHAT_TAP1_Y")
                
                // Wait 1 second before second tap
                Thread.sleep(1000)
                // Tap 2: Contact button
                tapAtCoordinate(WECHAT_TAP2_X, WECHAT_TAP2_Y, 50)  // Normal 50ms tap
                Log.d(TAG, "✅ WeChat tap 2: X=$WECHAT_TAP2_X, Y=$WECHAT_TAP2_Y")
                
                // Wait 1 second before third tap
                Thread.sleep(1000)
                // Tap 3: Call button
                tapAtCoordinate(WECHAT_TAP3_X, WECHAT_TAP3_Y, 50)  // Normal 50ms tap
                Log.d(TAG, "✅ WeChat tap 3: X=$WECHAT_TAP3_X, Y=$WECHAT_TAP3_Y")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error in WeChat tap sequence: ${e.message}")
            }
        }.start()
    }
    
    // Tap at specific coordinate using accessibility gesture
    private fun tapAtCoordinate(x: Int, y: Int, durationMs: Long = 50) {
        val gestureBuilder = android.accessibilityservice.GestureDescription.Builder()
        
        val path = android.graphics.Path()
        path.moveTo(x.toFloat(), y.toFloat())
        path.lineTo(x.toFloat(), y.toFloat())
        
        gestureBuilder.addStroke(
            android.accessibilityservice.GestureDescription.StrokeDescription(
                path,
                0,  // Start time
                durationMs  // Duration in milliseconds
            )
        )
        
        val gesture = gestureBuilder.build()
        dispatchGesture(gesture, null, null)
    }
    
    // End an active call by delegating to EndCallHandler
    // Supports WhatsApp, WeChat, and native phone dialer
    fun clickEndCallButton() {
        Log.d(TAG, "📴 End call requested - delegating to EndCallHandler")
        
        val success = endCallHandler.endCall()
        
        if (success) {
            // Reset call tracking state
            isCallOngoing = false
            callEndStartTime = 0L
            Log.d(TAG, "✅ End call action performed - call state reset")
        } else {
            Log.w(TAG, "⚠️ End call action could not be performed")
        }
    }
    
    // Accept an incoming call by delegating to IncomingCallHandler
    // Supports WhatsApp incoming call accept button
    fun acceptIncomingCall() {
        Log.d(TAG, "📞 Accept call requested - delegating to IncomingCallHandler")
        
        val success = incomingCallHandler.acceptCall()
        
        if (success) {
            Log.d(TAG, "✅ Accept call action performed")
        } else {
            Log.w(TAG, "⚠️ Accept call action could not be performed")
        }
    }
    
    // Arm auto-send for SOS message feature
    // After arming, the service watches WhatsApp for Send button and clicks it
    fun armAutoSendMessage() {
        Log.d(TAG, "📨 Auto-send message armed")
        sendMessageHandler.armAutoSend()
    }
    
    // Helper to find node by content description
    private fun findNodeByContentDescription(
        root: android.view.accessibility.AccessibilityNodeInfo,
        descriptions: List<String>,
        depth: Int = 0
    ): android.view.accessibility.AccessibilityNodeInfo? {
        if (depth > DEBUG_MAX_DEPTH) return null
        
        val contentDesc = root.contentDescription?.toString()?.lowercase() ?: ""
        for (desc in descriptions) {
            if (contentDesc.contains(desc.lowercase())) {
                return root
            }
        }
        
        for (i in 0 until root.childCount) {
            val child = root.getChild(i) ?: continue
            findNodeByContentDescription(child, descriptions, depth + 1)?.let { return it }
        }
        
        return null
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "🔴 Accessibility service destroyed")
    }}