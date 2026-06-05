/*
TapCall — ContactsStorage

Purpose:
- Persist the user's slot-to-contact/function mapping using SharedPreferences.
- Each `Contact` is serialized to JSON and stored as a `StringList` under the key `contacts_slots_v1`.
- Slot numbers are 1-based. There is no hard slot limit; users can assign any positive slot number.

Behavior overview:
- load(): Reads, decodes, filters invalid entries, deduplicates by slot (keeping the last occurrence), and returns a list sorted by slot.
- saveAll(): Serializes and stores all contacts. Ordering of the stored list is not critical because slots are part of the JSON.
- add(): Inserts a contact at its requested slot if available, otherwise finds the first free slot starting at 1.
- setAtSlot(): Writes a contact to a specific slot and re-sorts. Validates slot is positive.
- deleteAt(): Removes an item by list index (not slot) to keep compatibility with older UI code that referenced list positions.
- deleteSlot(): Removes by slot, which is the preferred, explicit identifier.

Interoperability:
- Uses `Contact.toJson()` and `Contact.fromJson()` for data exchange.
- Tolerates malformed list entries by skipping decode failures.
*/

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact.dart';

class ContactsStorage {
  // Persistent storage key for the serialized contacts list.
  static const _key = 'contacts_slots_v1';
  // Design: Unlimited slots. Sorting and uniqueness are enforced when reading.

  // Load the full set of contacts from disk, returning a list ordered by slot.
  Future<List<Contact>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);
    if (raw == null) return [];

    // Decode each JSON string into a Contact. Skip malformed entries.
    final list = raw.map((e) {
      try {
        return Contact.fromJson(jsonDecode(e) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<Contact>().toList(growable: false);

    // Ensure uniqueness by slot; if duplicates exist, keep the last occurrence.
    final Map<int, Contact> bySlot = {};
    for (final c in list) {
      if (c.slot >= 1) {
        bySlot[c.slot] = c;
      }
    }

    // Sort ascending by slot and return a flat list.
    final sorted = bySlot.keys.toList()..sort();
    return [for (final s in sorted) bySlot[s]!];
  }

  // Save the full list back to disk. Order is not required thanks to slot in JSON.
  Future<bool> saveAll(List<Contact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final list = contacts.map((c) => jsonEncode(c.toJson())).toList();
    return prefs.setStringList(_key, list);
  }

  // Add or place a contact: use its requested slot, or find the first free slot.
  Future<List<Contact>> add(Contact contact) async {
    final current = await load();
    final occupied = current.map((c) => c.slot).toSet();
    int slot = contact.slot;

    // If requested slot is invalid or occupied, find the next available slot starting at 1.
    if (slot < 1 || occupied.contains(slot)) {
      slot = 1;
      while (occupied.contains(slot)) {
        slot++;
      }
    }

    // Replace any existing contact at the slot, then sort.
    final updated = [
      ...current.where((c) => c.slot != slot),
      contact.copyWith(slot: slot),
    ]..sort((a, b) => a.slot.compareTo(b.slot));
    await saveAll(updated);
    return updated;
  }

  // Explicitly set a contact at a given slot. Validates slot is positive.
  Future<List<Contact>> setAtSlot(int slot, Contact contact) async {
    if (slot < 1) {
      throw ArgumentError.value(slot, 'slot', 'Must be 1 or greater');
    }
    final current = await load();
    final updated = [
      ...current.where((c) => c.slot != slot),
      contact.copyWith(slot: slot),
    ]..sort((a, b) => a.slot.compareTo(b.slot));
    await saveAll(updated);
    return updated;
  }

  // Remove an item by its index in the sorted list (backward compatibility path).
  Future<List<Contact>> deleteAt(int index) async {
    final current = await load();
    if (index < 0 || index >= current.length) return current;
    final targetSlot = current[index].slot;
    final updated = current.where((c) => c.slot != targetSlot).toList();
    await saveAll(updated);
    return updated;
  }

  // Remove any contact assigned to the given slot.
  Future<List<Contact>> deleteSlot(int slot) async {
    final current = await load();
    final updated = current.where((c) => c.slot != slot).toList();
    await saveAll(updated);
    return updated;
  }
}
