/*
TapCall — AppState

Purpose:
- Minimal in-memory state container keyed by 1-based slot numbers.
- Provides list access for legacy views and helpers to read/set/clear contacts.
- Not persistent: this layer is UI-facing; persistence lives in `ContactsStorage`.

Notes:
- Uses `ChangeNotifier` so widgets can `listen` and rebuild on updates.
- Exposes both list and slot-based access patterns.
*/

import 'package:flutter/foundation.dart';
import '../models/contact.dart';

class AppState extends ChangeNotifier {
  // Map of slot -> Contact. Slots are 1-based and open-ended.
  final Map<int, Contact> _slots = {};

  // Legacy-friendly list of contacts ordered by slot ascending.
  List<Contact> get contacts {
    final sortedKeys = _slots.keys.toList()..sort();
    return sortedKeys.map((key) => _slots[key]!).toList(growable: false);
  }

  // Fetch a contact by its slot. Returns null if slot invalid or empty.
  Contact? contactAt(int slot) {
    if (slot < 1) return null;
    return _slots[slot];
  }

  // Populate an initial example record (useful in demos/dev flows).
  void loadInitial() {
    _slots[1] = const Contact(slot: 1, name: 'Sample', regionCode: '+1', number: '123456789', app: 'phone');
    notifyListeners();
  }

  // Set or update a contact at a given slot. Basic validation applied.
  bool setContactAtSlot({
    required int slot,
    required String name,
    required String number,
    required String app,
    String regionCode = '+1',
  }) {
    if (slot < 1) return false;
    if (name.isEmpty || number.isEmpty) return false;

    _slots[slot] = Contact(
      slot: slot,
      name: name.trim(),
      regionCode: regionCode.trim(),
      number: number.trim(),
      app: app.toLowerCase().trim(),
    );
    notifyListeners();
    return true;
  }

  // Clear a slot if it exists, then notify listeners.
  void clearSlot(int slot) {
    if (slot < 1) return;
    if (_slots.containsKey(slot)) {
      _slots.remove(slot);
      notifyListeners();
    }
  }

  // Remove a specific contact instance if it matches what's stored at its slot.
  void removeContact(Contact c) {
    final slot = c.slot;
    if (slot >= 1 && _slots[slot] == c) {
      _slots.remove(slot);
      notifyListeners();
    }
  }

  // Force a UI refresh without changing data.
  void refresh() => notifyListeners();
}
