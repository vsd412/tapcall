# File Reference Guide

Complete listing and function of all files in the VideoCall project.

---

## **ESP32 Firmware**

### `src/main.cpp`
- **Function:** Core ESP32 firmware that monitors physical buttons and broadcasts button presses via BLE
- **Key Behavior:**
  - Initializes GPIO pins as button inputs
  - Detects button press/release with debouncing
  - Sends BLE notifications (`BTN:N\n` for press, `REL:N\n` for release)
  - Supports two input modes: active LOW (joystick) or active HIGH (button modules)
- **Configuration:** GPIO pins in `buttons[]` array; debounce constants at top
- **When to modify:** Adding/removing buttons, changing pin assignments, adjusting timing

### `platformio.ini`
- **Function:** Build configuration for ESP32 development
- **Key Settings:**
  - Platform: `esp32`
  - Board: `esp32-s3-devkitc-1`
  - Dependencies: NimBLE-Arduino for BLE
  - Upload speed: 921600 baud
- **When to modify:** Changing board type, adding dependencies, adjusting compiler flags

### `include/` (Directory)
- **Function:** Header files and custom library definitions
- **Contains:** Empty (placeholder for future custom headers)

### `lib/` (Directory)
- **Function:** Reusable libraries and configurations
- **Contains:**
  - `TFT_eSPI_Setup/User_Setup.h` - Display library configuration (future UART display integration)

### `test/` (Directory)
- **Function:** Test files and validation scripts
- **Status:** Minimal content (placeholder for future unit tests)

---

## **Flutter Mobile App - Dart/Flutter Code**

### `mobile_app/lib/main.dart`
- **Function:** App entry point and core BLE communication logic
- **Key Responsibilities:**
  - Initializes Flutter app and UI
  - Manages BLE scanning and connection to ESP32
  - Receives BLE notifications (`BTN:N` messages)
  - Routes button presses to contact actions
  - Manages foreground service for background BLE operation
- **When to modify:** Changing BLE behavior, adding new message types, modifying app startup

### **UI Screens** (`mobile_app/lib/screens/`)

#### `main_call_screen.dart`
- **Function:** Main screen with 9 call buttons (one per contact slot)
- **Key Features:**
  - Displays assigned contact name and app type per button
  - Triggers call action when button is pressed (from physical button or tap)
  - Shows connection status with ESP32
- **When to modify:** Changing button layout, adding visual effects, modifying call triggering logic

#### `contact_editor_dialog.dart`
- **Function:** Dialog for assigning a contact to a button slot
- **Key Features:**
  - Phone number input field
  - App type selector (WhatsApp or WeChat)
  - Contact photo picker (optional)
  - Saves contact to SharedPreferences
- **When to modify:** Adding new app types, changing UI fields, modifying validation

#### `contact_box.dart`
- **Function:** Reusable widget for displaying a single contact button
- **Key Features:**
  - Shows contact photo/initials
  - Displays contact name
  - Shows app type badge (WhatsApp/WeChat icon)
  - Handles tap/press events
- **When to modify:** Changing button appearance, adding animations, modifying touch feedback

#### `settings_screen.dart`
- **Function:** Settings and configuration screen
- **Key Features:**
  - Accessibility service enable/disable toggle
  - Screen size input dialog (width/height in pixels)
  - Language selection (UI language & TTS/voice language)
  - Contact management shortcuts
- **When to modify:** Adding new settings, changing UI language options, adding calibration tools

#### `reorder_screen.dart`
- **Function:** Allows user to reorder contact buttons (drag-and-drop)
- **Key Features:**
  - Drag-and-drop to reorder slots
  - Preview of new order
  - Persist reordered list to storage
- **When to modify:** Changing reorder UI, adding undo functionality

#### `debug_screen.dart`
- **Function:** Debug and testing utilities (optional)
- **Key Features:**
  - May contain logging, BLE state inspection, coordinate logging
- **When to modify:** Adding new debug features, removing when not needed

