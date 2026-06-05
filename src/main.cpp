/*
===============================================================================
TapCall ESP32-S3 Firmware
===============================================================================

Purpose:
- Monitors physical buttons connected to ESP32 GPIO pins
- Transmits button press/release events to Flutter app via BLE (Bluetooth Low Energy)
- Monitors analog potentiometer for volume control
- Supports two hardware configurations: joystick method (active LOW) or button modules (active HIGH)

Hardware Configuration:
- GPIO pins 4-11 are assigned to specific button slots/functions
- Each pin can trigger either a function slot (1-3), navigation, or SOS
- Uses 3-pin button modules (VCC/OUT/GND, active HIGH with INPUT_PULLDOWN)
- Potentiometer analog input on GPIO 1 (ADC1_CH0) for volume control
- PIR motion sensor on GPIO 2 for screen wake detection

BLE Communication Protocol:
- Service UUID: 4fafc201-1fb5-459e-8fcc-c5c9c331914b
- Characteristic UUID (TX): beb5483e-36e1-4688-b7f5-ea07361b26a8
- Message format: 
  - "BTN:N\n" (button pressed) or "REL:N\n" (button released)
  - "VOL:N\n" (volume control, N is 0-100)
  - "PIR:1\n" (motion detected - wake screen)
  - N is the slot number (1-3 for functions, 253=home, 254=prev page, 255=next page)

Button Debouncing:
- PRESS_DB: 10ms debounce delay before registering a press
- REL_DB: 15ms debounce delay before registering a release
- REFRACT: 40ms refractory period between presses to prevent double-triggers

Potentiometer Volume Control:
- Physical Potentiometer: Dual potentiometer with 6 pins
  - Pin Configuration: OTA (output), VCC (power), GND (ground), OTB (unused), VCC, GND
  - Using Channel OTA for volume control
  - Maximum voltage: 3.3V (ESP32 supply)
  - Minimum voltage: 0V (GND)
- Wiring:
  - Potentiometer OTA → GPIO 1 (ADC1_CH0, analog input)
  - Potentiometer VCC → 3.3V power
  - Potentiometer GND → GND (ground)
  - OTB, and extra VCC/GND pins: UNUSED (can be left disconnected)
- Analog to Digital Conversion:
  - ADC resolution: 12-bit (0-4095)
  - Top voltage (4095): Volume 100
  - Zero voltage (0): Volume 0
  - Linear interpolation: volume = (adc_value / 4095.0) * 100
- Debouncing: Only send new volume value if it changed by > 2% to reduce BLE traffic

Notes:
- Device advertises as "OneTapCall"
- Auto-reconnects when disconnected
- Serial output at 115200 baud for debugging
*/

#include <Arduino.h>
#include <NimBLEDevice.h>

// BLE service and characteristic UUIDs (must match Flutter app)
#define SERVICE_UUID           "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID_TX "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Hardware: 3-pin button modules with VCC/OUT/GND (active HIGH)
// Uses INPUT_PULLDOWN configuration - pin reads HIGH when button pressed

// Button state structure - tracks each physical button's state and timing
struct Btn {
  uint8_t pin;           // GPIO pin number (e.g., 4, 5, 6...)
  uint8_t slot;          // Slot number sent to app (1-3 for functions, 253-255 for navigation)
  bool pressed;          // Current debounced press state
  bool lastRaw;          // Previous raw pin reading
  uint32_t lastChange;   // Timestamp of last state change (for debouncing)
  uint32_t lastRelease;  // Timestamp of last release (for refractory period)
};

// Special slot numbers for navigation buttons (outside normal 1-100 range)
#define SLOT_ACCEPT_CALL 251 // Accept incoming call button - answers incoming call
#define SLOT_END_CALL  252  // End call / reject call button - terminates or rejects call
#define SLOT_SOS       253  // SOS emergency button (GPIO 11)
#define SLOT_PREV_PAGE 254  // Previous page button - navigates backward
#define SLOT_NEXT_PAGE 255  // Next page button - navigates forward

