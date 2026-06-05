# Android Setup Guide

## Running on Physical Android Phone

### Prerequisites
1. **Enable Developer Options on your Android phone:**
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times until you see "You are now a developer!"

2. **Enable USB Debugging:**
   - Go to Settings → Developer Options
   - Enable "USB Debugging"
   - Enable "Install via USB" (if available)

3. **Connect via USB:**
   - Connect phone to computer via USB cable
   - On phone, tap "Allow USB Debugging" when prompted
   - Select "Always allow from this computer" and tap OK

### Deploy to Physical Phone

1. **Check device is connected:**
   ```bash
   cd ~/Desktop/VideoCall/mobile_app
   flutter devices
   ```
   You should see your phone model listed.

2. **Run the app:**
   ```bash
   flutter run
   ```
   Or specify your device:
   ```bash
   flutter run -d <device-id>
   ```

3. **Build APK for installation:**
   ```bash
   flutter build apk --release
   ```
   APK location: `build/app/outputs/flutter-apk/app-release.apk`

4. **Build App Bundle (for Google Play):**
   ```bash
   flutter build appbundle --release
   ```
   Bundle location: `build/app/outputs/bundle/release/app-release.aab`

### Common Issues

**Device not detected:**
- Try different USB cable (some cables are charge-only)
- Revoke USB debugging authorizations: Settings → Developer Options → Revoke USB debugging authorizations
- Restart ADB: `flutter doctor -v` or `adb kill-server && adb start-server`

**Installation failed:**
- Uninstall existing app first
- Check phone storage space
- Disable "Verify apps over USB" in Developer Options

---

## Running on Android Emulator

### Setup Emulator (One-time)

1. **List available emulators:**
   ```bash
   flutter emulators
   ```

2. **Create new emulator (if needed):**
   ```bash
   flutter emulators --create --name pixel_6
   ```

3. **Launch emulator:**
   ```bash
   flutter emulators --launch <emulator-id>
   ```
   Or use Android Studio: Tools → Device Manager → Create/Launch

### Deploy to Emulator

1. **Start emulator first** (Android Studio or command above)

2. **Check emulator is running:**
   ```bash
   flutter devices
   ```
   Should show: `sdk gphone64 arm64 (mobile) • emulator-5554`

3. **Run the app:**
   ```bash
   cd ~/Desktop/VideoCall/mobile_app
   flutter run -d emulator-5554
   ```

### Emulator Tips

- **Hot reload:** Press `r` in terminal during development
- **Hot restart:** Press `R` in terminal
- **Quit:** Press `q` in terminal
- **Clear screen:** Press `c` in terminal

---

## App Permissions Required

The app requires these permissions (auto-requested at runtime):
- **Bluetooth** - For BLE connection to ESP32
- **Location** - For weather feature (background location)
- **Phone** - For making WhatsApp calls
- **Camera** - For contact photos (if using camera)
- **Storage** - For selecting contact photos

---

## Development Workflow

### Test on Emulator
```bash
cd ~/Desktop/VideoCall/mobile_app
flutter run -d emulator-5554
```

### Test on Phone
```bash
cd ~/Desktop/VideoCall/mobile_app
flutter run
# Select device when prompted, or use device ID
```

### Build Release APK
```bash
cd ~/Desktop/VideoCall/mobile_app
flutter build apk --release
```
APK: `build/app/outputs/flutter-apk/app-release.apk`

### Install APK on Phone
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Troubleshooting

### Check Flutter/Android Setup
```bash
flutter doctor -v
```

### View Logs (while app running)
```bash
flutter logs
```

### Clear Flutter Cache
```bash
cd ~/Desktop/VideoCall/mobile_app
flutter clean
flutter pub get
```

### Restart ADB
```bash
adb kill-server
adb start-server
```

---

## Quick Reference

| Command | Action |
|---------|--------|
| `flutter devices` | List connected devices |
| `flutter run` | Run on default device |
| `flutter run -d <id>` | Run on specific device |
| `r` | Hot reload (while running) |
| `R` | Hot restart (while running) |
| `q` | Quit app |
| `flutter build apk` | Build release APK |
| `flutter clean` | Clean build cache |
| `adb devices` | List ADB devices |