---

## **Flutter Mobile App - Core Services** (`mobile_app/lib/src/`)

### `contact_manager.dart`
- **Function:** Manages all contact data (CRUD operations)
- **Key Classes:**
  - `Contact` - Model for a single contact with phone number, app type, photo
  - `ContactManager` - Singleton that loads/saves contacts to SharedPreferences
- **Key Methods:**
  - `loadContacts()` - Load from storage
  - `saveContact(slot, contact)` - Save or update
  - `deleteContact(slot)` - Remove a contact
  - `getContact(slot)` - Retrieve a contact
- **When to modify:** Changing contact fields, adding new properties, modifying storage format

### `call_launcher.dart`
- **Function:** Launches calls by building and opening deeplinks
- **Key Methods:**
  - `launchWhatsAppCall(phoneNumber)` - Opens `https://wa.me/<number>`
  - `launchWeChatCall()` - Opens `weixin://`
  - `formatPhoneNumber(number)` - Converts to international format
- **When to modify:** Adding new app types, changing deeplink formats, modifying number formatting

### `launcher_helper.dart`
- **Function:** Flutter↔Android bridge for launcher and settings actions
- **Key Methods:**
  - `setScreenSize(width, height)` - Sends screen dimensions to native Android code
  - Invokes method channels to communicate with MainActivity
- **When to modify:** Adding new native method calls, changing parameter passing

### `accessibility_helper.dart`
- **Function:** Flutter↔Android bridge for accessibility service control
- **Key Methods:**
  - May include methods to enable/disable accessibility service
  - Checks if accessibility is currently enabled
- **When to modify:** Adding accessibility control features, changing permission requests

### `translations.dart`
- **Function:** All user-facing text strings (supports multiple languages)
- **Key Features:**
  - Separate UI language strings and TTS/voice language strings
  - Supports English, Traditional Chinese, Simplified Chinese (UI)
  - Supports English, Cantonese, Mandarin (TTS/Voice)
  - `Translations.get(key)` - Get UI text
  - `Translations.getTTS(key)` - Get voice text
- **When to modify:** Adding new languages, changing UI text, updating translations

### `language_helper.dart`
- **Function:** Manages UI and TTS language preferences
- **Key Classes:**
  - `UILanguage` enum - UI language options
  - `TTSLanguage` enum - Voice language options
- **When to modify:** Adding new language options, changing default language

### `tts_helper.dart`
- **Function:** Text-to-speech for reminders and announcements
- **Key Methods:**
  - `speak(text)` - Speak text using selected TTS language
  - `stop()` - Stop current speech
- **When to modify:** Adding new speech features, changing voice settings, supporting new languages

### `weather_helper.dart`
- **Function:** Fetches weather data (for weather button feature)
- **Key Methods:**
  - Likely retrieves current weather, location-based weather
- **When to modify:** Changing weather API, adding new weather features

### `location_helper.dart`
- **Function:** Gets device location (for location button feature)
- **Key Methods:**
  - `getLocation()` - Get current latitude/longitude
- **When to modify:** Changing location permissions, adding location features

### `contact.dart` (Models)
- **Function:** Data model for a contact
- **Key Fields:**
  - `name` - Contact name
  - `phoneNumber` - Phone number (WhatsApp) or WeChat ID
  - `appType` - WhatsApp or WeChat
  - `photoPath` - Path to contact photo
  - `functionType` - Type of function (contact call, reminder, etc.)
- **When to modify:** Adding new contact fields, changing data types

### `function_type.dart`
- **Function:** Enum defining what action a button can trigger
- **Key Types:**
  - `FunctionType.contact` - Call via WhatsApp/WeChat
  - `FunctionType.reminder` - Set a reminder
  - `FunctionType.emergencySos` - Emergency alert
  - Other types: weather, location, etc.
- **When to modify:** Adding new button action types

### `app_state.dart` (State Management)
- **Function:** Manages app-wide state (if using a state management library)
- **Key State:**
  - BLE connection status
  - Current contacts
  - Active settings
