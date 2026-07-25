import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:volume_controller/volume_controller.dart';
import 'src/contact_manager.dart';
import 'src/app_launcher.dart';
import 'src/tts.dart';
import 'src/open_accessibility_service.dart';
import 'screens/main_call_screen.dart';
import '../src/translations.dart';

void main() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'ble_call_service',
      channelName: 'BLE Call Service',
      channelDescription: 'Keeps BLE connection alive',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: false,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TapCall',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const BLEWrapperScreen(),
    );
  }
}

class BLEWrapperScreen extends StatefulWidget {
  const BLEWrapperScreen({super.key});

  @override
  State<BLEWrapperScreen> createState() => _BLEWrapperScreenState();
}

class _BLEWrapperScreenState extends State<BLEWrapperScreen> {
  final ContactManager _contactManager = ContactManager();
  final TTS _tts = TTS(); // For SOS announcements
  BluetoothDevice? _connectedDevice;
  List<BluetoothService> _services = [];
  StreamSubscription<List<int>>? _buttonSubscription;
  bool _isConnecting = false;
  DateTime? _lastCallTime;
  int? _lastButtonPressed;
  DateTime? _lastBLEMessageTime; // BLE-level debouncing
  int? _lastBLEButtonNumber;
  bool _isProcessingBLE = false; // Mutex to prevent parallel processing
  static const _callCooldown = Duration(seconds: 3);
  static const _bleCooldown = Duration(milliseconds: 2000); // Increased to prevent hardware duplicates
  List<ScanResult> _scannedDevices = [];
  bool _isScanning = false;
  Function(int)? _onButtonPressCallback;
  int _callbackId = 0; // Track which callback is current

  String _bluetoothDeviceTitle = "";
  String _bluetoothDeviceScan = "";
  String _bluetoothDeviceScanning = "";
  String _bluetoothDeviceEmpty = "";
  String _bluetoothDeviceUnknown = "";
  String _bluetoothDeviceSignal = "";
  String _bluetoothDeviceClose = "";
  String _bluetoothDeviceConnected = "";
  String _bluetoothDeviceName = "";
  String _buttonSOSMissingTTS = "";
  String _buttonSOSCallingTTS = "";
  String _callReadyTitle = "";
  String _callReadyDescription = "";
  String _deviceConnectedTitle = "";
  String _deviceConnectedDescription = "";

  Future<void> _loadTranslations() async {
    final results = await Future.wait([
      Translations.get('bluetoothDeviceTitle'),
      Translations.get('bluetoothDeviceScan'),
      Translations.get('bluetoothDeviceScanning'),
      Translations.get('bluetoothDeviceEmpty'),
      Translations.get('bluetoothDeviceUnknown'),
      Translations.get('bluetoothDeviceSignal'),
      Translations.get('bluetoothDeviceClose'),
      Translations.get('bluetoothDeviceConnected'),
      Translations.get('bluetoothDeviceName'),
      Translations.getTTS2('buttonSOSMissing'),
      Translations.getTTS2('buttonSOSCalling'),
      Translations.get('_callReadyTitle'),
      Translations.get('_callReadyDescription'),
      Translations.get('_deviceConnectedTitle'),
      Translations.get('_deviceConnectedDescription'),
    ]);

    setState(() {
      _bluetoothDeviceTitle = results[0];
      _bluetoothDeviceScan = results[1];
      _bluetoothDeviceScanning = results[2];
      _bluetoothDeviceEmpty = results[3];
      _bluetoothDeviceUnknown = results[4];
      _bluetoothDeviceSignal = results[5];
      _bluetoothDeviceClose = results[6];
      _bluetoothDeviceConnected = results[7];
      _bluetoothDeviceName = results[8];
      _buttonSOSMissingTTS = results[9];
      _buttonSOSCallingTTS = results[10];
      _callReadyTitle = results[11];
      _callReadyDescription = results[12];
      _deviceConnectedTitle = results[13];
      _deviceConnectedDescription = results[14];
    });

  }