// Button array: defines all physical buttons with their GPIO pins and assigned slots
// Each entry: {GPIO_PIN, SLOT_NUMBER, initial_state, raw_state, timestamps}
Btn buttons[] = {
  // Function buttons (slots 1-3 for current page display)
  {11,  1, false, false, 0, 0},             // Button 1: Slot 1 (GPIO11)
  {8,  2, false, false, 0, 0},             // Button 2: Slot 2 (GPIO8)
  {4,  3, false, false, 0, 0},             // Button 3: Slot 3 (GPIO4)
  // Navigation buttons
  {7,  SLOT_PREV_PAGE, false, false, 0, 0},    // Button 4: Previous page (GPIO7)
  {8,  SLOT_NEXT_PAGE, false, false, 0, 0},    // Button 5: Next page (GPIO8)
  {9,  SLOT_END_CALL, false, false, 0, 0},     // Button 6: End call / reject (GPIO9)
  {10, SLOT_ACCEPT_CALL, false, false, 0, 0},  // Button 7: Accept incoming call (GPIO10)
  {11, SLOT_SOS, false, false, 0, 0},           // Button 8: SOS emergency (GPIO11)
};

// Debouncing and timing constants (all in milliseconds)
constexpr uint32_t PRESS_DB = 10;    // Debounce delay for button press detection
constexpr uint32_t REL_DB   = 15;    // Debounce delay for button release detection
constexpr uint32_t REFRACT  = 40;    // Refractory period between presses (anti-bounce)
constexpr uint32_t LOOP_DELAY = 2;   // Main loop delay to reduce CPU usage

// ===============================================================================
// Potentiometer Volume Control Configuration
// ===============================================================================
// Hardware: Dual potentiometer (6-pin module) - uses OTA channel only
// Pin Assignments:
//   - Potentiometer OTA (output/wiper) → GPIO 1 (ADC1_CH0)
//   - Potentiometer VCC                → 3.3V power
//   - Potentiometer GND                → GND (ground)
//   - Potentiometer OTB, extra VCC/GND → UNUSED (not connected)
// 
// Analog-to-Digital Conversion:
//   - ADC channel: ADC1_CH0 (GPIO 1)
//   - ADC resolution: 12-bit (0-4095)
//   - Reference voltage: 3.3V (Attenuation: 11dB)
//   - Raw range: 0-4095 maps to Volume: 0-100
//   
// Volume Control Logic:
//   - Potentiometer wiper at top voltage (3.3V): ADC reads ~4095 → Volume 100% ✓
//   - Potentiometer wiper at zero voltage (0V): ADC reads ~0 → Volume 0% ✓
//   - Linear interpolation: volume = round((adc_raw / 4095.0) * 100.0)
//
// Debouncing Strategy:
//   - Only send "VOL:N\n" command if volume changes by > 2% (reduces BLE traffic)
//   - Update interval: ~50ms to avoid flooding BLE with small changes
//
// Testing:
//   1. Upload firmware
//   2. Open Serial Monitor (115200 baud)
//   3. Rotate potentiometer and observe "VOL:N" messages
//   4. Verify volume ranges from 0 to 100

// Set to true when potentiometer hardware is physically connected to GPIO 1
// Set to false to disable volume reading (prevents noise from floating pin)
constexpr bool ENABLE_POTENTIOMETER = true;

constexpr uint8_t POTENTIOMETER_PIN = 1;      // GPIO 1 = ADC1_CH0 (analog input for volume)
constexpr uint8_t VOLUME_MIN = 0;             // Minimum volume percentage
constexpr uint8_t VOLUME_MAX = 100;           // Maximum volume percentage
constexpr uint8_t VOLUME_CHANGE_THRESHOLD = 2; // Only send update if change > 5% (reduces lag)
constexpr uint32_t VOLUME_POLL_INTERVAL = 50;  // Read analog input every 100ms (smoother, less lag)
constexpr uint16_t ADC_MAX = 4095;            // 12-bit ADC: 0 to 4095

// Potentiometer state tracking
uint8_t lastVolumePercent = 0;                // Last volume value sent tou app (0-100)
uint32_t lastVolumePoll = 0;                  // Timestamp of last analog read

// ===============================================================================
// PIR Motion Sensor Configuration (Passive Infrared)
// ===============================================================================
// Hardware: PIR motion sensor module (4-pin: GND, NC, OUT, VCC)
// Pin Assignments:
//   - PIR OUT (signal output) → GPIO 2 (digital input)
//   - PIR VCC                 → 5V or 3.3V power (check sensor specs, most support both)
//   - PIR GND                 → GND (ground)
//   - PIR NC (not connected)  → Leave unconnected
//
// Detection Logic:
//   - PIR OUT = HIGH when motion/person detected
//   - PIR OUT = LOW when no motion (after timeout period, usually 2-5 seconds)
//
// Purpose:
//   - Wake phone screen when elderly person approaches device
//   - Improves accessibility - no need to touch phone to see screen
//   - Sends "PIR:1\n" when motion detected
//   - Sends "PIR:0\n" when motion clears (optional, for logging)
//
// Debouncing:
//   - PIR modules have built-in retriggering logic
//   - Software hold: 1000ms sustained HIGH required before triggering
//   - Only sends once per detection event (waits for LOW before re-triggering)
//
// Wiring:
//   PIR Sensor → ESP32-S3
//   OUT        → GPIO 2
//   VCC        → 3.3V (or 5V if sensor requires it - most are 3.3V compatible)
//   GND        → GND
//   NC         → (leave unconnected)

