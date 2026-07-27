/// TapCall Contact & Function Manager
///
/// Purpose:
/// - Stores per‑button “slots” (1–100) in `SharedPreferences`
/// - Each slot can be a contact or an extra function (time/weather)
/// - Provides CRUD helpers for slots and a standalone SOS contact
///
/// Data model:
/// - `Contact` holds union‑style optional fields depending on `FunctionType`
/// - Keys in preferences are namespaced as `slot_{N}_...` (e.g., phone, app)
/// - SOS contact uses `sos_name` / `sos_phone` outside regular slots
///
/// Usage:
/// - UI reads via `loadContacts()` + `getContact(slot)`
/// - Saving via `saveContact(...)` writes only relevant keys per function type
/// - Removing via `removeContact(slot)` clears all keys for that slotlibrary;
library;
import 'package:shared_preferences/shared_preferences.dart';
import 'function_type.dart';

enum AppType {
  whatsapp,
  wechat,
  phone,
}

extension AppTypeExtension on AppType {
  String get displayName {
    switch (this) {
      case AppType.whatsapp:
        return 'WhatsApp';
      case AppType.wechat:
        return 'WeChat';
      case AppType.phone:
        return 'Phone';
    }
  }
  
  String get value {
    return toString().split('.').last;
  }
  
  static AppType fromString(String value) {
    return AppType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AppType.whatsapp,
    );
  }
}

class Contact {
  final FunctionType functionType; // Type of function
  
  // Common fields
  final String name; // Display name
  final String? photoPath; // Path to photo
  
  // Contact-specific fields
  final String? phoneNumber; // For Contact type only
  final AppType appType; // For Contact type only
  
  // Reminder-specific fields
  final String? reminderTime; // Format: "HH:mm" (24-hour)
  final List<int>? reminderDays; // [1-7] for Mon-Sun
  final String? reminderMessage; // Message to display
  
  // Emergency SOS-specific fields
  final String? emergencyMessage; // Message to send

  Contact({
    this.functionType = FunctionType.contact,
    required this.name,
    this.photoPath,
    this.phoneNumber,
    this.appType = AppType.whatsapp,
    this.reminderTime,
    this.reminderDays,
    this.reminderMessage,
    this.emergencyMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'functionType': functionType.toString().split('.').last,
      'name': name,
      'photoPath': photoPath,
      'phoneNumber': phoneNumber,
      'appType': appType.value,
      'reminderTime': reminderTime,
      'reminderDays': reminderDays?.join(','),
      'reminderMessage': reminderMessage,
      'emergencyMessage': emergencyMessage,
    };
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    final functionTypeStr = json['functionType'] ?? 'contact';
    final functionType = FunctionType.values.firstWhere(
      (e) => e.toString().split('.').last == functionTypeStr,
      orElse: () => FunctionType.contact,
    );

    List<int>? reminderDays;
    if (json['reminderDays'] != null && json['reminderDays'].isNotEmpty) {
      reminderDays = (json['reminderDays'] as String)
          .split(',')
          .map((e) => int.tryParse(e) ?? 1)
          .toList();
    }

    return Contact(
      functionType: functionType,
      name: json['name'] ?? '',
      photoPath: json['photoPath'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      appType: AppTypeExtension.fromString(json['appType'] ?? 'whatsapp'),
      reminderTime: json['reminderTime'] as String?,
      reminderDays: reminderDays,
      reminderMessage: json['reminderMessage'] as String?,
      emergencyMessage: json['emergencyMessage'] as String?,
    );
  }
}

class ContactManager {
  final Map<int, Contact> _contacts = {};

  /// Load all saved slots from `SharedPreferences` into memory.
  /// Clears in‑memory cache first to reflect deletions properly.
  Future<void> loadContacts() async {
    // CRITICAL: Clear existing contacts before loading to ensure deleted contacts are removed
    _contacts.clear();
    
    final prefs = await SharedPreferences.getInstance();
    // Load up to 100 slots
    for (int slot = 1; slot <= 100; slot++) {
      final name = prefs.getString('slot_${slot}_name');
      
      if (name != null) {
        final functionTypeStr = prefs.getString('slot_${slot}_functionType') ?? 'contact';
        final functionType = FunctionType.values.firstWhere(
          (e) => e.toString().split('.').last == functionTypeStr,
          orElse: () => FunctionType.contact,
        );

        List<int>? reminderDays;
        final reminderDaysStr = prefs.getString('slot_${slot}_reminderDays');
        if (reminderDaysStr != null && reminderDaysStr.isNotEmpty) {
          reminderDays = reminderDaysStr
              .split(',')
              .map((e) => int.tryParse(e) ?? 1)
              .toList();
        }

        _contacts[slot] = Contact(
          functionType: functionType,
          name: name,
          photoPath: prefs.getString('slot_${slot}_photo'),
          phoneNumber: prefs.getString('slot_${slot}_phone'),
          appType: AppTypeExtension.fromString(prefs.getString('slot_${slot}_app') ?? 'whatsapp'),
          reminderTime: prefs.getString('slot_${slot}_reminderTime'),
          reminderDays: reminderDays,
          reminderMessage: prefs.getString('slot_${slot}_reminderMessage'),
          emergencyMessage: prefs.getString('slot_${slot}_emergencyMessage'),
        );
      }
    }
  }