  @override
  void initState() {
    super.initState();
    _loadTranslations();
    _initBLE();
  }

  @override
  void dispose() {
    _buttonSubscription?.cancel();
    _disconnectDevice();
    WakelockPlus.disable();
    FlutterForegroundTask.stopService();
    super.dispose();
  }

  Future<void> _initBLE() async {
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.phone,
    ];

    for (var permission in permissions) {
      final status = await permission.request();
      if (!status.isGranted) {
        debugPrint('Permission not granted: $permission');
      }
    }

    WakelockPlus.enable();

    await FlutterForegroundTask.startService(
      notificationTitle: _callReadyTitle,
      notificationText: _callReadyDescription,
    );

    _autoConnectToDevice();
  }

  Future<void> _autoConnectToDevice() async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      FlutterBluePlus.scanResults.listen((results) async {
        for (var result in results) {
          final deviceName = result.device.platformName.toLowerCase();
          // Only connect to TapCall device, not all esp32 devices
          if (deviceName == 'tapcall') {
            await FlutterBluePlus.stopScan();
            await _connectToDevice(result.device);
            break;
          }
        }
      });

      await Future.delayed(const Duration(seconds: 12));
      if (_connectedDevice == null && mounted) {
        _autoConnectToDevice();
      }
    } catch (e) {
      debugPrint('Scan error: $e');
      await Future.delayed(const Duration(seconds: 5));
      _autoConnectToDevice();
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 15));
      setState(() {
        _connectedDevice = device;
      });

      _services = await device.discoverServices();
      _setupButtonCharacteristic();

      await FlutterForegroundTask.updateService(
        notificationTitle: '$_deviceConnectedTitle ${device.platformName}',
        notificationText: _deviceConnectedDescription,
      );

      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && mounted) {
          setState(() {
            _connectedDevice = null;
          });
          _autoConnectToDevice();
        }
      });
    } catch (e) {
      debugPrint('Connection error: $e');
      await Future.delayed(const Duration(seconds: 5));
      _autoConnectToDevice();
    }
  }

  void _setupButtonCharacteristic() {
    // CRITICAL: Cancel any existing subscription before creating new one
    _buttonSubscription?.cancel();
    _buttonSubscription = null;
    debugPrint('🔄 Setting up BLE button characteristic...');

    for (var service in _services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          characteristic.setNotifyValue(true);
          _buttonSubscription = characteristic.lastValueStream.listen((value) {
            if (value.isNotEmpty) {
              // Parse "BTN:1\n" or "REL:1\n" or "VOL:50\n" or "PIR:1\n" format
              final message = String.fromCharCodes(value).trim();

              if (message.startsWith('BTN:')) {
                final slotStr = message.substring(4);
                final buttonNum = int.tryParse(slotStr);
                if (buttonNum != null) {
                  // MUTEX: Prevent parallel processing of BLE messages
                  if (_isProcessingBLE) {
                    debugPrint('🚫 BLE MUTEX: Already processing, ignoring BTN:$buttonNum');
                    return;
                  }

                  // BLE-level debouncing: Ignore if same button within cooldown
                  final now = DateTime.now();
                  if (_lastBLEMessageTime != null && _lastBLEButtonNumber == buttonNum) {
                    final elapsed = now.difference(_lastBLEMessageTime!);
                    if (elapsed < _bleCooldown) {
                      debugPrint('🚫 BLE DEBOUNCE: Ignoring duplicate BTN:$buttonNum (${elapsed.inMilliseconds}ms < ${_bleCooldown.inMilliseconds}ms)');
                      return; // CRITICAL: Exit immediately, don't process
                    }
                  }

                  // Set mutex and update tracking IMMEDIATELY
                  _isProcessingBLE = true;
                  _lastBLEMessageTime = now;
                  _lastBLEButtonNumber = buttonNum;

                  debugPrint('Received BLE message: $message');

                  _handleButtonPress(buttonNum).whenComplete(() {
                    _isProcessingBLE = false;
                  });
                }
              } else if (message.startsWith('VOL:')) {
                // Volume control from potentiometer
                final volumeStr = message.substring(4);
                final volumePercent = int.tryParse(volumeStr);
                if (volumePercent != null && volumePercent >= 0 && volumePercent <= 100) {
                  _handleVolumeChange(volumePercent);
                }
              } else if (message.startsWith('PIR:')) {
                // Motion detection from PIR sensor
                final pirValue = message.substring(4);
                if (pirValue == '1') {
                  _handleMotionDetected();
                }
              }
              // Ignore REL: messages
            }
          });
          debugPrint('Subscribed to button characteristic');
          break;
        }
      }
    }
  }

  Future<void> _handleButtonPress(int buttonNum) async {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('\n╔═══════════════════════════════════════════════════════════');
    debugPrint('║ 🔔 BLE BUTTON PRESS DETECTED');
    debugPrint('║ Timestamp: $timestamp');
    debugPrint('║ Button Number: $buttonNum');
    debugPrint('║ Device: ${_connectedDevice?.platformName ?? "none"}');
    debugPrint('║ Callback registered: ${_onButtonPressCallback != null ? "YES" : "NO"}');
    debugPrint('╚═══════════════════════════════════════════════════════════');

    // Handle special buttons (252=end call, 253=SOS, 254=prev, 255=next)
    if (buttonNum == 252) {
      debugPrint('📴 END CALL button pressed - ending active call');
      await _handleEndCall();
      debugPrint('═══════════════════════════════════════════════════════════\n');
      return;
    }
    if (buttonNum == 253) {
      debugPrint('🆘 SOS button pressed - making emergency call');
      await _handleSOSCall();
      debugPrint('═══════════════════════════════════════════════════════════\n');
      return;
    }
    if (buttonNum == 254) {
      debugPrint('◀️ PREVIOUS PAGE button pressed');
      if (_onButtonPressCallback != null) {
        _onButtonPressCallback!(-1); // Special signal for previous page
      } else {
        debugPrint('❌ ERROR: Callback is null!');
      }
      debugPrint('═══════════════════════════════════════════════════════════\n');
      return;
    }
    if (buttonNum == 255) {
      debugPrint('▶️ NEXT PAGE button pressed');
      if (_onButtonPressCallback != null) {
        _onButtonPressCallback!(-2); // Special signal for next page
      } else {
        debugPrint('❌ ERROR: Callback is null!');
      }
      debugPrint('═══════════════════════════════════════════════════════════\n');
      return;
    }

    // Check accessibility service status
    final isAccessibilityEnabled = await AccessibilityService.isServiceEnabled();
    debugPrint('🔍 Accessibility Service Status: ${isAccessibilityEnabled ? "ENABLED ✅" : "DISABLED ❌"}');

    debugPrint('🔍 Callback registered: ${_onButtonPressCallback != null ? "YES ✅" : "NO ❌"}');

    // Debounce: Ignore if same button pressed within cooldown period
    final now = DateTime.now();
    if (_lastCallTime != null && _lastButtonPressed == buttonNum) {
      final timeSinceLastCall = now.difference(_lastCallTime!);
      if (timeSinceLastCall < _callCooldown) {
        debugPrint('⏸️  COOLDOWN ACTIVE: Ignoring repeated button press');
        debugPrint('   Time since last: ${timeSinceLastCall.inSeconds}s / ${_callCooldown.inSeconds}s');
        debugPrint('═══════════════════════════════════════════════════════════\n');
        return;
      }
    }

    // Update last call tracking
    _lastCallTime = now;
    _lastButtonPressed = buttonNum;

    // Use callback if available (preferred - has TTS and visual feedback)
    if (_onButtonPressCallback != null) {
      debugPrint('📱 Using MainCallScreen callback for full TTS/visual feedback');
      _onButtonPressCallback!(buttonNum);
      debugPrint('═══════════════════════════════════════════════════════════\n');
      return;
    }

    // Fallback: direct call without TTS/visual feedback
    debugPrint('⚠️  Callback not available, using FALLBACK method');
    await _contactManager.loadContacts();
    final contact = _contactManager.getContact(buttonNum);

    if (contact != null) {
      debugPrint('📞 Making call to: ${contact.name}');
      debugPrint('   Phone: ${contact.phoneNumber}');
      debugPrint('   App: ${contact.appType.displayName}');

      // Reset accessibility service state before making call
      debugPrint('🔄 Resetting accessibility service state...');
      await AccessibilityService.resetCallState();

      debugPrint('🚀 Launching call...');
      final success = await AppLauncher.makeCall(
        contact.appType,
        contact.phoneNumber ?? '',
        '852', // Hong Kong country code hardcoded
      );
      debugPrint('📊 Call launch result: ${success ? "SUCCESS ✅" : "FAILED ❌"}');
    } else {
      debugPrint('❌ No contact assigned to button $buttonNum');
    }
    debugPrint('═══════════════════════════════════════════════════════════\n');
  }

  Future<void> _handleSOSCall() async {
    debugPrint('╔═══════════════════════════════════════════════════════════');
    debugPrint('║ 🆘 SOS EMERGENCY CALL INITIATED');
    debugPrint('╚═══════════════════════════════════════════════════════════');

    // Load SOS contact from storage
    final sosContact = await _contactManager.getSOSContact();

    if (sosContact == null || sosContact.phoneNumber == null || sosContact.phoneNumber!.isEmpty) {
      debugPrint('❌ SOS contact not configured');
      // Show error via TTS
      await _tts.speak(_buttonSOSMissingTTS);
      return;
    }

    debugPrint('📞 SOS Contact: ${sosContact.name}');
    debugPrint('📱 Phone: ${sosContact.phoneNumber}');

    // TTS announcement
    await _tts.speak('$_buttonSOSCallingTTS ${sosContact.name}');

    // Make WhatsApp video call
    debugPrint('🚀 Launching SOS WhatsApp call...');
    final success = await AppLauncher.makeCall(
      AppType.whatsapp,  // Use WhatsApp for SOS
      sosContact.phoneNumber!,
      '852', // Hong Kong country code
    );

    debugPrint('📊 SOS call result: ${success ? "SUCCESS ✅" : "FAILED ❌"}');
  }

  /// Handles ending an active call via accessibility service
  /// Triggered by GPIO 9 button (slot 252)
  Future<void> _handleEndCall() async {
    debugPrint('╔═══════════════════════════════════════════════════════════');
    debugPrint('║ 📴 END CALL INITIATED');
    debugPrint('╚═══════════════════════════════════════════════════════════');

    try {
      const platform = MethodChannel('com.tapcall.app/accessibility');
      final result = await platform.invokeMethod('endCall');
      debugPrint('📊 End call result: $result');
    } catch (e) {
      debugPrint('❌ Failed to end call: $e');
    }
  }

  /// Handles volume control from ESP32 potentiometer
  /// Receives VOL:N messages where N is 0-100 percentage
  /// Sets Android system volume accordingly
  void _handleVolumeChange(int volumePercent) {
    try {
      // Convert percentage (0-100) to volume level (0.0-1.0)
      final volumeLevel = volumePercent / 100.0;

      // Set system volume using volume_controller package
      VolumeController().setVolume(volumeLevel);

      debugPrint('🔊 Volume set to $volumePercent% (level: ${volumeLevel.toStringAsFixed(2)})');
    } catch (e) {
      debugPrint('❌ Failed to set volume: $e');
    }
  }

  /// Handles motion detection from PIR sensor
  /// Receives PIR:1 message when motion detected
  /// Wakes phone screen using Android PowerManager
  void _handleMotionDetected() {
    try {
      // Call native Android code to wake the screen
      const platform = MethodChannel('com.tapcall.app/screen');
      platform.invokeMethod('wakeScreen');

      debugPrint('👁️ Motion detected - Screen woken up');
    } catch (e) {
      debugPrint('❌ Failed to wake screen: $e');
    }
  }

  Future<void> _disconnectDevice() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      setState(() {
        _connectedDevice = null;
        _services = [];
      });
    }
  }

  Future<void> _manualScan() async {
    setState(() {
      _isScanning = true;
      _scannedDevices = [];
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          // Only show TapCall devices
          final tapCallDevices = results.where((r) {
            final name = r.device.platformName.toLowerCase();
            return name == 'tapcall' || name == 'onetapcall';
          }).toList();

          setState(() {
            _scannedDevices = tapCallDevices;
          });
        }
      });

      await Future.delayed(const Duration(seconds: 10));
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('Manual scan error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _manualConnect(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    setState(() {
      _isScanning = false;
    });
    await _connectToDevice(device);
  }

  void _showDeviceListDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_bluetoothDeviceTitle),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: Column(
              children: [
                // Show currently connected device at the top
                if (_connectedDevice != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              _bluetoothDeviceConnected,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_bluetoothDeviceName: ${_connectedDevice!.platformName}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'MAC: ${_connectedDevice!.remoteId}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Scan button
                if (!_isScanning)
                  ElevatedButton.icon(
                    onPressed: () {
                      _manualScan().then((_) => setDialogState(() {}));
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(_bluetoothDeviceScan),
                  )
                else
                  Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(_bluetoothDeviceScanning, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                const SizedBox(height: 16),

                // Device list
                Expanded(
                  child: _scannedDevices.isEmpty
                      ? Center(
                    child: Text(
                      _bluetoothDeviceEmpty,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                  )
                      : ListView.builder(
                    itemCount: _scannedDevices.length,
                    itemBuilder: (context, index) {
                      final result = _scannedDevices[index];
                      final device = result.device;
                      final name = device.platformName.isEmpty
                          ? _bluetoothDeviceUnknown
                          : device.platformName;
                      final rssi = result.rssi;
                      final isConnected = _connectedDevice?.remoteId == device.remoteId;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Icon(
                            Icons.bluetooth,
                            color: rssi > -70 ? Colors.green :
                            rssi > -80 ? Colors.orange : Colors.red,
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
                              color: isConnected ? Colors.green : Colors.black,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('MAC: ${device.remoteId}', style: const TextStyle(fontSize: 10)),
                              Text(
                                '$_bluetoothDeviceSignal: $rssi dBm ${rssi > -70 ? "📶" : rssi > -80 ? "📳" : "📡"}',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: isConnected
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.pop(context);
                            _manualConnect(device);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_bluetoothDeviceClose),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        // Move app to background instead of closing
        debugPrint('Back button pressed - moving to background');
        _loadTranslations();
        // App will stay in background with BLE connection active
      },
      child: MainCallScreen(
        isConnected: _connectedDevice != null,
        onBluetoothTap: _showDeviceListDialog,
        onButtonPress: (slotNumber) async {
          debugPrint('BLE triggered slot: $slotNumber');
          await _handleButtonPress(slotNumber);
        },
        onRegisterCallback: (callback) {
          _callbackId++; // Increment to invalidate old callbacks
          final myId = _callbackId;
          debugPrint('📝 Registering callback with ID: $myId');
          _onButtonPressCallback = (buttonNum) {
            if (myId == _callbackId) {
              debugPrint('✅ Callback ID $myId is current, processing');
              callback(buttonNum);
            } else {
              debugPrint('🚫 Callback ID $myId is stale (current: $_callbackId), ignoring');
            }
          };
        },
      ),
    );
  }
}