// Set to true when PIR motion sensor is physically connected to GPIO 2
// Set to false to disable PIR reading (prevents noise from floating pin)
constexpr bool ENABLE_PIR = true;

constexpr uint8_t PIR_SENSOR_PIN = 2;              // GPIO 2 (digital input for PIR signal)
constexpr uint32_t PIR_HOLD_TIME = 1000;           // Require HIGH for 1 second before triggering
bool lastPIRState = false;                         // Last PIR state (false=no motion, true=motion)
uint32_t pirHighStartTime = 0;                     // When PIR first went HIGH (for sustained detection)
bool pirTriggered = false;                         // Has this HIGH period already triggered?


// BLE connection state and pointers
NimBLEServer* pServer = nullptr;              // BLE server instance
NimBLECharacteristic* pTx = nullptr;          // TX characteristic for sending data to app
bool deviceConnected = false;                 // Connection status flag

class ServerCB : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer* s, ble_gap_conn_desc* desc) override {
    deviceConnected = true;
    Serial.println("✓ Device connected");
  }
  void onDisconnect(NimBLEServer* s) override {
    deviceConnected = false;
    Serial.println("✗ Device disconnected");
    NimBLEDevice::startAdvertising();
    Serial.println("Advertising restarted");
  }
};

static inline bool rawPressed(const Btn& btn) {
  // Button modules: Active HIGH (pressed = HIGH)
  return digitalRead(btn.pin) == HIGH;
}

void sendLine(const char* line) {
  if (!pTx) return;
  // Use explicit length to avoid any implicit truncation
  size_t len = strlen(line);
  pTx->setValue((uint8_t*)line, len);
  pTx->notify();
  Serial.print("TX (len=");
  Serial.print(len);
  Serial.print(") -> ");
  Serial.print(line);
}

void emitBtn(uint8_t slot) {
  char buf[12];
  snprintf(buf, sizeof(buf), "BTN:%u\n", slot);
  Serial.printf("Button %u pressed\n", slot);
  sendLine(buf);
}
void emitRel(uint8_t slot) {
  char buf[12];
  snprintf(buf, sizeof(buf), "REL:%u\n", slot);
  Serial.printf("Button %u released\n", slot);
  sendLine(buf);
}

// ===============================================================================
// Volume Control Functions
// ===============================================================================

/// Reads the potentiometer analog value and sends volume command to Flutter app
/// if volume has changed significantly (> VOLUME_CHANGE_THRESHOLD %)
/// 
/// Algorithm:
/// 1. Read ADC value from potentiometer (GPIO 1)
/// 2. Convert raw ADC reading (0-4095) to volume percentage (0-100)
/// 3. Compare with last sent value
/// 4. If change >= threshold, send "VOL:N\n" command via BLE
/// 5. Update lastVolumePercent for next comparison
void updateVolume() {
  // Read analog input from potentiometer
  // analogRead(GPIO1) returns 0-4095 (12-bit ADC)
  uint16_t rawAdc = analogRead(POTENTIOMETER_PIN);
  
  // Convert raw ADC value to volume percentage (0-100)
  // Formula: volume = (adc_raw / 4095) * 100
  // Rounding ensures smooth percentage jumps (0-100)
  uint8_t volumePercent = round((float)rawAdc / ADC_MAX * VOLUME_MAX);
  
  // Clamp to valid range (handles edge cases)
  volumePercent = constrain(volumePercent, VOLUME_MIN, VOLUME_MAX);
  
  // Check if volume changed significantly (by > threshold)
  // This reduces BLE traffic by ignoring small fluctuations due to ADC noise
  uint8_t difference = abs((int)volumePercent - (int)lastVolumePercent);
  
  if (difference > VOLUME_CHANGE_THRESHOLD) {
    // Send volume command to Flutter app
    // Format: "VOL:N\n" where N is 0-100
    char buf[12];
    snprintf(buf, sizeof(buf), "VOL:%u\n", volumePercent);
    
    Serial.printf("🔊 Volume changed: %u%% (ADC: %u)\n", volumePercent, rawAdc);
    sendLine(buf);
    
    // Update last sent value for next comparison
    lastVolumePercent = volumePercent;
  }
}