  /// Create or update a slot with the provided data.
  /// Only persists keys relevant to the chosen `FunctionType`.
  Future<void> saveContact(
    int slot,
    FunctionType functionType,
    String name, {
    String? phoneNumber,
    AppType appType = AppType.whatsapp,
    String? photoPath,
    String? reminderTime,
    List<int>? reminderDays,
    String? reminderMessage,
    String? emergencyMessage,
  }) async {
    _contacts[slot] = Contact(
      functionType: functionType,
      name: name,
      photoPath: photoPath?.isNotEmpty == true ? photoPath : null,
      phoneNumber: phoneNumber,
      appType: appType,
      reminderTime: reminderTime,
      reminderDays: reminderDays,
      reminderMessage: reminderMessage,
      emergencyMessage: emergencyMessage,
    );
    
    final prefs = await SharedPreferences.getInstance();
    
    // Save common fields
    await prefs.setString('slot_${slot}_functionType', functionType.toString().split('.').last);
    await prefs.setString('slot_${slot}_name', name);
    
    if (photoPath != null && photoPath.isNotEmpty) {
      await prefs.setString('slot_${slot}_photo', photoPath);
    } else {
      await prefs.remove('slot_${slot}_photo');
    }
    
    // Save Contact-specific fields
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      await prefs.setString('slot_${slot}_phone', phoneNumber);
      await prefs.setString('slot_${slot}_app', appType.value);
    } else {
      await prefs.remove('slot_${slot}_phone');
      await prefs.remove('slot_${slot}_app');
    }
    
    // Save Reminder-specific fields
    if (reminderTime != null && reminderTime.isNotEmpty) {
      await prefs.setString('slot_${slot}_reminderTime', reminderTime);
    } else {
      await prefs.remove('slot_${slot}_reminderTime');
    }
    
    if (reminderDays != null && reminderDays.isNotEmpty) {
      await prefs.setString('slot_${slot}_reminderDays', reminderDays.join(','));
    } else {
      await prefs.remove('slot_${slot}_reminderDays');
    }
    
    if (reminderMessage != null && reminderMessage.isNotEmpty) {
      await prefs.setString('slot_${slot}_reminderMessage', reminderMessage);
    } else {
      await prefs.remove('slot_${slot}_reminderMessage');
    }
    
    // Save Emergency SOS-specific fields
    if (emergencyMessage != null && emergencyMessage.isNotEmpty) {
      await prefs.setString('slot_${slot}_emergencyMessage', emergencyMessage);
    } else {
      await prefs.remove('slot_${slot}_emergencyMessage');
    }
  }

  /// Remove a slot and all its persisted keys.
  Future<void> removeContact(int slot) async {
    _contacts.remove(slot);
    final prefs = await SharedPreferences.getInstance();
    
    // Remove all fields for this slot
    await prefs.remove('slot_${slot}_functionType');
    await prefs.remove('slot_${slot}_name');
    await prefs.remove('slot_${slot}_photo');
    await prefs.remove('slot_${slot}_phone');
    await prefs.remove('slot_${slot}_app');
    await prefs.remove('slot_${slot}_reminderTime');
    await prefs.remove('slot_${slot}_reminderDays');
    await prefs.remove('slot_${slot}_reminderMessage');
    await prefs.remove('slot_${slot}_emergencyMessage');
  }

  /// Get a single slot from the in‑memory cache.
  Contact? getContact(int slot) {
    return _contacts[slot];
  }

  /// Return all saved contacts/functions in display order (1..100).
  Future<List<Contact>> getContacts() async {
    await loadContacts(); // Ensure contacts are loaded
    final contacts = <Contact>[];
    for (int slot = 1; slot <= 100; slot++) {
      final contact = _contacts[slot];
      if (contact != null) {
        contacts.add(contact);
      }
    }
    return contacts;
  }

  /// Convenience: return the list of all slot numbers (1..100).
  Future<List<int>> getAllSlots() async {
    await loadContacts();
    return List.generate(100, (index) => index + 1);
  }

  // Get all contacts of type Contact (for Emergency SOS)
  Future<List<Contact>> getAllContactsForEmergency() async {
    await loadContacts();
    return _contacts.values
        .where((contact) => contact.functionType == FunctionType.contact)
        .toList();
  }
  
  // Get first contact (for Emergency SOS)
  Future<Contact?> getFirstContact() async {
    await loadContacts();
    // Find the first slot (1-6) that has a Contact type function
    for (int slot = 1; slot <= 6; slot++) {
      final contact = _contacts[slot];
      if (contact != null && contact.functionType == FunctionType.contact) {
        return contact;
      }
    }
    return null;
  }

  // ============ STANDALONE SOS CONTACT (Button 253/GPIO9) ============
  
  // Save SOS contact (standalone, separate from slots)
  Future<void> saveSOSContact(String name, String phoneNumber, {String message = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sos_name', name);
    await prefs.setString('sos_phone', phoneNumber);
    await prefs.setString('sos_message', message);
  }

  // Get SOS contact
  Future<Contact?> getSOSContact() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('sos_name');
    final phone = prefs.getString('sos_phone');
    final message = prefs.getString('sos_message') ?? '';
    
    if (name == null || name.isEmpty || phone == null || phone.isEmpty) {
      return null;
    }
    
    return Contact(
      functionType: FunctionType.contact,
      name: name,
      phoneNumber: phone,
      appType: AppType.whatsapp, // SOS uses WhatsApp (message + call)
      emergencyMessage: message,
    );
  }

  // Check if SOS contact is configured
  Future<bool> hasSOSContact() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('sos_name');
    final phone = prefs.getString('sos_phone');
    return name != null && name.isNotEmpty && phone != null && phone.isNotEmpty;
  }

  // Remove SOS contact
  Future<void> removeSOSContact() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sos_name');
    await prefs.remove('sos_phone');
    await prefs.remove('sos_message');
  }
}