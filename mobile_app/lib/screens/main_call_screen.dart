/// MainCallScreen (TapCall)
///
/// Purpose:
/// - Primary UI for elderly‑friendly one‑tap calling
/// - Shows 3 large function buttons per page (contacts/time/weather)
/// - Handles physical button presses forwarded from BLE wrapper
///
/// Key concepts:
/// - Physical buttons 1–3 map to the current page’s 3 slots
/// - Special signals: `-1` = previous page, `-2` = next page
/// - Debounce & cooldown prevent repeated triggers
/// - Uses `TTS` for voice feedback and `AccessibilityService` for state
///
/// Structure:
/// - Periodic checks: accessibility and location permissions
/// - `_loadContacts()` builds slot lists and paging
/// - `_makeCall()` dispatches by `FunctionType`
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import '../src/contact_manager.dart';
import '../src/app_launcher.dart';
import '../src/open_accessibility_service.dart';
import '../src/function_type.dart';
import '../src/tts.dart';
import '../src/location.dart';
import '../src/weather.dart';
import '../src/translations.dart';
import 'settings_screen.dart';

class MainCallScreen extends StatefulWidget {
  final bool isConnected;
  final VoidCallback? onBluetoothTap;
  final Function(int)? onButtonPress;
  final Function(Function(int))? onRegisterCallback;

  const MainCallScreen({
    super.key,
    this.isConnected = false,
    this.onBluetoothTap,
    this.onButtonPress,
    this.onRegisterCallback,
  });

  @override
  State<MainCallScreen> createState() => _MainCallScreenState();
}

class _MainCallScreenState extends State<MainCallScreen> with WidgetsBindingObserver {
  final ContactManager _contactManager = ContactManager();
  final TTS _tts = TTS();
  final Location _location = Location();
  final Weather _weather = Weather();

  int _currentPage = 0;
  List<Contact?> _allContacts = []; // All existing contacts
  List<int> _allSlotNumbers = []; // Corresponding slot numbers
  List<Contact?> _currentContacts = [null, null, null];
  int _totalPages = 0;
  bool _settingsHoldStarted = false;
  int _settingsHoldProgress = 0;
  bool _isAccessibilityEnabled = false;
  bool _isLocationEnabled = false;
  Timer? _accessibilityCheckTimer;
  Timer? _locationCheckTimer;
  DateTime? _lastActionTime;
  int? _lastActionSlot;
  static const _actionCooldown = Duration(seconds: 3);
  bool _callbackRegistered = false; // Prevent double registration

  String _pageNumberPrefix = "";
  String _pageNumberSuffix = "";
  String _firstPageWarning = "";
  String _lastPageWarning = "";
  String _buttonFunctionMissing = "";
  String _buttonPhoneMissing = "";
  String _buttonCalling = "";
  String _buttonCallFailed = "";

  String _pageNumberPrefixTTS = "";
  String _pageNumberSuffixTTS = "";
  String _firstPageWarningTTS = "";
  String _lastPageWarningTTS = "";
  String _buttonFunctionMissingTTS = "";
  String _buttonPhoneMissingTTS = "";
  String _buttonCallingTTS = "";
  String _buttonCallFailedTTS = "";