- **When to modify:** Adding new global state, changing state management approach

---

## **Flutter Services** (`mobile_app/lib/src/services/`)

### `contacts_storage.dart`
- **Function:** Persists contacts to device storage (SharedPreferences)
- **Key Methods:**
  - `saveContact(slot, contact)` - Write to storage
  - `loadContact(slot)` - Read from storage
  - `deleteContact(slot)` - Remove from storage
- **When to modify:** Changing storage format, migrating to different storage backend

### `launcher_service.dart`
- **Function:** Service for launching calls and external apps
- **Key Methods:**
  - Handles deeplink launches
  - May include retry logic for failed launches
- **When to modify:** Adding new app types, changing launch behavior

### `settings_service.dart`
- **Function:** Manages app settings (language, screen size, accessibility)
- **Key Methods:**
  - `saveUILanguage(lang)` - Save UI language preference
  - `saveTTSLanguage(lang)` - Save voice language preference
  - `saveScreenSize(width, height)` - Save screen dimensions
  - Load methods for each setting
- **When to modify:** Adding new settings, changing storage keys

---

## **Flutter Widgets** (`mobile_app/lib/src/widgets/`)

### `translated_text.dart`
- **Function:** Custom widget that displays translated text
- **Key Feature:**
  - Automatically uses current UI language
  - Updates when language changes
- **When to modify:** Customizing text styling, adding text features

---

## **Android/Kotlin Code** (`mobile_app/android/app/src/main/kotlin/com/tapcall/app/`)

### `MainActivity.kt`
- **Function:** Android entry point and Flutter↔Kotlin bridge
- **Key Responsibilities:**
  - Initializes Flutter engine
  - Sets up method channels for communication
  - Handles `setScreenSize` method calls from Flutter
  - Handles `endCall` method calls to trigger accessibility-based call termination
  - Stores screen dimensions via CoordinateScaler
- **Key Methods:**
  - `endActiveCall()` - Routes endCall request from Flutter to AccessibilityServices
- **When to modify:** Adding new method channels, handling new settings, Android-specific initialization

### `AccessibilityServices.kt`
- **Function:** Main orchestrator for call automation and accessibility
- **Key Responsibilities:**
  - Watches WhatsApp foreground events
  - Detects call start and end states
  - Performs global Back action to return to app after call
  - Opens WeChat and performs timed tap sequence
  - Logs UI element details for debugging
  - Ends active calls via `clickEndCallButton()` method
- **Key Methods:**
  - `performWeChatTapSequence()` - Execute three taps with delays
  - `tapAtCoordinate(x, y, duration)` - Inject accessibility tap gesture
  - `detectCallActive()` - Check if WhatsApp call is ongoing
  - `detectCallEnded()` - Check if WhatsApp call has ended
  - `clickEndCallButton()` - Find and click end call button (triggered by GPIO 9, slot 252)
- **Configuration:**
  - Tap coordinates (constants lines 26-31): X/Y pixel positions
  - Tap delays (constants): 2s wait, then 1s between taps
  - Tap durations: 20ms for tap 1, 50ms for taps 2-3
- **When to modify:** Changing WhatsApp detection logic, adjusting WeChat taps, modifying delays/timing

### `ReturnAfterEndCall.kt`
- **Function:** Call state detection utility
- **Key Methods:**
  - `detectCallActive(node)` - Recursively scan UI tree for in-call indicators
  - `detectCallEnded(node)` - Recursively scan UI tree for call-ended indicators
- **Detection Signals:**
  - In-call: Timer display, "正在說話", accessibility descriptions like "離開通話"
  - Call-ended: Chat indicators like "訊息", "更多選項", rejected/missed indicators
- **When to modify:** Adding new detection signals, changing sensitivity, adjusting thresholds