// ===============================================================================
// PIR Motion Sensor Functions
// ===============================================================================

/// Checks PIR sensor and sends wake command to Flutter app when motion detected
/// Requires sustained HIGH for 1 second to filter out false triggers
/// 
/// Algorithm:
/// 1. Read digital state from PIR sensor (GPIO 2)
/// 2. Track when HIGH state begins (pirHighStartTime)
/// 3. Only trigger if HIGH is sustained for >= 1000ms (PIR_HOLD_TIME)
/// 4. Send "PIR:1\n" command to wake phone screen
/// 5. Wait for PIR to go LOW before allowing next detection
void checkPIRSensor() {
  uint32_t now = millis();
  bool currentPIRState = digitalRead(PIR_SENSOR_PIN) == HIGH;
  
  // Transition: LOW → HIGH (person approaching)
  if (currentPIRState && !lastPIRState) {
    pirHighStartTime = now;
    pirTriggered = false;
  }
  
  // Sustained HIGH detection: held for 1+ second
  if (currentPIRState && !pirTriggered) {
    if (now - pirHighStartTime >= PIR_HOLD_TIME) {
      Serial.println("👁️ PIR: Motion confirmed - sending wake command");
      sendLine("PIR:1\n");
      pirTriggered = true;
    }
  }
  
  // Transition: HIGH → LOW (person moved away or sensor reset)
  if (!currentPIRState && lastPIRState) {
    Serial.println("👁️ PIR: Motion cleared");
    pirTriggered = false;
  }
  
  // Update last state for next comparison
  lastPIRState = currentPIRState;
}

void setup() {
  Serial.begin(115200);
  delay(150);

  // Turn off the built-in RGB NeoPixel LED on GPIO 48 (very bright, not needed)
#ifdef RGB_BUILTIN
  neopixelWrite(RGB_BUILTIN, 0, 0, 0);
#else
  neopixelWrite(48, 0, 0, 0);
#endif

  Serial.println();
  Serial.println("=== TapCall ESP32-S3 Boot ===");
  Serial.printf("Heap: %u\n", ESP.getFreeHeap());

  // Initialize buttons
  for (auto &b : buttons) {
    pinMode(b.pin, INPUT_PULLDOWN);  // Button modules: internal pulldown, reads HIGH when pressed
    Serial.printf("Btn slot %u on GPIO %u configured (INPUT_PULLDOWN)\n", b.slot, b.pin);
    
    b.lastRaw = rawPressed(b);
    b.pressed = false;
    b.lastChange = millis();
    b.lastRelease = 0;
    
    Serial.printf("  Initial state: %s\n", b.lastRaw ? "PRESSED" : "released");
  }

  // Initialize potentiometer for volume control
  if (ENABLE_POTENTIOMETER) {
    Serial.println();
    Serial.println("=== Potentiometer Volume Control Setup ===");
    Serial.printf("Analog pin: GPIO %u (ADC1_CH0)\n", POTENTIOMETER_PIN);
    Serial.printf("Expected behavior:\n");
    Serial.printf("  - Top voltage (3.3V) → Volume 100%%\n");
    Serial.printf("  - Zero voltage (0V)  → Volume 0%%\n");
    Serial.printf("  - Threshold: %u%% change before sending update\n", VOLUME_CHANGE_THRESHOLD);
    Serial.printf("  - Poll interval: %ums\n", VOLUME_POLL_INTERVAL);
    Serial.println("Testing: Rotate potentiometer and watch Serial output");
    
    // Configure ADC for analog reading
    // Set 11dB attenuation for full 0-3.3V range
    analogSetAttenuation(ADC_11db);
    analogReadResolution(12);  // 12-bit resolution (0-4095)
    
    // Read initial value
    lastVolumePercent = round((float)analogRead(POTENTIOMETER_PIN) / ADC_MAX * VOLUME_MAX);
    lastVolumePoll = millis();
  } else {
    Serial.println();
    Serial.println("=== Potentiometer DISABLED (no hardware connected) ===");
  }

  // Initialize PIR motion sensor
  if (ENABLE_PIR) {
    Serial.println();
    Serial.println("=== PIR Motion Sensor Setup ===");
    Serial.printf("PIR pin: GPIO %u (digital input)\n", PIR_SENSOR_PIN);
    Serial.printf("Expected behavior:\n");
    Serial.printf("  - Motion detected → Phone screen wakes up\n");
    Serial.printf("  - Hold time: %ums (must hold position for this long)\n", PIR_HOLD_TIME);
    Serial.printf("  - Detection range: ~3-7 meters\n");
    Serial.println("Testing: Hold hand in front of sensor for 1+ second");
    
    // Configure PIR sensor pin as input
    pinMode(PIR_SENSOR_PIN, INPUT);
    
    // Read initial state
    lastPIRState = digitalRead(PIR_SENSOR_PIN) == HIGH;
    Serial.printf("  Initial state: %s\n", lastPIRState ? "MOTION DETECTED" : "no motion");
  } else {
    Serial.println();
    Serial.println("=== PIR Motion Sensor DISABLED (no hardware connected) ===");
  }

  NimBLEDevice::init("TapCall");
  // Set max TX power (valid constants: ESP_PWR_LVL_N12, N9, N6, N3, P0, P3, P6, P9)
  NimBLEDevice::setPower(ESP_PWR_LVL_P9);

  pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new ServerCB());
  NimBLEService* svc = pServer->createService(SERVICE_UUID);

  pTx = svc->createCharacteristic(CHARACTERISTIC_UUID_TX, NIMBLE_PROPERTY::NOTIFY);

  svc->start();
  NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  NimBLEDevice::startAdvertising();

  Serial.println("Advertising as TapCall");
  Serial.println("Waiting for BLE central...");
}