  Future<void> _loadTranslations() async {
    final results = await Future.wait([
      Translations.get('pageNumberPrefix'),
      Translations.get('pageNumberSuffix'),
      Translations.get('firstPageWarning'),
      Translations.get('lastPageWarning'),
      Translations.get('buttonFunctionMissing'),
      Translations.get('buttonPhoneMissing'),
      Translations.get('buttonCalling'),
      Translations.get('buttonCallFailed'),

      Translations.getTTS2('pageNumberPrefix'),
      Translations.getTTS2('pageNumberSuffix'),
      Translations.getTTS2('firstPageWarning'),
      Translations.getTTS2('lastPageWarning'),
      Translations.getTTS2('buttonFunctionMissing'),
      Translations.getTTS2('buttonPhoneMissing'),
      Translations.getTTS2('buttonCalling'),
      Translations.getTTS2('buttonCallFailed'),
    ]);

    setState(() {
      _pageNumberPrefix = results[0];
      _pageNumberSuffix = results[1];
      _firstPageWarning = results[2];
      _lastPageWarning = results[3];
      _buttonFunctionMissing = results[4];
      _buttonPhoneMissing = results[5];
      _buttonCalling = results[6];
      _buttonCallFailed = results[7];

      _pageNumberPrefixTTS = results[8];
      _pageNumberSuffixTTS = results[9];
      _firstPageWarningTTS = results[10];
      _lastPageWarningTTS = results[11];
      _buttonFunctionMissingTTS = results[12];
      _buttonPhoneMissingTTS = results[13];
      _buttonCallingTTS = results[14];
      _buttonCallFailedTTS = results[15];
    });

  }

  @override
  void initState() {
    // Lifecycle setup: observe app state, initial loads, register BLE callback
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadContacts();
    _checkAccessibility();
    _checkLocation();
    _loadTranslations();

    // Register this screen's _handleBLEButtonPress with the wrapper (ONCE)
    if (!_callbackRegistered) {
      widget.onRegisterCallback?.call(_handleBLEButtonPress);
      _callbackRegistered = true;
      debugPrint('🔗 MainCallScreen callback registered (hashCode: ${hashCode})');
    }

    // Check statuses periodically (2 seconds for more responsive accessibility checks)
    _accessibilityCheckTimer = Timer.periodic(
      const Duration(seconds: 2),
          (_) => _checkAccessibility(),
    );
    _locationCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => _checkLocation(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accessibilityCheckTimer?.cancel();
    _locationCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload contacts when app comes back to foreground
      _loadContacts();
    }
  }

  Future<void> _checkAccessibility() async {
    final enabled = await AccessibilityService.isServiceEnabled();
    if (mounted) {
      setState(() {
        _isAccessibilityEnabled = enabled;
      });
    }
  }

  Future<void> _checkLocation() async {
    final enabled = await _location.checkPermission();
    if (mounted) {
      setState(() {
        _isLocationEnabled = enabled;
      });
    }
  }

  Future<void> _loadContacts() async {
    debugPrint('═══ Loading Contacts ═══');
    await _contactManager.loadContacts();

    // Collect all slots that have contacts stored
    List<Contact?> loadedContacts = [];
    List<int> loadedSlotNumbers = [];

    for (int slot = 1; slot <= 100; slot++) {
      final contact = _contactManager.getContact(slot);
      if (contact != null) {
        loadedContacts.add(contact);
        loadedSlotNumbers.add(slot);
        debugPrint('Found slot $slot: ${contact.name} (${contact.functionType.name})');
      }
    }

    debugPrint('Total slots loaded: ${loadedSlotNumbers.length}');
    debugPrint('Slot numbers: $loadedSlotNumbers');

    setState(() {
      _allContacts = loadedContacts;
      _allSlotNumbers = loadedSlotNumbers;
      _totalPages = _allContacts.isEmpty ? 1 : ((_allContacts.length - 1) ~/ 3) + 1;
      _updateCurrentContacts();
    });

    debugPrint('Total pages: $_totalPages');
    debugPrint('Current page: $_currentPage');
    debugPrint('Display order (slot numbers): $_allSlotNumbers');

    // Debug: Show what's in each display position
    for (int i = 0; i < _allSlotNumbers.length; i++) {
      final slot = _allSlotNumbers[i];
      final contact = _contactManager.getContact(slot);
      if (contact != null) {
        debugPrint('  Position ${i+1}: Slot $slot = ${contact.name} (${contact.functionType.name})');
      }
    }
  }

