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
library;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../src/contact_manager.dart';
import '../src/open_accessibility_service.dart';
import '../src/function_type.dart';
import '../src/language.dart';
import '../src/translations.dart';
import '../src/launcher.dart';
import 'contact_box.dart';
import 'contact_editor_dialog.dart';
import 'reorder_screen.dart';

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
  bool _isSystemNavMode = false;
  
  // SOS Contact (standalone)
  String _sosName = '';
  String _sosPhone = '';
  String _sosMessage = '';

  @override
  void initState() {
    super.initState();
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
    final isSystemNav = await Launcher.isSystemNavModeEnabled();
    
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
      _isSystemNavMode = isSystemNav;
      _contacts = loadedContacts;
      _slotNumbers = loadedSlotNumbers;
      _sosName = sosContact?.name ?? '';
      _sosPhone = sosContact?.phoneNumber ?? '';
      _sosMessage = sosContact?.emergencyMessage ?? '';
      _isLoading = false;
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
  }
  
  Future<void> _removeSlot(int index) async {
    // Confirm, delete storage keys for that slot, then reload
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C3E50),
        title: const Text(
          'Remove Slot?',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will permanently remove this slot and its configuration.',
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontSize: 20)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('Remove', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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

  Future<void> _toggleSystemNavMode() async {
    // Switch between “Back/Recent Apps” vs “Prev/Next page” for buttons 4&5
    final newValue = !_isSystemNavMode;
    await Launcher.setSystemNavMode(newValue);
    setState(() {
      _isSystemNavMode = newValue;
    });
    
    // Show message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue 
              ? 'System Nav Mode ON: Buttons 4&5 → Back/Recent Apps'
              : 'System Nav Mode OFF: Buttons 4&5 → Prev/Next Page',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _openContactEditor(int index) async {
    // Edit a specific slot’s configuration via `ContactEditorDialog`
    // Safety check for index
    if (index >= _contacts.length || index >= _slotNumbers.length) {
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
    // Standalone SOS contact editor (name + phone + emergency message)
    final nameController = TextEditingController(text: _sosName);
    final phoneController = TextEditingController(text: _sosPhone);
    final messageController = TextEditingController(text: _sosMessage);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C3E50),
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.red.shade300, size: 28),
            const SizedBox(width: 12),
            const Text(
              'SOS Contact',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This contact will be called when Button 9 is pressed.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: InputDecoration(
                  labelText: 'Name',
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
                  labelText: 'Phone Number',
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
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'Emergency Message (optional)',
                  hintText: 'e.g. 緊急求救！請幫忙！',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 16),
                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 18),
                  prefixIcon: const Icon(Icons.message, color: Colors.white70),
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
              const SizedBox(height: 8),
              const Text(
                'If set, a WhatsApp message will be sent before making the call.',
                style: TextStyle(color: Colors.white38, fontSize: 13),
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
                  _sosMessage = '';
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('Delete', style: TextStyle(color: Colors.red.shade300, fontSize: 18)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final message = messageController.text.trim();
              
              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter both name and phone number'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              await _contactManager.saveSOSContact(name, phone, message: message);
              setState(() {
                _sosName = name;
                _sosPhone = phone;
                _sosMessage = message;
              });
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('Save', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
        const SnackBar(
          content: Text(
            'Permissions requested',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
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
                'Language: $label',
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'UI Language: $label',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 1),
            ),
          );
          // Reload to refresh UI with new language
          _loadSettings();
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
          const SnackBar(
            content: Text(
              'Enable "One-Tap Call" in Accessibility',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 4),
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
  
  void _showScreenSizeDialog() {
    final widthController = TextEditingController(text: '1080');
    final heightController = TextEditingController(text: '1920');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C3E50),
        title: const Row(
          children: [
            Icon(Icons.phone_android, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Text(
              'Screen Size Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set your phone screen dimensions (in pixels)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Width (pixels)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widthController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: '1080',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white54),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Height (pixels)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: heightController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: '1920',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white54),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () async {
              final width = int.tryParse(widthController.text.trim());
              final height = int.tryParse(heightController.text.trim());
              
              if (width == null || height == null || width <= 0 || height <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid positive numbers'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              // Call native method to save screen size
              try {
                await Launcher.setScreenSize(width, height);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✅ Screen size saved: $width×$height',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
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
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        title: FutureBuilder<String>(
          future: Translations.get('settings'),
          builder: (context, snapshot) {
            return Text(
              snapshot.data ?? 'Settings',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            );
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSystemNavMode ? Icons.touch_app : Icons.touch_app_outlined,
              size: 32,
            ),
            tooltip: 'System Navigation Mode',
            onPressed: _toggleSystemNavMode,
          ),
          IconButton(
            icon: const Icon(Icons.phone_android, size: 32),
            tooltip: 'Screen Size Settings',
            onPressed: _showScreenSizeDialog,
          ),
          IconButton(
            icon: const Icon(Icons.reorder, size: 32),
            tooltip: 'Reorder Functions',
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
                    FutureBuilder<String>(
                      future: Translations.get('required_setup'),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? 'Required Setup',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FutureBuilder<String>(
                  future: Translations.get('required_setup_desc'),
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.data ?? '1. Enable Phone & Bluetooth permissions\n2. Enable Accessibility service for auto-calling',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        height: 1.5,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                
                // Permissions button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _checkAndRequestPermissions,
                    icon: const Icon(Icons.phone_android, size: 28),
                    label: FutureBuilder<String>(
                      future: Translations.get('enable_permissions'),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? 'Enable Permissions',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        );
                      },
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
                    label: FutureBuilder<String>(
                      future: Translations.get('enable_accessibility'),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? 'Enable Accessibility',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        );
                      },
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
                      child: FutureBuilder<String>(
                        future: Translations.get('ui_language'),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data ?? 'UI Language',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          );
                        },
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
                      child: FutureBuilder<String>(
                        future: Translations.get('voice_subtitle'),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data ?? 'Voice & Subtitle',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          );
                        },
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
                    FutureBuilder<String>(
                      future: Translations.get('sos_emergency'),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? 'SOS Emergency',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        );
                      },
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
                                _sosName.isNotEmpty ? _sosName : 'Tap to set SOS contact',
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
                              if (_sosMessage.isNotEmpty)
                                Text(
                                  '💬 $_sosMessage',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                    FutureBuilder<String>(
                      future: Translations.get('contacts'),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? 'Contacts',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        );
                      },
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
                        // Page separator for page 2+
                        if (pageIndex > 0)
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
                                      'Page ${pageIndex + 1}',
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
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ContactBox(
                              contact: contact,
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
                    label: const Text(
                      'Add More Contacts (1 more)',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
                    const Icon(Icons.star, color: Colors.amber, size: 32),
                    const SizedBox(width: 12),
                    FutureBuilder<String>(
                      future: Translations.get('extra_functions'),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? 'Extra Functions',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        );
                      },
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
                  
                  // Show all extra function slots
                  return List.generate(extraIndices.length, (localIndex) {
                    final actualIndex = extraIndices[localIndex];
                    final contact = _contacts[actualIndex];
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ContactBox(
                        contact: contact,
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
                    icon: const Icon(Icons.add_circle, size: 28, color: Colors.amber),
                    label: const Text(
                      'Add More Extra Functions (1 more)',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.amber, width: 3),
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