### `CoordinateScaler.kt`
- **Function:** Converts tap coordinates for different screen sizes
- **Key Responsibilities:**
  - Stores reference screen dimensions (1080x1920) in SharedPreferences
  - Converts percentage-based coordinates to absolute pixels
  - Handles screen size mismatch for different devices
- **Key Methods:**
  - `getAbsoluteCoordinates(percentX, percentY, screenWidth, screenHeight)` - Convert to pixels
  - `getReferenceScreen()` - Get stored reference dimensions
  - `setReferenceScreen(width, height)` - Store new reference
- **When to modify:** Changing coordinate conversion logic, adjusting scaling formula

### `CallLauncher.kt`
- **Function:** Alternative/legacy call launching (may be redundant with call_launcher.dart)
- **Status:** May not be actively used; check if needed
- **When to modify:** Removing if redundant, or updating if using native call launching

---

## **Android Configuration** (`mobile_app/android/`)

### `app/src/main/AndroidManifest.xml`
- **Function:** Android app manifest with permissions and service declarations
- **Key Declarations:**
  - Permissions: BLUETOOTH, ACCESS_FINE_LOCATION, CALL_PHONE, BIND_ACCESSIBILITY_SERVICE
  - Services: AccessibilityServices
  - Activities: MainActivity
  - Uses-feature: BLUETOOTH_LE
- **When to modify:** Adding new permissions, registering new services, changing app properties

### `app/src/main/res/xml/accessibility_service.xml`
- **Function:** Configuration for the accessibility service
- **Key Settings:**
  - Event types to listen for (window changes, state changes, touch interaction)
  - Feedback type
  - Flags for interactive windows and touch exploration
- **When to modify:** Changing which events the service listens to, adjusting service capabilities

### `app/src/main/res/xml/accessibility_service_config.xml`
- **Function:** Alternative accessibility service configuration (may be deprecated)
- **Status:** Verify if still needed or if can be consolidated with accessibility_service.xml

### `app/build.gradle.kts`
- **Function:** Gradle build configuration for Android app
- **Key Settings:**
  - Target SDK, min SDK, compile SDK
  - Dependencies (Flutter, plugins)
  - Build types and flavors
- **When to modify:** Updating target API level, adding native dependencies, changing build settings

### `gradle.properties`
- **Function:** Gradle properties and plugin versions
- **When to modify:** Changing Gradle plugin versions, adjusting build properties

### `settings.gradle.kts`
- **Function:** Gradle multi-project configuration
- **When to modify:** Adding new modules or sub-projects

---

## **Flutter Configuration**

### `mobile_app/pubspec.yaml`
- **Function:** Flutter project configuration and dependencies
- **Key Dependencies:**
  - `flutter_blue_plus` - BLE communication
  - `url_launcher` - Launch WhatsApp/WeChat deeplinks
  - `flutter_foreground_task` - Background BLE service
  - `shared_preferences` - Contact and settings storage
  - `flutter_tts` - Text-to-speech
  - `intl` - Date/time formatting
  - `permission_handler` - Request permissions
  - `image_picker` - Contact photo selection
  - `package_info_plus` - App version info
  - Other plugins as needed
- **When to modify:** Adding new packages, updating dependency versions, removing unused plugins

### `mobile_app/analysis_options.yaml`
- **Function:** Dart/Flutter linter and analyzer configuration
- **Key Settings:**
  - Lint rules
  - Code style preferences
- **When to modify:** Adjusting code style rules, enabling/disabling specific lints

### `mobile_app/devtools_options.yaml`
- **Function:** DevTools configuration (Flutter debugging)
- **When to modify:** Adjusting DevTools settings for development

---

## **Documentation**

### `CALLING_GUIDE.md`
- **Function:** User-facing guide explaining how WhatsApp and WeChat calling works
- **Covers:**
  - Deeplink explanation
  - WhatsApp direct calling flow
  - WeChat guided tap flow and screen scaling
  - Accessibility service explanation
  - Contact configuration
  - Settings and screen size adjustment
  - Troubleshooting and FAQ
  - Reference app analysis (apktool reverse engineering notes)