  Future<void> _handleBLEButtonPress(int slotNumber) async {
    // Entry point for physical button actions from BLE wrapper
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('');
    debugPrint('╔═══════════════════════════════════════════════════════════');
    debugPrint('║ 📱 MainCallScreen BLE Handler');
    debugPrint('║ Timestamp: $timestamp');
    debugPrint('║ Slot Number: $slotNumber');
    debugPrint('║ hashCode: ${hashCode}');
    debugPrint('╚═══════════════════════════════════════════════════════════');

    // Handle navigation signals from physical buttons
    // Note: Button 253 (GPIO 9) is now handled as SOS in main.dart, not passed here
    if (slotNumber == -1) {
      // Previous page button (GPIO 7)
      debugPrint('◀️ Physical PREVIOUS PAGE button');
      final oldPage = _currentPage;
      _previousPage();
      if (_currentPage < oldPage) {
        await _tts.speak('$_pageNumberPrefixTTS ${_currentPage + 1} $_pageNumberSuffixTTS');
        _showMessage('◀️ $_pageNumberPrefix ${_currentPage + 1}/$_totalPages $_pageNumberSuffix', Colors.blue.shade700);
        debugPrint('✅ Moved to page ${_currentPage + 1}');
      } else {
        await _tts.speak(_firstPageWarningTTS);
        _showMessage('⚠️ $_firstPageWarning', Colors.orange.shade700);
        debugPrint('⚠️ Already at first page');
      }
      return;
    }
    if (slotNumber == -2) {
      // Next page button (GPIO 8)
      debugPrint('▶️ Physical NEXT PAGE button');
      final oldPage = _currentPage;
      _nextPage();
      if (_currentPage > oldPage) {
        await _tts.speak('$_pageNumberPrefixTTS ${_currentPage + 1} $_pageNumberSuffixTTS');
        _showMessage('▶️ $_pageNumberPrefix ${_currentPage + 1}/$_totalPages $_pageNumberSuffix', Colors.blue.shade700);
        debugPrint('✅ Moved to page ${_currentPage + 1}');
      } else {
        await _tts.speak(_lastPageWarningTTS);
        _showMessage('⚠️ $_lastPageWarning', Colors.orange.shade700);
        debugPrint('⚠️ Already at last page (page ${_currentPage + 1} of $_totalPages)');
      }
      return;
    }

    // Function buttons (1-3)
    // Map physical button (1-3) to current page's displayed slot
    // Button 1 -> first slot on current page
    // Button 2 -> second slot on current page
    // Button 3 -> third slot on current page
    if (slotNumber >= 1 && slotNumber <= 3) {
      final pageStartIndex = _currentPage * 3;
      final actualIndex = pageStartIndex + (slotNumber - 1);

      if (actualIndex < _allSlotNumbers.length) {
        final actualSlot = _allSlotNumbers[actualIndex];
        debugPrint('Physical button $slotNumber → Page slot index $actualIndex → Actual slot $actualSlot');

        // CRITICAL: Check cooldown BEFORE loading contacts to prevent double-trigger
        final now = DateTime.now();
        if (_lastActionTime != null && _lastActionSlot == actualSlot) {
          final timeSinceLastAction = now.difference(_lastActionTime!);
          if (timeSinceLastAction < _actionCooldown) {
            debugPrint('⏸️  DEBOUNCE: Ignoring repeated button press (${timeSinceLastAction.inMilliseconds}ms < ${_actionCooldown.inMilliseconds}ms)');
            return;
          }
        }

        // Update cooldown tracking immediately
        _lastActionTime = now;
        _lastActionSlot = actualSlot;

        // Reload contacts to ensure we have latest data
        await _contactManager.loadContacts();

        // Find contact for this slot number
        final contact = _contactManager.getContact(actualSlot);
        debugPrint('Contact found: ${contact != null ? contact.name : "NULL"}');
        debugPrint('Contact type: ${contact?.functionType.name}');

        if (contact != null) {
          debugPrint('✅ FOUND Contact: ${contact.name} (${contact.functionType.name})');
          debugPrint('🔥 CALLING _makeCall - THIS SHOULD ONLY APPEAR ONCE');
          await _makeCall(contact);
        } else {
          debugPrint('No contact found for actual slot $actualSlot');
          await _tts.speak(_buttonFunctionMissingTTS);
          _showMessage(_buttonFunctionMissing, Colors.orange.shade700);
        }
      } else {
        debugPrint('Button $slotNumber pressed but no slot at page index $actualIndex');
        await _tts.speak(_buttonFunctionMissingTTS);
      }
      return;
    }

    // If we reach here, button number is invalid (should never happen)
    debugPrint('⚠️ WARNING: Unexpected button number $slotNumber');
  }

