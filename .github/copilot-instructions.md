# TapCall AI Agent Guide

## Project Overview

TapCall is a dual-platform system enabling elderly users to make video calls via physical buttons. It consists of:
- **ESP32-S3 firmware** (PlatformIO/Arduino) that monitors GPIO buttons and transmits via BLE
- **Flutter mobile app** that receives BLE events and automates call launches using Android Accessibility Services

## Architecture & Data Flow

### BLE Communication Pipeline
1. Physical button press on ESP32 → GPIO pin state change (GPIO 1-9)
2. Firmware debounces (10ms press, 15ms release, 40ms refractory) → sends `BTN:N\n` or `REL:N\n` via NimBLE
3. Flutter app ([main.dart](mobile_app/lib/main.dart) `_BLEWrapperScreenState`) receives notification → triggers contact action
4. Platform channel invokes Kotlin accessibility service → automated UI taps in WhatsApp/WeChat

**Critical**: Slots 1-3 are function buttons (mapped to contacts on current page). Slot 252=end call, 253=SOS, 254=prev, 255=next are special buttons.

### Contact Storage & Mapping
- Contacts stored in `SharedPreferences` with keys `slot_{N}_name`, `slot_{N}_phone`, `slot_{N}_app`
- [ContactManager](mobile_app/lib/src/contact_manager.dart) handles CRUD operations for 100 slots
- Each contact has `FunctionType` (contact, time, weather, reminder, SOS)
- App type enum: `whatsapp`, `wechat`, `phone` (see [contact_manager.dart](mobile_app/lib/src/contact_manager.dart#L19-L26))

### Accessibility Automation Flow
1. Flutter calls Android method channel `com.tapcall.app/accessibility`
2. [AccessibilityServices.kt](mobile_app/android/app/src/main/kotlin/com/tapcall/app/AccessibilityServices.kt) monitors `TYPE_WINDOW_CONTENT_CHANGED` events
3. **WhatsApp**: Scans nodes for "call"/"通話" text → clicks via [CallLauncher.kt](mobile_app/android/app/src/main/kotlin/com/tapcall/app/CallLauncher.kt#L24-L38)
4. **WeChat**: Uses pixel-perfect coordinate taps (3-tap sequence at hardcoded X,Y) → [CoordinateScaler.kt](mobile_app/android/app/src/main/kotlin/com/tapcall/app/CoordinateScaler.kt) scales for device
5. Detects call end via timer disappearance → auto-returns to TapCall

## Critical Development Patterns

### ESP32 Firmware (PlatformIO)
**Build & Upload**:
```bash
cd /Users/tcp/Desktop/VideoCall
pio run --target upload
pio device monitor  # Serial monitor at 115200 baud
```

**Button Configuration**: Edit [main.cpp](src/main.cpp#L60-L67) `buttons[]` array:
```cpp
{GPIO_PIN, SLOT_NUMBER, false, false, 0, 0}
```
Use `INPUT_PULLDOWN` for 3-pin button modules (active HIGH). GPIO 4-9 are assigned to slots 1-3 + nav buttons.

**BLE Protocol**: Service UUID `4fafc201...`, TX characteristic `beb5483e...`. Message format: `BTN:255\n` (newline required).

### Flutter Mobile App
**Run on physical Android**:
```bash
cd mobile_app
flutter devices
flutter run -d <device-id>
flutter build apk --release  # Output: build/app/outputs/flutter-apk/app-release.apk
```

**Platform Channels**: Two method channels defined in [MainActivity.kt](mobile_app/android/app/src/main/kotlin/com/tapcall/app/MainActivity.kt):
- `com.tapcall.app/accessibility`: Check/enable accessibility service
- `com.tapcall.app/launcher`: Set screen size for coordinate scaling

**BLE Connection Logic**: [main.dart](mobile_app/lib/main.dart#L122-L147) auto-scans for devices named "esp32"/"tapcall"/"onetapcall" (case-insensitive). Connection persists via foreground service.

### Coordinate-Based Automation (WeChat)
**Reference device**: 1080x2400 px (hardcoded in [AccessibilityServices.kt](mobile_app/android/app/src/main/kotlin/com/tapcall/app/AccessibilityServices.kt#L42-L47))
- Tap 1 (86, 287): "Try" button
- Tap 2 (1015, 1844): Contact selector
- Tap 3 (663, 1318): Call button

To update coordinates for new device: Enable `DEBUG_COORDINATE_LOGGING = true`, run app, check logcat for scaled coords.

**Scaling logic**: [CoordinateScaler.kt](mobile_app/android/app/src/main/kotlin/com/tapcall/app/CoordinateScaler.kt) uses `SharedPreferences` keys `ref_screen_width`/`ref_screen_height`. Set via Settings screen or method channel.

## Common Workflows

### Adding a New Button to ESP32
1. Wire button to unused GPIO pin (e.g., GPIO 10)
2. Add entry to [main.cpp](src/main.cpp#L60-L67) `buttons[]`: `{10, 4, false, false, 0, 0}` (slot 4)
3. Recompile: `pio run -t upload`

### Ending a Call via GPIO Button (End Call Button - GPIO 9)
**Current Implementation**: GPIO 9 triggers BLE slot 252 which sends `BTN:252\n`
1. **Flutter receives**: [main.dart](mobile_app/lib/main.dart) `_handleButtonPress(252)` calls `_handleEndCall()`
2. **Method channel invokes**: `MethodChannel('com.tapcall.app/accessibility').invokeMethod('endCall')`
3. **Kotlin processes**: [MainActivity.kt](mobile_app/android/app/src/main/kotlin/com/tapcall/app/MainActivity.kt) `endCall` handler calls `endActiveCall()`
4. **Accessibility service executes**: [AccessibilityServices.kt](mobile_app/android/app/src/main/kotlin/com/tapcall/app/AccessibilityServices.kt) `clickEndCallButton()` finds and clicks the red end call button
   - Searches by text: "end call", "hang up", "结束通话" (multi-language)
   - Searches by content description
   - Falls back to coordinate tap at center-bottom of screen (85% down)

### Adding a New Contact Function Type
1. Add enum to [function_type.dart](mobile_app/lib/src/function_type.dart)
2. Update `Contact` class in [contact_manager.dart](mobile_app/lib/src/contact_manager.dart#L57-L82) with new fields
3. Modify `toJson`/`fromJson` serialization methods
4. Update UI in [contact_editor_dialog.dart](mobile_app/lib/screens/contact_editor_dialog.dart)

### Debugging BLE Issues
- **ESP32 side**: Serial monitor shows `TX (len=X) -> BTN:N\n` when sending
- **Flutter side**: Check `debugPrint` logs in [main.dart](mobile_app/lib/main.dart#L173-L210) for received bytes
- **Common issue**: Newline missing from BLE message → parser fails ([main.dart](src/main.cpp#L116-L120) uses `snprintf` with `\n`)

### Debugging Accessibility Automation
1. Enable `DEBUG_DUMP_ENABLED = true` in [AccessibilityServices.kt](mobile_app/android/app/src/main/kotlin/com/tapcall/app/AccessibilityServices.kt#L35)
2. Run `adb logcat | grep A11yServices` to see UI node tree
3. Check `isCallOngoing` state transitions (logged every 5 seconds)

## Project-Specific Conventions

- **No async/await in ESP32**: All BLE operations are synchronous; use `delay()` for timing
- **Debouncing is critical**: Physical buttons bounce; firmware enforces 40ms refractory period ([main.cpp](src/main.cpp#L76))
- **BLE cooldown on Flutter**: 2-second debounce at app level ([main.dart](main.dart#L69)) to prevent duplicate calls from hardware glitches
- **Accessibility service must be manually enabled**: No programmatic way to enable; app guides user to Settings
- **Foreground service required**: Android kills background BLE connections; [main.dart](mobile_app/lib/main.dart#L14-L31) starts persistent notification
- **Multi-language support**: Button text detection supports English + Traditional/Simplified Chinese ([CallLauncher.kt](mobile_app/android/app/src/main/kotlin/com/tapcall/app/CallLauncher.kt#L24-L27))

## Key Files Reference

| Component | File | Purpose |
|-----------|------|---------|
| ESP32 Main | [src/main.cpp](src/main.cpp) | Button monitoring + BLE transmission |
| BLE Connection | [mobile_app/lib/main.dart](mobile_app/lib/main.dart) | BLE client, message parsing, call routing |
| Accessibility | [AccessibilityServices.kt](mobile_app/android/app/src/main/kotlin/com/tapcall/app/AccessibilityServices.kt) | WhatsApp/WeChat UI automation |
| Contact Storage | [contact_manager.dart](mobile_app/lib/src/contact_manager.dart) | SharedPreferences CRUD for 100 slots |
| Coordinate Scaling | [CoordinateScaler.kt](mobile_app/android/app/src/main/kotlin/com/tapcall/app/CoordinateScaler.kt) | Device-independent tap positioning |

## External Dependencies

- **NimBLE-Arduino** (ESP32): Lightweight BLE stack, lower memory than Bluedroid
- **flutter_blue_plus**: Cross-platform BLE for iOS/Android
- **flutter_foreground_task**: Keeps service alive in background
- **Android Accessibility API**: Required for automated UI interactions (user must grant permission)

See [ANDROID_SETUP.md](ANDROID_SETUP.md) for deployment instructions and [FILE_REFERENCE.md](FILE_REFERENCE.md) for complete file manifest.