- **When to update:** Adding new features, clarifying user workflows, updating troubleshooting

### `ANDROID_SETUP.md`
- **Function:** Developer guide for setting up Android development environment
- **Covers:**
  - Installing Android SDK, Flutter, development tools
  - Connecting physical Android devices
  - USB debugging setup
  - Building and running the app
- **When to update:** Changing setup process, new tool versions, new setup steps

### `SIMPLE_WIRING.md`
- **Function:** Hardware wiring guide for connecting physical buttons to ESP32
- **Covers:**
  - Button-to-GPIO connections
  - Debounce capacitor recommendations
  - Wiring diagrams and pinouts
- **When to update:** Adding new button configurations, changing wiring recommendations

### `ESP32_PIN_MAPPING.md`
- **Function:** Reference of GPIO pin assignments for ESP32
- **Covers:**
  - All 9 button GPIO pins
  - Pin descriptions and usage
  - Hardware compatibility notes
- **When to update:** Changing button pin assignments, adding new pins

### `BUTTON_SETUP_5BTN.md`
- **Function:** Example configuration for a 5-button setup
- **Covers:**
  - GPIO pin assignments for 5 buttons
  - Software configuration in platformio.ini
  - Testing and validation
- **When to update:** Creating new example configurations, clarifying setup steps

### `系統介紹.md`
- **Function:** System introduction in Traditional Chinese (legacy/reference)
- **Status:** May be outdated; kept for reference
- **When to update:** If maintaining Chinese documentation

### `HOME_BUTTON_DETECTION_REFERENCE.md`
- **Function:** Documentation of Home button detection approach (deprecated)
- **Status:** Archived - Home button interception was deemed unreliable and not shipped
- **Purpose:** Reference for why this approach was not used

### `Reference Code.md`
- **Function:** Code snippets and references from development (legacy)
- **Status:** Archive - historical reference

---

## **Build & Artifacts**

### `mobile_app/build/`
- **Function:** Compiled output and build artifacts
- **Status:** Auto-generated by Flutter/Gradle; safe to delete and rebuild
- **Contents:**
  - APK outputs
  - Build intermediates
  - Plugin compiled code

### `.pio/`
- **Function:** PlatformIO build cache and artifacts
- **Status:** Auto-generated; safe to delete and rebuild

### `.github/`
- **Function:** GitHub Actions CI/CD configuration
- **Contents:** Workflow files for automated builds/tests
- **When to modify:** Setting up CI/CD pipelines

### `.vscode/`
- **Function:** VS Code workspace settings
- **Contents:** Recommended extensions, debugging config
- **When to modify:** Changing IDE settings, adding debug configurations

### `.gitignore`
- **Function:** Git ignore rules
- **When to modify:** Excluding new build artifacts or generated files

---

## **Development Scripts**

### `check_usb_cable.sh`
- **Function:** Bash script to verify USB cable and ADB connection
- **Usage:** Run to diagnose USB/ADB issues
- **When to use:** Troubleshooting connection problems

### `debug_monitor.sh`
- **Function:** Bash script to open ESP32 serial monitor
- **Usage:** View ESP32 debug output
- **When to use:** Debugging ESP32 firmware

---

## **Quick Navigation**

| Task | Go To |
|------|-------|
| Modify UI buttons/screens | `mobile_app/lib/screens/` |
| Change how contacts are stored | `mobile_app/lib/src/contact_manager.dart` |
| Adjust WhatsApp detection | `mobile_app/android/.../ReturnAfterEndCall.kt` |
| Modify WeChat taps | `mobile_app/android/.../AccessibilityServices.kt` |
| Add/change button GPIO pins | `src/main.cpp` |
| Update translations | `mobile_app/lib/src/translations.dart` |
| Configure build settings | `mobile_app/pubspec.yaml` & `platformio.ini` |
| Update user documentation | `CALLING_GUIDE.md` |
| Hardware wiring reference | `SIMPLE_WIRING.md` |