  void _updateCurrentContacts() {
    final startIndex = _currentPage * 3;
    // Force new list instance to trigger rebuild
    _currentContacts = List<Contact?>.from([
      startIndex < _allContacts.length ? _allContacts[startIndex] : null,
      startIndex + 1 < _allContacts.length ? _allContacts[startIndex + 1] : null,
      startIndex + 2 < _allContacts.length ? _allContacts[startIndex + 2] : null,
    ]);
    debugPrint('📄 Updated current contacts: Page ${_currentPage + 1}/$_totalPages');
    debugPrint('   Showing slots: ${_currentContacts.map((c) => c?.name ?? "Empty").join(", ")}');
  }

  void _nextPage() {
    debugPrint('_nextPage called: current=$_currentPage, total=$_totalPages');
    if (_currentPage < _totalPages - 1) {
      _currentPage++;
      _updateCurrentContacts();
      debugPrint('Page incremented to $_currentPage');
      if (mounted) {
        setState(() {});
        debugPrint('setState called for page change');
      }
    } else {
      debugPrint('Cannot go next: already at last page');
    }
  }

  void _previousPage() {
    debugPrint('_previousPage called: current=$_currentPage, total=$_totalPages');
    if (_currentPage > 0) {
      _currentPage--;
      _updateCurrentContacts();
      debugPrint('Page decremented to $_currentPage');
      if (mounted) {
        setState(() {});
        debugPrint('setState called for page change');
      }
    } else {
      debugPrint('Cannot go previous: already at first page');
    }
  }

  Future<void> _makeCall(Contact? contact) async {
    // Dispatch to the appropriate handler based on `FunctionType`
    if (contact == null) {
      await _tts.speak(_buttonFunctionMissingTTS);
      _showMessage(_buttonFunctionMissing, Colors.orange.shade700);
      return;
    }

    // Execute based on function type (debouncing handled at button press level)
    switch (contact.functionType) {
      case FunctionType.contact:
        await _executeContact(contact);
        break;
      case FunctionType.time:
        await _executeTimeAnnouncement();
        break;
      case FunctionType.weather:
        await _executeWeatherAnnouncement();
        break;
    }
  }

  Future<void> _executeContact(Contact contact) async {
    // Contact flow: speak “Calling <name>”, reset accessibility, launch app
    if (contact.phoneNumber == null || contact.phoneNumber!.isEmpty) {
      _showMessage(_buttonPhoneMissing, Colors.orange.shade700);
      await _tts.speak(_buttonPhoneMissingTTS);
      return;
    }

    try {
      _showMessage('$_buttonCalling ${contact.name}', const Color(0xFF3498DB));

      // Reset accessibility service immediately before launching
      debugPrint('🔄 Resetting accessibility state right before URL launch...');
      await AccessibilityService.resetCallState();

      // Start call immediately (non-blocking)
      final callFuture = AppLauncher.makeCall(
        contact.appType,
        contact.phoneNumber!,
        '852',
      );

      // Speak while WhatsApp is loading
      await _tts.speak('$_buttonCallingTTS ${contact.name}');

      // Set up error timeout - if call doesn't establish in 12 seconds, show error
      bool callSucceeded = false;
      Timer? errorTimer;

      errorTimer = Timer(const Duration(seconds: 12), () async {
        if (!callSucceeded) {
          debugPrint('❌ Call timeout - likely failed to connect');
          _showMessage('$_buttonCallFailed ${contact.name}', Colors.red.shade700);
          await _tts.speak('$_buttonCallFailedTTS ${contact.name}');

          // Return to app after error
          await Future.delayed(const Duration(seconds: 2));

          if (mounted) {
            // This doesn't actually bring app to foreground, but shows intent
            debugPrint('⬅️  Returning to app after error');
          }
        }
      });

      // Wait for call to complete
      await callFuture;
      callSucceeded = true;
      errorTimer.cancel();
    } catch (e) {
      _showMessage('$_buttonCallFailed ${contact.name}', Colors.red.shade700);
      await _tts.speak('$_buttonCallFailedTTS ${contact.name}');
      debugPrint('Failed to call ${contact.name}: $e');
    }
  }

