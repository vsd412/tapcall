/*
===============================================================================
TapCall ESP32-S3 Firmware - ALL BUTTONS REPLACED WITH 4-LEG TACTILE SWITCHES
===============================================================================

Purpose:
- Monitors 8 tactile buttons (internal pull-up, active LOW)
- Transmits button press/release events via BLE
- Monitors potentiometer for volume
- Monitors PIR motion sensor for screen wake

Hardware:
- 8 x 4-leg tactile switches (pressed = LOW)
- 1 x Potentiometer (pin to be assigned)
- 1 x PIR sensor (pin to be assigned)
*/

#include <Arduino.h>
#include <NimBLEDevice.h>

// ===============================================================================
// PIN CONFIGURATION - ALL AS PLACEHOLDERS (ASSIGN LATER)
// ===============================================================================
// SAFE GPIO PINS FOR ESP32-S3-DevKitC-1:
//   Best choices: 3, 5, 6, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21
//   Also safe:    4, 7, 8, 9, 10, 11
//
//   AVOID: GPIO 0 (boot), GPIO 45, 46 (strapping), GPIO 48 (RGB LED)
// ===============================================================================

// Button array with placeholder pins
Btn buttons[] = {
  // Function buttons (slots 1-3 for current page display)
  {-1, 1, false, false, 0, 0}, // Button 1: Slot 1  ← CHANGE PIN HERE
  {-1, 2, false, false, 0, 0}, // Button 2: Slot 2  ← CHANGE PIN HERE
  {-1, 3, false, false, 0, 0}, // Button 3: Slot 3  ← CHANGE PIN HERE

  // Navigation buttons
  {-1, SLOT_PREV_PAGE, false, false, 0, 0}, // Button 4: Previous page  ← CHANGE PIN HERE
  {-1, SLOT_NEXT_PAGE, false, false, 0, 0}, // Button 5: Next page      ← CHANGE PIN HERE
  {-1, SLOT_END_CALL,  false, false, 0, 0}, // Button 6: End call       ← CHANGE PIN HERE
  {-1, SLOT_ACCEPT_CALL,false, false, 0, 0},// Button 7: Accept call    ← CHANGE PIN HERE
  {-1, SLOT_SOS,       false, false, 0, 0}, // Button 8: SOS            ← CHANGE PIN HERE
};

// BLE service and characteristic UUIDs
#define SERVICE_UUID           "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID_TX "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Button state structure
struct Btn {
  uint8_t pin;           // GPIO pin number
  uint8_t slot;          // Slot number sent to app
  bool pressed;          // Current debounced press state
  bool lastRaw;          // Previous raw pin reading
  uint32_t lastChange;   // Timestamp of last state change
  uint32_t lastRelease;  // Timestamp of last release
};

// Special slot numbers
#define SLOT_ACCEPT_CALL 251
#define SLOT_END_CALL    252
#define SLOT_SOS         253
#define SLOT_PREV_PAGE   254
#define SLOT_NEXT_PAGE   255

// Debouncing constants
constexpr uint32_t PRESS_DB = 10;
constexpr uint32_t REL_DB   = 15;
constexpr uint32_t REFRACT  = 40;
constexpr uint32_t LOOP_DELAY = 2;

// ===============================================================================
// Sensors - Now also using placeholders
constexpr bool ENABLE_POTENTIOMETER = true;
constexpr uint8_t POTENTIOMETER_PIN = -1;    // ← CHANGE PIN HERE (was GPIO 1)

constexpr uint8_t VOLUME_MIN = 0;
constexpr uint8_t VOLUME_MAX = 100;
constexpr uint8_t VOLUME_CHANGE_THRESHOLD = 2;
constexpr uint32_t VOLUME_POLL_INTERVAL = 50;
constexpr uint16_t ADC_MAX = 4095;
uint8_t lastVolumePercent = 0;
uint32_t lastVolumePoll = 0;

constexpr bool ENABLE_PIR = true;
constexpr uint8_t PIR_SENSOR_PIN = -1;       // ← CHANGE PIN HERE (was GPIO 2)
constexpr uint32_t PIR_HOLD_TIME = 1000;
bool lastPIRState = false;
uint32_t pirHighStartTime = 0;
bool pirTriggered = false;

// BLE variables
NimBLEServer* pServer = nullptr;
NimBLECharacteristic* pTx = nullptr;
bool deviceConnected = false;

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

// Active LOW detection for tactile switches
static inline bool rawPressed(const Btn& btn) {
  return digitalRead(btn.pin) == LOW;
}

