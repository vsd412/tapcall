/// SettingsScreen (TapCall)
///
/// Purpose:
/// - Configure contacts/functions shown on Main screen
/// - Manage language preferences (UI vs TTS) and system navigation mode
/// - Set standalone SOS contact (Button 9)
///
/// Sections:
/// - Required setup: permissions & accessibility
/// - UI Language + Voice & Subtitle language
/// - SOS Emergency contact
/// - Contacts list (paged every 3 items) + Extra Functions
///
library;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../src/contact_manager.dart';
import '../src/open_accessibility_service.dart';
import '../src/function_type.dart';
import '../src/language.dart';
import '../src/translations.dart';
import 'contact_box.dart';
import 'contact_editor_dialog.dart';
import 'reorder_screen.dart';
import 'info_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ContactManager _contactManager = ContactManager();
  bool _isLoading = true;
  List<Contact?> _contacts = [];
  List<int> _slotNumbers = []; // Track slot numbers separately
  TTSLanguage _currentLanguage = TTSLanguage.english;
  UILanguage _currentUILanguage = UILanguage.english;
  String _sosName = '';
  String _sosPhone = '';
  String _contactDispName = "";
  String _timeDateDispName = "";
  String _weatherDispName = "";
  String _addSOSLabel = "";
  String _addContactLabel = "";
  String _addExtraLabel = "";
  String _reorderFunctionHover = "";
  String _uiLanguageTitle = "";
  String _voLanguageTitle = "";
  String _enablePermLabel = "";
  String _enableAccessLabel = "";
  String _enableSetupDescription = "";
  String _enableSetupTitle = "";
  String _settingScreenTitle = "";
  String _sosContactTitle = "";
  String _contactTitle = "";
  String _extraFunctionTitle = "";
  String _contactPagePrefix = "";
  String _sosSetupTitle = "";
  String _sosSetupDescription = "";
  String _sosNameGuide = "";
  String _sosPhoneGuide = "";
  String _sosDeleteLabel = "";
  String _sosCancelLabel = "";
  String _sosSaveLabel = "";
  String _emptySlotLabel = "";
  String _removeFunctionTitle = "";
  String _removeFunctionDescription = "";
  String _removeCancelLabel = "";
  String _removeConfirmLabel = "";
  String _sosMissingReport = "";
  String _requestPermReport = "";

  Future<void> _loadTranslations() async {
    final results = await Future.wait([
      Translations.get('contactDispName'),
      Translations.get('timeDateDispName'),
      Translations.get('weatherDispName'),
      Translations.get('addSOSLabel'),
      Translations.get('addContactLabel'),
      Translations.get('addExtraLabel'),
      Translations.get('reorderFunctionHover'),
      Translations.get('uiLanguageTitle'),
      Translations.get('voLanguageTitle'),
      Translations.get('enablePermLabel'),
      Translations.get('enableAccessLabel'),
      Translations.get('enableSetupDescription'),
      Translations.get('enableSetupTitle'),
      Translations.get('settingScreenTitle'),
      Translations.get('sosContactTitle'),
      Translations.get('contactTitle'),
      Translations.get('extraFunctionTitle'),
      Translations.get('contactPagePrefix'),
      Translations.get('sosSetupTitle'),
      Translations.get('sosSetupDescription'),
      Translations.get('sosNameGuide'),
      Translations.get('sosPhoneGuide'),
      Translations.get('sosDeleteLabel'),
      Translations.get('sosCancelLabel'),
      Translations.get('sosSaveLabel'),
      Translations.get('emptySlotLabel'),
      Translations.get('removeFunctionTitle'),
      Translations.get('removeFunctionDescription'),
      Translations.get('removeCancelLabel'),
      Translations.get('removeConfirmLabel'),
      Translations.get('sosMissingReport'),
      Translations.get('requestPermReport'),
    ]);

    setState(() {
      _contactDispName = results[0];
      _timeDateDispName = results[1];
      _weatherDispName = results[2];
      _addSOSLabel = results[3];
      _addContactLabel = results[4];
      _addExtraLabel = results[5];
      _reorderFunctionHover = results[6];
      _uiLanguageTitle = results[7];
      _voLanguageTitle = results[8];
      _enablePermLabel = results[9];
      _enableAccessLabel = results[10];
      _enableSetupDescription = results[11];
      _enableSetupTitle = results[12];
      _settingScreenTitle = results[13];
      _sosContactTitle = results[14];
      _contactTitle = results[15];
      _extraFunctionTitle = results[16];
      _contactPagePrefix = results[17];
      _sosSetupTitle = results[18];
      _sosSetupDescription = results[19];
      _sosNameGuide = results[20];
      _sosPhoneGuide = results[21];
      _sosDeleteLabel = results[22];
      _sosCancelLabel = results[23];
      _sosSaveLabel = results[24];
      _emptySlotLabel = results[25];
      _removeFunctionTitle = results[26];
      _removeFunctionDescription = results[27];
      _removeCancelLabel= results[28];
      _removeConfirmLabel = results[29];
      _sosMissingReport = results[30];
      _requestPermReport = results[31];
    });

  }

  @override
  void initState() {
    super.initState();
    _loadTranslations();
    _loadSettings();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadSettings() async {
    // Load slots, language preferences, system nav mode, and SOS contact
    await _contactManager.loadContacts();
    
    // Load language preferences
    final language = await Language.getLanguage();
    final uiLanguage = await Language.getUILanguage();
    
    // Load system navigation mode
    //final isSystemNav = await Launcher.isSystemNavModeEnabled();
    
    // Load SOS contact
    final sosContact = await _contactManager.getSOSContact();
    
    // Collect all slots that have contacts stored
    List<Contact?> loadedContacts = [];
    List<int> loadedSlotNumbers = [];
    
    for (int slot = 1; slot <= 100; slot++) {
      final contact = _contactManager.getContact(slot);
      if (contact != null) {
        loadedContacts.add(contact);
        loadedSlotNumbers.add(slot);
      }
    }
    
    setState(() {
      _currentLanguage = language;
      _currentUILanguage = uiLanguage;
      //_isSystemNavMode = isSystemNav;
      _contacts = loadedContacts;
      _slotNumbers = loadedSlotNumbers;
      _sosName = sosContact?.name ?? '';
      _sosPhone = sosContact?.phoneNumber ?? '';
      _isLoading = false;
      _loadTranslations();
    });
  }

  Color _getSlotColor(int index) {
    final colorIndex = index % 3;
    switch (colorIndex) {
      case 0:
        return const Color(0xFF3498DB); // Blue
      case 1:
        return const Color(0xFFE67E22); // Orange
      case 2:
        return const Color(0xFF27AE60); // Green
      default:
        return Colors.grey;
    }
  }
  
  void _addMoreContactSlots() async {
    // Create the next free slot as an empty contact entry
    // Find next available slot number
    int newSlot = 1;

    while (_slotNumbers.contains(newSlot)) {
      newSlot++;
    }

    // Save empty contact to create the slot
    await _contactManager.saveContact(
      newSlot,
      FunctionType.contact,
      '',
      phoneNumber: '',
    );
    
    // Reload to show the new slot
    await _loadSettings();

    _openContactEditor(newSlot-1);
  }
  
  void _addMoreExtraSlots() async {
    // Create a new extra function slot (default: Time) with a label
    // Find next available slot number
    int newSlot = 1;
    while (_slotNumbers.contains(newSlot)) {
      newSlot++;
    }
    
    // Default to time function with its display name as default name
    const defaultType = FunctionType.time;
    
    // Save extra function slot with default name from function type
    await _contactManager.saveContact(
      newSlot,
      defaultType,
      defaultType.displayName, // Use display name as default
    );
    
    // Reload to show the new slot
    await _loadSettings();

    _openContactEditor(newSlot-1);
  }
  
  Future<void> _removeSlot(int index) async {
    // Confirm, delete storage keys for that slot, then reload
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C3E50),
        title:Text(
          _removeFunctionTitle,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: Text(
          _removeFunctionDescription,
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_removeCancelLabel, style: const TextStyle(fontSize: 20, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: Text(_removeConfirmLabel, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final slot = _slotNumbers[index];
      // Delete the contact from storage
      await _contactManager.removeContact(slot);
      
      // Reload to refresh the list
      await _loadSettings();
    }
  }
  Future<void> _openContactEditor(int index) async {
    // Edit a specific slot’s configuration via `ContactEditorDialog`
    // Safety check for index
    if (index > _contacts.length || index > _slotNumbers.length) {
      return;
    }
    
    final contact = _contacts[index];
    final slot = _slotNumbers[index];
    
    // Determine if this is an extra function slot (non-Contact type)
    final isExtraFunction = contact != null && contact.functionType != FunctionType.contact;
    
    await showDialog(
      context: context,
      builder: (context) => ContactEditorDialog(
        contact: contact,
        slot: slot,
        slotColor: _getSlotColor(index),
        isExtraFunctionSlot: isExtraFunction,
        onSave: (Contact contact) async {
          await _contactManager.saveContact(
            slot,
            contact.functionType,
            contact.name,
            phoneNumber: contact.phoneNumber,
            appType: contact.appType,
            photoPath: contact.photoPath,
            reminderTime: contact.reminderTime,
            reminderDays: contact.reminderDays,
            reminderMessage: contact.reminderMessage,
            emergencyMessage: contact.emergencyMessage,
          );
          _loadSettings();
        },
        onDelete: () async {
          await _contactManager.removeContact(slot);
          _loadSettings();
        },
      ),
    );
  }

  Future<void> _editSOSContact() async {
    // Standalone SOS contact editor (name + phone)
    final nameController = TextEditingController(text: _sosName);
    final phoneController = TextEditingController(text: _sosPhone);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C3E50),
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.red.shade300, size: 28),
            const SizedBox(width: 12),
            Text(
              _sosSetupTitle,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _sosSetupDescription,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: InputDecoration(
                  labelText: _sosNameGuide,
                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 18),
                  prefixIcon: const Icon(Icons.person, color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white30, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red.shade300, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: InputDecoration(
                  labelText: _sosPhoneGuide,
                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 18),
                  prefixIcon: const Icon(Icons.phone, color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white30, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red.shade300, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Delete button (only show if SOS contact exists)
          if (_sosName.isNotEmpty)
            TextButton(
              onPressed: () async {
                await _contactManager.removeSOSContact();
                setState(() {
                  _sosName = '';
                  _sosPhone = '';
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(_sosDeleteLabel, style: TextStyle(color: Colors.red.shade300, fontSize: 18)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_sosCancelLabel, style: const TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              
              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_sosMissingReport,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              await _contactManager.saveSOSContact(name, phone);
              setState(() {
                _sosName = name;
                _sosPhone = phone;
              });
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: Text(_sosSaveLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAndRequestPermissions() async {
    final permissions = [
      Permission.phone,
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ];
    
    for (var permission in permissions) {
      final status = await permission.status;
      if (!status.isGranted) {
        await permission.request();
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _requestPermReport,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildLanguageOption(TTSLanguage language, String label) {
    final isSelected = _currentLanguage == language;
    
    return GestureDetector(
      onTap: () async {
        await Language.setLanguage(language);
        setState(() {
          _currentLanguage = language;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$_voLanguageTitle $label',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.green.shade700
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white30,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUILanguageOption(UILanguage language, String label) {
    final isSelected = _currentUILanguage == language;
    
    return GestureDetector(
      onTap: () async {
        await Language.setUILanguage(language);
        setState(() {
          _currentUILanguage = language;
        });
        if (mounted) {
          _loadSettings();
          _loadTranslations();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$_uiLanguageTitle: $label',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.shade700
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white30,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await AccessibilityService.openAccessibilitySettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _enableAccessLabel,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: const TextStyle(fontSize: 18),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF2C3E50),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 35, 40, 50),
        title: Text(
          _settingScreenTitle,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white,),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 32, color: Colors.white,),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info, size: 32, color: Colors.white,),
            tooltip: _reorderFunctionHover,
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => const InfoScreen(),
                ),
              );
              // If reorder was saved, reload settings
              if (result == true) {
                await _loadSettings();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.reorder, size: 32, color: Colors.white,),
            tooltip: _reorderFunctionHover,
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReorderScreen(),
                ),
              );
              // If reorder was saved, reload settings
              if (result == true) {
                await _loadSettings();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Permissions and Accessibility Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.security, color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      _enableSetupTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _enableSetupDescription,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Permissions button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _checkAndRequestPermissions,
                    icon: const Icon(Icons.phone_android, size: 28),
                    label: Text(
                      _enablePermLabel,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Accessibility button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openAccessibilitySettings,
                    icon: const Icon(Icons.accessibility_new, size: 28),
                    label: Text(
                      _enableAccessLabel,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // UI LANGUAGE SETTING
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.translate, color: Colors.white, size: 28),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _uiLanguageTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                
                // UI Language options
                Row(
                  children: [
                    Expanded(
                      child: _buildUILanguageOption(UILanguage.english, 'English'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildUILanguageOption(UILanguage.traditionalChinese, '繁體中文'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildUILanguageOption(UILanguage.simplifiedChinese, '简体中文'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // VOICE & SUBTITLE LANGUAGE SETTING
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.language, color: Colors.white, size: 28),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _voLanguageTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                
                // Language options
                Row(
                  children: [
                    Expanded(
                      child: _buildLanguageOption(TTSLanguage.english, 'English'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildLanguageOption(TTSLanguage.traditionalChinese, '繁體中文'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildLanguageOption(TTSLanguage.simplifiedChinese, '简体中文'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // SOS EMERGENCY CONTACT SECTION (Standalone - Button 253 / GPIO 9)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.shade400, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emergency, color: Colors.red.shade300, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      _sosContactTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // SOS Contact display/edit
                GestureDetector(
                  onTap: _editSOSContact,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _sosName.isNotEmpty 
                          ? Colors.red.shade700 
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _sosName.isNotEmpty ? Colors.red.shade300 : Colors.white30,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _sosName.isNotEmpty ? Icons.phone_in_talk : Icons.add,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _sosName.isNotEmpty ? _sosName : _addSOSLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_sosPhone.isNotEmpty)
                                Text(
                                  _sosPhone,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit, color: Colors.white70, size: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // CONTACTS SECTION
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.contacts, color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      _contactTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Contact slots - show only contacts (FunctionType.contact)
                ...(() {
                  // Filter to only contact-type entries
                  final contactIndices = <int>[];
                  for (int i = 0; i < _contacts.length; i++) {
                    final contact = _contacts[i];
                    if (contact == null || contact.functionType == FunctionType.contact) {
                      contactIndices.add(i);
                    }
                  }
                  
                  if (contactIndices.isEmpty) {
                    return <Widget>[];
                  }
                  
                  final contactPages = (contactIndices.length / 3).ceil();
                  
                  return List.generate(contactPages, (pageIndex) {
                    final startIdx = pageIndex * 3;
                    final endIdx = (startIdx + 3).clamp(0, contactIndices.length);
                    
                    if (endIdx <= startIdx) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      children: [
                        if (pageIndex >= 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              children: [
                                const Expanded(child: Divider(color: Colors.white30, thickness: 2)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white30, width: 2),
                                    ),
                                    child: Text(
                                      '$_contactPagePrefix ${pageIndex + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const Expanded(child: Divider(color: Colors.white30, thickness: 2)),
                              ],
                            ),
                          ),
                        
                        // Contact boxes for this page
                        ...List.generate((endIdx - startIdx).clamp(0, 3), (localIndex) {
                          final actualIndex = contactIndices[startIdx + localIndex];
                          final contact = _contacts[actualIndex];
                          String displayInfo = "";
                          if ((contact?.functionType ?? FunctionType.contact) == FunctionType.contact) {
                            displayInfo = _contactDispName;
                          } else if ((contact?.functionType ?? FunctionType.contact) == FunctionType.time){
                            displayInfo = _timeDateDispName;
                          } else if ((contact?.functionType ?? FunctionType.contact) == FunctionType.weather){
                            displayInfo = _weatherDispName;
                          } else {
                            displayInfo = "???";
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ContactBox(
                              contact: contact,
                              displayInfo: displayInfo,
                              emptyInfo: _emptySlotLabel,
                              slotColor: _getSlotColor(localIndex + startIdx),
                              onTap: () => _openContactEditor(actualIndex),
                              onDelete: () => _removeSlot(actualIndex),
                            ),
                          );
                        }),
                      ],
                    );
                  });
                })(),
                
                // Add More Contacts button
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addMoreContactSlots,
                    icon: const Icon(Icons.add_circle, size: 28, color: Colors.white),
                    label: Text(
                      _addContactLabel,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white, width: 3),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),

          // EXTRA FUNCTIONS SECTION (Slots 7-9)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.deepPurple.shade300, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      _extraFunctionTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Extra function slots - show only non-contact types
                ...(() {
                  // Filter to only extra function entries (non-contact types)
                  final extraIndices = <int>[];


                  for (int i = 0; i < _contacts.length; i++) {
                    final contact = _contacts[i];
                    if (contact != null && contact.functionType != FunctionType.contact) {
                      extraIndices.add(i);
                    }
                  }
                  
                  if (extraIndices.isEmpty) {
                    return <Widget>[];
                  }
                  String displayInfo = "";
                  // Show all extra function slots
                  return List.generate(extraIndices.length, (localIndex) {
                    final actualIndex = extraIndices[localIndex];
                    final contact = _contacts[actualIndex];
                    if ((contact?.functionType ?? FunctionType.contact) == FunctionType.contact) {
                      displayInfo = _contactDispName;
                    } else if ((contact?.functionType ?? FunctionType.contact) == FunctionType.time){
                      displayInfo = _timeDateDispName;
                    } else if ((contact?.functionType ?? FunctionType.contact) == FunctionType.weather){
                      displayInfo = _weatherDispName;
                    } else {
                      displayInfo = "???";
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ContactBox(
                        contact: contact,
                        displayInfo: displayInfo,
                        emptyInfo: _emptySlotLabel,
                        slotColor: _getSlotColor(localIndex),
                        onTap: () => _openContactEditor(actualIndex),
                        onDelete: () => _removeSlot(actualIndex),
                      ),
                    );
                  });
                })(),
                
                // Add More Extra Functions button
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addMoreExtraSlots,
                    icon: const Icon(Icons.add_circle, size: 28, color: Colors.white),
                    label: Text(
                      _addExtraLabel,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white, width: 3),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