  Future<void> _executeTimeAnnouncement() async {
    final now = DateTime.now();

    // Get language-specific announcement
    final announcement = await Translations.getTimeAnnouncement(now);

    _showMessage(announcement, const Color(0xFF3498DB));
    await _tts.speak(announcement);
  }

  Future<void> _executeWeatherAnnouncement() async {
    // Weather flow: ensure location permission, announce fetching, then weather
    // Check location permission first
    if (!_isLocationEnabled) {
      final msg = await Translations.getTTS('location_required');
      _showMessage(msg, Colors.orange.shade700);
      await _tts.speak(msg);
      return;
    }

    final gettingMsg = await Translations.getTTS('getting_weather');
    _showMessage(gettingMsg, const Color(0xFF3498DB));
    await _tts.speak(gettingMsg);

    final position = await _location.getCurrentLocation();
    if (position == null) {
      final msg = await Translations.getTTS('unable_location');
      _showMessage(msg, Colors.red.shade700);
      await _tts.speak(msg);
      return;
    }

    final weatherDesc = await _weather.getWeatherDescription(position);
    if (weatherDesc != null) {
      _showMessage(weatherDesc, const Color(0xFF27AE60));
      await _tts.speak(weatherDesc);
    } else {
      final msg = await Translations.getTTS('weather_unavailable');
      _showMessage(msg, Colors.red.shade700);
      await _tts.speak(msg);
    }
  }

