# ESP32-S3 GPIO Pin Reference Guide

## Currently Used Pins

| GPIO | Function | Status | Notes |
|------|----------|--------|-------|
| **1** | Potentiometer (ADC1_CH0) | ✅ IN USE | Volume control analog input |
| **2** | PIR Motion Sensor | ✅ IN USE | Digital input (HIGH = motion) |v
| **4** | Button 1 (Slot 1) | ✅ IN USE | Active HIGH, INPUT_PULLDOWN |
| **5** | Button 2 (Slot 2) | ✅ IN USE | Active HIGH, INPUT_PULLDOWN |
| **6** | Button 3 (Slot 3) | ✅ IN USE | Active HIGH, INPUT_PULLDOWN |
| **7** | Button 4 (Prev Page) | ✅ IN USE | Active HIGH, INPUT_PULLDOWN |
| **8** | Button 5 (Next Page) | ✅ IN USE | Active HIGH, INPUT_PULLDOWN |
| **9** | Button 6 (End Call) | ✅ IN USE | Active HIGH, INPUT_PULLDOWN |

---

## Safe to Use Pins

These pins are **SAFE** for additional features (analog inputs, digital I/O, PWM, etc.):

| GPIO | Type | Notes |
|------|------|-------|
| **1** | ADC1_CH0 | Potentiometer (volume) - **IN USE** |
| **2** | ADC1_CH1 | PIR motion sensor - **IN USE** |
| **4** | ADC1_CH3 | Button 1 (Slot 1) - **IN USE** |
| **5** | ADC1_CH4 | Button 2 (Slot 2) - **IN USE** |
| **6** | ADC1_CH5 | Button 3 (Slot 3) - **IN USE** |
| **7** | ADC1_CH6 | Button 4 (Prev Page) - **IN USE** |
| **8** | ADC1_CH7 | Button 5 (Next Page) - **IN USE** |
| **9** | ADC1_CH8 | Button 6 (End Call) - **IN USE** |
| **10** | ADC1_CH9 | General purpose - available |
| **12** | ADC1_CH11 | General purpose - available |
| **13** | ADC1_CH12 | General purpose - available |
| **14** | Digital/ADC | General purpose - available |
| **15** | Digital/ADC | General purpose - available |
| **16** | Digital | General purpose - available |
| **17** | Digital | General purpose - available |
| **18** | Digital | General purpose - available |
| **19** | Digital | General purpose - available |
| **21** | Digital | General purpose - available |
| **33** | Digital | General purpose - available |
| **34** | Digital (input only) | No pullup/pulldown |
| **35** | Digital (input only) | No pullup/pulldown |
| **36** | Digital (input only) | No pullup/pulldown |
| **37** | Digital (input only) | No pullup/pulldown |
| **38** | Digital (input only) | No pullup/pulldown |
| **39** | Digital (input only) | No pullup/pulldown |
| **40** | Digital | General purpose - available |
| **43** | Digital | General purpose - available |
| **45** | Digital | General purpose - available |
| **46** | Digital | General purpose - available |
| **47** | Digital | General purpose - available |
| **48** | Digital | General purpose - available |

---

## ⚠️ UNSAFE / DO NOT USE Pins

### **Strapping Pins** (affect boot mode)
These pins must be in specific states during power-on:
- **GPIO 0** (IO0) - BOOT button strapping (LOW = download mode, HIGH = normal)
- **GPIO 3** (RX) - Serial RX strapping (must be HIGH at boot)

**Why unsafe**: Using these can prevent proper boot or interfere with programming.

### **USB and Serial Communication**
- **GPIO 41** (RTS) - Serial RTS line (your CH340 serial adapter)
- **GPIO 42** (TXD) - Serial TX line (your CH340 serial adapter)
- **GPIO 44** (RXD) - Serial RX line (your CH340 serial adapter)

**Why unsafe**: Interferes with USB communication and firmware uploads.

### **Flash Memory Interface**
Reserved for SPI flash storage:
- **GPIO 26, 27, 28, 29, 30, 31, 32** - SPI flash pins (PSRAM on some models)

**Why unsafe**: Interferes with firmware storage and execution.

### **Reserved for JTAG Debugging** (optional, but reserved)
- **GPIO 39** - JTAG data (optional, might not be used on your board)

**Why unsafe**: Interferes with hardware debugging (if you use it).

---

## How to Choose a Pin

### For a Second Power Switch or Feature:
**Best options (no side effects):**
- **GPIO 10** ✅ Safest - fully general purpose
- **GPIO 12-15** ✅ Safe - general purpose
- **GPIO 16-18** ✅ Safe - general purpose
- **GPIO 21** ✅ Safe - general purpose
- **GPIO 33, 40-48** ✅ Safe - general purpose

### For Analog Input (ADC):
Only use ADC1 pins (ADC2 conflicts with WiFi if enabled):
- **GPIO 1** (ADC1_CH0) - **IN USE for potentiometer**
- **GPIO 2** (ADC1_CH1) - **IN USE for PIR**
- **GPIO 3** (ADC1_CH2) - ⚠️ Strapping pin (unsafe)
- **GPIO 4** (ADC1_CH3) - **IN USE for button**
- **GPIO 5** (ADC1_CH4) - **IN USE for button**
- **GPIO 6** (ADC1_CH5) - **IN USE for button**
- **GPIO 7** (ADC1_CH6) - **IN USE for button**
- **GPIO 8** (ADC1_CH7) - **IN USE for button**
- **GPIO 9** (ADC1_CH8) - **IN USE for button**
- **GPIO 10** (ADC1_CH9) - ✅ **Available for new analog input**
- **GPIO 11** (ADC1_CH10) - **IN USE for power switch**
- **GPIO 12** (ADC1_CH11) - ✅ **Available for new analog input**
- **GPIO 13** (ADC1_CH12) - ✅ **Available for new analog input**

---

## Quick Reference Table

```
Safe for General Use:  1-2, 4-18, 21, 33-40, 43, 45-48
Safe for Analog:       1-2, 4-15 (various ADC1 channels)
DO NOT USE:            0, 3, 19-20, 26-32, 39, 41-42, 44
In Use by TapCall:     1-2 (sensors), 4-9 (buttons)
Available:             10-18, 21, 33, 40, 43, 45-48
```

---

## Example: Adding a New Feature on GPIO 10

```cpp
#define NEW_FEATURE_PIN 10

void setup() {
  pinMode(NEW_FEATURE_PIN, INPUT);  // or OUTPUT, INPUT_PULLUP, etc.
  // ... rest of setup
}

void loop() {
  int value = digitalRead(NEW_FEATURE_PIN);  // Read the pin
  // ... process value
}
```

---

## Notes

- **INPUT_PULLUP**: Adds internal 100kΩ pull-up resistor (pin reads HIGH when not connected)
- **INPUT_PULLDOWN**: Adds internal pull-down resistor (pin reads LOW when not connected) - only works on specific pins
- **INPUT**: No internal resistor - pin floats (unpredictable) if left unconnected
- **OUTPUT**: Pin driven by ESP32 (HIGH = 3.3V, LOW = 0V)

For physical buttons, use **INPUT_PULLDOWN** so pressing the button connects to 3.3V (active HIGH).

---

## Board Specs
- **Chip**: ESP32-S3 (dual-core, 240MHz)
- **GPIO Pins**: 48 total (0-48)
- **ADC Channels**: ADC1 (8 channels), ADC2 (10 channels)
- **PWM**: All GPIO support PWM
- **SPI/I2C**: Multiple interfaces available
- **UART**: Serial RX/TX for debugging and programming
