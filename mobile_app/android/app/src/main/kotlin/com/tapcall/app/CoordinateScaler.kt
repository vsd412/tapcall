/*
TapCall Coordinate Scaler (Android/Kotlin)

Purpose:
- Manages coordinate scaling for tap actions across different Android device screen sizes
- Stores reference dimensions (from calibration device) in SharedPreferences
- Converts between absolute pixels and percentage-based coordinates

Use Case:
- WeChat tap coordinates are recorded on one device (reference device)
- CoordinateScaler allows those coordinates to work on ANY Android device
- Converts reference coordinates to percentage → scales to target device pixels

Key Methods:
1. setReferenceScreen(width, height): Store reference device dimensions
2. getReferenceScreen(): Retrieve stored reference dimensions (defaults: 1080x1920)
3. toPercentage(x, y): Convert absolute pixels to percentage (0.0 to 1.0)
4. toAbsolute(xPercent, yPercent, currentW, currentH): Convert percentage to target pixels
5. getAbsoluteCoordinates(): Convenience wrapper for toAbsolute

Storage:
- Uses SharedPreferences ("coordinate_prefs") for persistent storage
- Keys: "reference_width", "reference_height"
- Default fallback: 1080x1920 if no reference stored

Example:
- Reference device: 1080x1920, tap at (540, 960) → 50%, 50%
- Target device: 1440x2560 → scaled to (720, 1280)

Notes:
- Currently not used for WeChat (using absolute coordinates instead)
- Useful for future multi-device tap coordinate support
*/

package com.tapcall.app

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

class CoordinateScaler(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("coordinate_prefs", Context.MODE_PRIVATE)
    private val TAG = "CoordinateScaler"
    
    companion object {
        // SharedPreferences keys
        private const val KEY_REF_WIDTH = "reference_width"
        private const val KEY_REF_HEIGHT = "reference_height"
        // Default dimensions (Full HD portrait)
        private const val DEFAULT_WIDTH = 1080
        private const val DEFAULT_HEIGHT = 1920
    }
    
    /**
     * Store the reference screen dimensions (usually from the calibration phone).
     * These dimensions are used as the baseline for percentage calculations.
     */
    fun setReferenceScreen(width: Int, height: Int) {
        prefs.edit().apply {
            putInt(KEY_REF_WIDTH, width)
            putInt(KEY_REF_HEIGHT, height)
            apply()
        }
        Log.d(TAG, "🔧 Stored reference screen: ${width}x${height}")
    }
    
    /**
     * Get stored reference dimensions
     */
    fun getReferenceScreen(): Pair<Int, Int> {
        val width = prefs.getInt(KEY_REF_WIDTH, DEFAULT_WIDTH)
        val height = prefs.getInt(KEY_REF_HEIGHT, DEFAULT_HEIGHT)
        return Pair(width, height)
    }
    
    /**
     * Convert absolute pixel coordinates to percentage-based (0.0 to 1.0)
     * Used when recording coordinates on a reference device
     */
    fun toPercentage(x: Int, y: Int): Pair<Double, Double> {
        val (refWidth, refHeight) = getReferenceScreen()
        val xPercent = x.toDouble() / refWidth
        val yPercent = y.toDouble() / refHeight
        return Pair(xPercent, yPercent)
    }
    
    /**
     * Convert percentage-based coordinates back to absolute pixels on current screen
     * Used when performing taps on any device
     */
    fun toAbsolute(xPercent: Double, yPercent: Double, currentWidth: Int, currentHeight: Int): Pair<Int, Int> {
        val x = (xPercent * currentWidth).toInt()
        val y = (yPercent * currentHeight).toInt()
        return Pair(x, y)
    }
    
    /**
     * Convenience method: convert and tap in one step
     * Given percentage coordinates, convert to absolute for current screen
     */
    fun getAbsoluteCoordinates(xPercent: Double, yPercent: Double, currentWidth: Int, currentHeight: Int): Pair<Int, Int> {
        return toAbsolute(xPercent, yPercent, currentWidth, currentHeight)
    }
}