  void _showMessage(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          backgroundColor: color,
          duration: const Duration(seconds: 5), // Last 5 seconds minimum
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(32),
        ),
      );
    }
  }

  Widget _buildElderlyContactButton(Contact? contact, Color backgroundColor) {
    final hasContact = contact != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: hasContact ? Colors.white : Colors.white30,
          width: 5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _makeCall(contact),
          borderRadius: BorderRadius.circular(35),
          splashColor: Colors.white.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                // Left side: Icon (photo or function icon) - ALWAYS CIRCULAR
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 140,
                    maxWidth: 140,
                    minHeight: 140,
                    maxHeight: 140,
                  ),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: contact?.photoPath != null && contact!.photoPath!.isNotEmpty
                        ? ClipOval(
                      child: Image.file(
                        File(contact.photoPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              contact.functionType.icon,
                              style: const TextStyle(
                                fontSize: 60,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                        : Center(
                      child: Text(
                        contact?.functionType.icon ?? '?',
                        style: const TextStyle(
                          fontSize: 60,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                // Right side: Label text
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final text = contact?.name ?? 'Not Set';
                        final isSingleWord = !text.contains(' ');

                        if (isSingleWord) {
                          // Single word: use FittedBox to shrink font if needed
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              text,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: hasContact ? Colors.white : Colors.white60,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        } else {
                          // Multiple words: allow wrapping
                          return Text(
                            text,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: hasContact ? Colors.white : Colors.white60,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          );
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startSettingsHold() {
    setState(() {
      _settingsHoldStarted = true;
      _settingsHoldProgress = 0;
    });

    _holdTimer();
  }

  void _holdTimer() async {
    for (int i = 0; i <= 30; i++) {
      if (!_settingsHoldStarted) break;

      await Future.delayed(const Duration(milliseconds: 100));

      if (_settingsHoldStarted && mounted) {
        setState(() {
          _settingsHoldProgress = i;
        });

        if (i >= 30) {
          _openSettings();
          break;
        }
      }
    }
  }

  void _cancelSettingsHold() {
    setState(() {
      _settingsHoldStarted = false;
      _settingsHoldProgress = 0;
    });
  }

  void _openSettings() async {
    setState(() {
      _settingsHoldStarted = false;
      _settingsHoldProgress = 0;
    });

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );

    // Force reload contacts after settings to sync with any changes
    debugPrint('Returned from settings, reloading contacts...');
    await _loadContacts();
    debugPrint('Contacts reloaded: ${_allContacts.length} slots found');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      body: SafeArea(
        child: Column(
          children: [
            // Top header: page indicator (left), status icons (middle), settings (right)
            Container(
              color: const Color.fromARGB(255, 35, 40, 50),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        shape: BoxShape.rectangle,
                        border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 2),
                      ),
                      child: const Text(
                        "SOS",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  /*
                  const Spacer(),
                  // Page indicator (smaller, top-left) Change to SOS
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      '${_currentPage + 1}/$_totalPages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  */
                  const Spacer(),

                  // Status icons in middle
                  Row(
                    children: [
                      // ESP32 connection status icon
                      GestureDetector(
                        onTap: widget.onBluetoothTap,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.isConnected ? Colors.blue: Colors.white30,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.bluetooth,
                            color: widget.isConnected ? Colors.blue : Colors.white30,
                            size: 26,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Accessibility status icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isAccessibilityEnabled ? Colors.blue : Colors.white30,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.accessibility_new,
                          color: _isAccessibilityEnabled ? Colors.blue : Colors.white30,
                          size: 26,
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Location status icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isLocationEnabled ? Colors.blue : Colors.white30,
                            width: 2,
                          ),

                        ),
                        child: Icon(
                          Icons.location_on,
                          color: _isLocationEnabled ? Colors.blue : Colors.white30,
                          size: 26,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Settings button (hold to unlock)
                  GestureDetector(
                    onLongPressStart: (_) => _startSettingsHold(),
                    onLongPressEnd: (_) => _cancelSettingsHold(),
                    onLongPressCancel: _cancelSettingsHold,
                    child: SizedBox(
                      width: 56,  // fixed width
                      height: 56, // fixed height
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_settingsHoldStarted)
                            CircularProgressIndicator(
                              value: _settingsHoldProgress / 30,
                              strokeWidth: 4,
                              backgroundColor: Colors.white30,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _settingsHoldStarted
                                  ? Colors.green.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.settings,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Three large contact buttons with dynamic colors based on page
            Expanded(
              child: _buildElderlyContactButton(
                _currentContacts[0],
                _currentPage == 2 ? const Color(0xFF9C27B0) : const Color(0xFF3498DB), // Purple for page 3, Blue for others
              ),
            ),

            Expanded(
              child: _buildElderlyContactButton(
                _currentContacts[1],
                _currentPage == 2 ? const Color(0xFF673AB7) : const Color(0xFFE67E22), // Deep purple for page 3, Orange for others
              ),
            ),

            Expanded(
              child: _buildElderlyContactButton(
                _currentContacts[2],
                _currentPage == 2 ? const Color(0xFF512DA8) : const Color(0xFF27AE60), // Dark purple for page 3, Green for others
              ),
            ),

            const SizedBox(height: 8),

            // Bottom navigation arrows (always visible)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // Left arrow (PREVIOUS)
                  Expanded(
                    child: GestureDetector(
                      onTap: _currentPage > 0 ? _previousPage : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _currentPage > 0
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _currentPage > 0 ? Colors.white : Colors.white30,
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          Icons.chevron_left,
                          color: _currentPage > 0 ? Colors.white : Colors.white30,
                          size: 50,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Right arrow (NEXT)
                  Expanded(
                    child: GestureDetector(
                      onTap: _currentPage < _totalPages - 1 ? _nextPage : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _currentPage < _totalPages - 1
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _currentPage < _totalPages - 1 ? Colors.white : Colors.white30,
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          color: _currentPage < _totalPages - 1 ? Colors.white : Colors.white30,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