void loop() {
  uint32_t now = millis();

  // ===============================================================================
  // Button Processing: Detect presses and releases with debouncing
  // ===============================================================================
  for (auto &b : buttons) {
    bool r = rawPressed(b);
    if (r != b.lastRaw) {
      b.lastRaw = r;
      b.lastChange = now;
    }

    if (r && !b.pressed) {
      bool inRefract = (now - b.lastRelease) < REFRACT;
      if (!inRefract && (now - b.lastChange) >= PRESS_DB) {
        b.pressed = true;
        
        // Navigation buttons send special codes
        if (b.slot == SLOT_PREV_PAGE) {
          Serial.println("◀ Previous page button pressed");
          emitBtn(b.slot);  // Send 254
        } 
        else if (b.slot == SLOT_NEXT_PAGE) {
          Serial.println("▶ Next page button pressed");
          emitBtn(b.slot);  // Send 255
        }
        else if (b.slot == SLOT_SOS) {
          Serial.println("🏠 Home button pressed");
          emitBtn(b.slot);  // Send 253
        }
        else if (b.slot == SLOT_END_CALL) {
          Serial.println("📴 End call / reject button pressed");
          emitBtn(b.slot);  // Send 252
        }
        else if (b.slot == SLOT_ACCEPT_CALL) {
          Serial.println("📞 Accept call button pressed");
          emitBtn(b.slot);  // Send 251
        }
        else {
          // Function buttons: send position (1, 2, or 3)
          // App will map this to the correct slot based on page & sort order
          Serial.printf("Button position %d pressed\n", b.slot);
          emitBtn(b.slot);  // Send 1, 2, or 3
        }
      }
    }
    if (!r && b.pressed) {
      if ((now - b.lastChange) >= REL_DB) {
        b.pressed = false;
        b.lastRelease = now;
        emitRel(b.slot);  // Always send the slot value (position or nav code)
      }
    }
  }
  
  // ===============================================================================
  // Potentiometer Volume Control: Poll analog input at regular intervals
  // ===============================================================================
  // Read potentiometer every VOLUME_POLL_INTERVAL milliseconds
  // Only sends BLE command if volume changes by > threshold (reduces wireless traffic)
  if (ENABLE_POTENTIOMETER && (now - lastVolumePoll) >= VOLUME_POLL_INTERVAL) {
    updateVolume();
    lastVolumePoll = now;
  }
  
  // ===============================================================================
  // PIR Motion Sensor: Check for motion detection
  // ===============================================================================
  // PIR sensor is checked every loop iteration for immediate response
  // Built-in debouncing prevents spam from continuous detection
  if (ENABLE_PIR) {
    checkPIRSensor();
  }
  
  delay(LOOP_DELAY);
}