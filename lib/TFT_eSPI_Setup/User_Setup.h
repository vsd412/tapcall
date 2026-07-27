// TFT_eSPI User Setup for LT7689 TFT Display
// This file configures the TFT_eSPI library for your specific display

#define USER_SETUP_INFO "User_Setup"

// Define the display driver
#define ILI9341_DRIVER    // Generic driver that works with LT7689

// ESP32 Pin definitions
#define TFT_MISO 19  // Not used for this display
#define TFT_MOSI 23  // SDA pin
#define TFT_SCLK 18  // SCL pin
#define TFT_CS   2   // Chip select control pin
#define TFT_DC   15  // Data Command control pin (changed from 4 to avoid conflict)
#define TFT_RST  16  // Reset pin (could connect to RST pin)

// Optional backlight control
#define TFT_BL   17  // LED back-light control pin

// Color depth
#define COLOR_ORDER_BGR

// Fonts to be available
#define LOAD_GLCD   // Font 1. Original Adafruit 8 pixel font needs ~1820 bytes in FLASH
#define LOAD_FONT2  // Font 2. Small 16 pixel high font, needs ~3534 bytes in FLASH
#define LOAD_FONT4  // Font 4. Medium 26 pixel high font, needs ~5848 bytes in FLASH
#define LOAD_FONT6  // Font 6. Large 48 pixel high font, needs ~2666 bytes in FLASH
#define LOAD_FONT7  // Font 7. 7 segment 48 pixel high font, needs ~2438 bytes in FLASH
#define LOAD_FONT8  // Font 8. Large 75 pixel high font needs ~3256 bytes in FLASH

// Enable smooth fonts
#define SMOOTH_FONT

// SPI frequency
#define SPI_FREQUENCY  40000000  // 40MHz - adjust if display has issues
#define SPI_READ_FREQUENCY  20000000