void sendLine(const char* line) {
  if (!pTx) return;
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

void updateVolume() {
  uint16_t rawAdc = analogRead(POTENTIOMETER_PIN);
  uint8_t volumePercent = round((float)rawAdc / ADC_MAX * VOLUME_MAX);
  volumePercent = constrain(volumePercent, VOLUME_MIN, VOLUME_MAX);
  uint8_t difference = abs((int)volumePercent - (int)lastVolumePercent);
 
  if (difference > VOLUME_CHANGE_THRESHOLD) {
    char buf[12];
    snprintf(buf, sizeof(buf), "VOL:%u\n", volumePercent);
    Serial.printf("🔊 Volume changed: %u%% (ADC: %u)\n", volumePercent, rawAdc);
    sendLine(buf);
    lastVolumePercent = volumePercent;
  }
}

void checkPIRSensor() {
  uint32_t now = millis();
  bool currentPIRState = digitalRead(PIR_SENSOR_PIN) == HIGH;
 
  if (currentPIRState && !lastPIRState) {
    pirHighStartTime = now;
    pirTriggered = false;
  }
 
  if (currentPIRState && !pirTriggered) {
    if (now - pirHighStartTime >= PIR_HOLD_TIME) {
      Serial.println("👁️ PIR: Motion confirmed - sending wake command");
      sendLine("PIR:1\n");
      pirTriggered = true;
    }
  }
 
  if (!currentPIRState && lastPIRState) {
    Serial.println("👁️ PIR: Motion cleared");
    pirTriggered = false;
  }
 
  lastPIRState = currentPIRState;
}

void setup() {
  Serial.begin(115200);
  delay(150);

#ifdef RGB_BUILTIN
  neopixelWrite(RGB_BUILTIN, 0, 0, 0);
#else
  neopixelWrite(48, 0, 0, 0);
#endif

  Serial.println();
  Serial.println("=== TapCall ESP32-S3 Boot (All Pins as Placeholders) ===");
  Serial.printf("Heap: %u\n", ESP.getFreeHeap());

  // Initialize tactile buttons with internal pull-up
  for (auto &b : buttons) {
    if (b.pin != 255 && b.pin < 255 && b.pin != 0) {
      pinMode(b.pin, INPUT_PULLUP);
      Serial.printf("Tactile switch (slot %u) on GPIO %u → INPUT_PULLUP\n", b.slot, b.pin);
     
      b.lastRaw = rawPressed(b);
      b.pressed = false;
      b.lastChange = millis();
      b.lastRelease = 0;
    } else {
      Serial.printf("Button slot %u - Pin not assigned yet (placeholder -1)\n", b.slot);
    }
  }

  // Potentiometer setup
  if (ENABLE_POTENTIOMETER) {
    if (POTENTIOMETER_PIN != -1 && POTENTIOMETER_PIN != 0) {
      Serial.println("\n=== Potentiometer Volume Control ===");
      Serial.printf("Potentiometer on GPIO %u\n", POTENTIOMETER_PIN);
      analogSetAttenuation(ADC_11db);
      analogReadResolution(12);
      lastVolumePercent = round((float)analogRead(POTENTIOMETER_PIN) / ADC_MAX * VOLUME_MAX);
      lastVolumePoll = millis();
    } else {
      Serial.println("\n=== Potentiometer - Pin not assigned yet (-1) ===");
    }
  }

  // PIR setup
  if (ENABLE_PIR) {
    if (PIR_SENSOR_PIN != -1 && PIR_SENSOR_PIN != 0) {
      Serial.println("\n=== PIR Motion Sensor ===");
      Serial.printf("PIR sensor on GPIO %u\n", PIR_SENSOR_PIN);
      pinMode(PIR_SENSOR_PIN, INPUT);
      lastPIRState = digitalRead(PIR_SENSOR_PIN) == HIGH;
    } else {
      Serial.println("\n=== PIR Sensor - Pin not assigned yet (-1) ===");
    }
  }

  // BLE Setup
  NimBLEDevice::init("TapCall");
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
}

void loop() {
  uint32_t now = millis();

  // Button processing
  for (auto &b : buttons) {
    if (b.pin == 255 || b.pin >= 255 || b.pin == 0) continue; // Skip unassigned buttons

    bool r = rawPressed(b);
    if (r != b.lastRaw) {
      b.lastRaw = r;
      b.lastChange = now;
    }

    if (r && !b.pressed) {
      bool inRefract = (now - b.lastRelease) < REFRACT;
      if (!inRefract && (now - b.lastChange) >= PRESS_DB) {
        b.pressed = true;
       
        if (b.slot == SLOT_PREV_PAGE)      Serial.println("◀ Previous page");
        else if (b.slot == SLOT_NEXT_PAGE) Serial.println("▶ Next page");
        else if (b.slot == SLOT_SOS)       Serial.println("🏠 SOS");
        else if (b.slot == SLOT_END_CALL)  Serial.println("📴 End call");
        else if (b.slot == SLOT_ACCEPT_CALL) Serial.println("📞 Accept call");
        else Serial.printf("Button position %d pressed\n", b.slot);
       
        emitBtn(b.slot);
      }
    }
   
    if (!r && b.pressed) {
      if ((now - b.lastChange) >= REL_DB) {
        b.pressed = false;
        b.lastRelease = now;
        emitRel(b.slot);
      }
    }
  }
 
  if (ENABLE_POTENTIOMETER && (now - lastVolumePoll) >= VOLUME_POLL_INTERVAL) {
    updateVolume();
    lastVolumePoll = now;
  }
 
  if (ENABLE_PIR) {
    checkPIRSensor();
  }
 
  delay(LOOP_DELAY);
}