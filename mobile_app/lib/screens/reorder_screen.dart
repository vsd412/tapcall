/// ReorderScreen (TapCall)
///
/// Purpose:
/// - Drag‑and‑drop UI to reorder all configured slots
/// - Saves new sequential slot numbers (1..N) to `SharedPreferences`
///
/// UX notes:
/// - A dotted divider marks every group of 3 (one page on the main screen)
/// - Warns about unsaved changes when navigating back
library;

import 'package:flutter/material.dart';
import '../src/contact_manager.dart';
import '../src/function_type.dart';
import '../src/translations.dart';

class ReorderScreen extends StatefulWidget {
  const ReorderScreen({super.key});

  @override
  State<ReorderScreen> createState() => _ReorderScreenState();
}

class _ReorderScreenState extends State<ReorderScreen> {
  final ContactManager _contactManager = ContactManager();
  List<Contact> _items = [];
  List<int> _originalSlots = [];
  bool _isLoading = true;
  bool _hasChanges = false;
  String _reorderScreenTitle = "";
  String _reorderDiscardTitle = "";
  String _reorderDiscardDescription = "";
  String _reorderCancelLabel = "";
  String _reorderDiscardLabel = "";
  String _reorderSaveLabel = "";
  String _reorderEmptyTitle = "";
  String _reorderEmptyDescription = "";
  String _reorderScreenDescription = "";
  String _timeDateDescription = "";
  String _weatherDescription = "";
  String _emptySlotLabel = "";

  @override
  void initState() {
    super.initState();
    Future<void> loadTranslations() async {
      final results = await Future.wait([
        Translations.get('reorderScreenTitle'),
        Translations.get('reorderDiscardTitle'),
        Translations.get('reorderDiscardDescription'),
        Translations.get('reorderCancelLabel'),
        Translations.get('reorderDiscardLabel'),
        Translations.get('reorderSaveLabel'),
        Translations.get('reorderEmptyTitle'),
        Translations.get('reorderEmptyDescription'),
        Translations.get('reorderScreenDescription'),
        Translations.get('timeDateDescription'),
        Translations.get('weatherDescription'),
        Translations.get('emptySlotLabel'),
      ]);

      setState(() {
        _reorderScreenTitle      = results[0];
        _reorderDiscardTitle     = results[1];
        _reorderDiscardDescription = results[2];
        _reorderCancelLabel      = results[3];
        _reorderDiscardLabel     = results[4];
        _reorderSaveLabel        = results[5];
        _reorderEmptyTitle       = results[6];
        _reorderEmptyDescription = results[7];
        _reorderScreenDescription = results[8];
        _timeDateDescription = results[9];
        _weatherDescription = results[10];
        _emptySlotLabel = results[11];
      });
    }
    loadTranslations();
    _loadItems();
  }

  Future<void> _loadItems() async {
    await _contactManager.loadContacts();
    
    // Load all slots with their contacts
    List<Contact> loadedItems = [];
    List<int> slots = [];
    
    for (int slot = 1; slot <= 1000; slot++) {
      final contact = _contactManager.getContact(slot);
      if (contact != null) {
        loadedItems.add(contact);
        slots.add(slot);
      }
    }
    
    setState(() {
      _items = loadedItems;
      _originalSlots = List.from(slots);
      _isLoading = false;
    });
  }

  Future<void> _saveOrder() async {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    // Show saving indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Create new slot assignments (1, 2, 3, 4, ...)
    // We'll temporarily save to a different set of keys, then swap
    final tempStorage = <int, Contact>{};
    
    for (int i = 0; i < _items.length; i++) {
      final contact = _items[i];
      final newSlot = i + 1;
      tempStorage[newSlot] = contact;
    }

    // Remove all old slots
    for (final slot in _originalSlots) {
      await _contactManager.removeContact(slot);
    }

    // Save all items with new slot numbers
    for (final entry in tempStorage.entries) {
      final slot = entry.key;
      final contact = entry.value;
      
      await _contactManager.saveContact(
        slot,
        contact.functionType,
        contact.name,
        phoneNumber: contact.phoneNumber,
        photoPath: contact.photoPath,
        appType: contact.appType,
        reminderTime: contact.reminderTime,
        reminderDays: contact.reminderDays,
        reminderMessage: contact.reminderMessage,
        emergencyMessage: contact.emergencyMessage,
      );
    }

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog
    Navigator.pop(context, true); // Return to settings with refresh flag
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        
        final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2C3E50),
            title: Text(
              _reorderDiscardTitle,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            content: Text(
              _reorderDiscardDescription,
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(_reorderCancelLabel, style: const TextStyle(color: Colors.white70, fontSize: 18)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(_reorderDiscardLabel, style: const TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        
        if (shouldDiscard == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF34495E),
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255,35,40,50),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () async {
              if (_hasChanges) {
                final shouldDiscard = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF2C3E50),
                    title: Text(
                      _reorderDiscardTitle,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    content: Text(
                      _reorderDiscardDescription,
                      style: const TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(_reorderCancelLabel, style: const TextStyle(color: Colors.white70, fontSize: 18)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(_reorderDiscardLabel, style: const TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
                if (shouldDiscard == true) {
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            _reorderScreenTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _saveOrder,
                child: Text(
                  _reorderSaveLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inbox_outlined, size: 80, color: Colors.white38),
                        const SizedBox(height: 16),
                        Text(
                          _reorderEmptyTitle,
                          style: const TextStyle(color: Colors.white70, fontSize: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _reorderEmptyDescription,
                          style: const TextStyle(color: Colors.white38, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: const Color(0xFF2C3E50),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFF3498DB), size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _reorderScreenDescription,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Theme(
                              data: Theme.of(context).copyWith(
                                canvasColor: Colors.transparent,
                              ),
                              child: ReorderableListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: _items.length,
                                buildDefaultDragHandles: false,
                                proxyDecorator: (child, index, animation) {
                                  return AnimatedBuilder(
                                    animation: animation,
                                    builder: (context, child) {
                                      return Material(
                                        elevation: 8,
                                        color: Colors.transparent,
                                        shadowColor: Colors.black.withValues(alpha: 0.5),
                                        child: child,
                                      );
                                    },
                                    child: child,
                                  );
                                },
                                onReorder: (oldIndex, newIndex) {
                                  setState(() {
                                    _hasChanges = true;
                                    if (newIndex > oldIndex) {
                                      newIndex -= 1;
                                    }
                                    final item = _items.removeAt(oldIndex);
                                    _items.insert(newIndex, item);
                                  });
                                },
                                itemBuilder: (context, index) {
                                  final item = _items[index];
                                  final position = index + 1;
                                  
                                  // Check if this is the end of a group (every 3rd item)
                                  final isGroupEnd = (position % 3 == 0) && (index < _items.length - 1);
                                  
                                  return Column(
                                    key: ValueKey(item.hashCode + index),
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2C3E50),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.2),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ReorderableDragStartListener(
                                          index: index,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: _getPositionColor(index),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '$position',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  item.functionType.icon,
                                                  style: const TextStyle(fontSize: 32),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        item.name.isEmpty ? _emptySlotLabel : item.name,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 20,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        item.functionType == FunctionType.contact ? '${item.phoneNumber ?? ''} • ${item.appType.displayName}'
                                                            : item.functionType == FunctionType.time ? _timeDateDescription
                                                            : item.functionType == FunctionType.weather ? _weatherDescription
                                                            : '???',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.drag_handle,
                                              color: Colors.white54,
                                              size: 32,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Add dotted line after every 3rd item (but not after the last item)
                                  if (isGroupEnd)
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                      height: 1,
                                      child: CustomPaint(
                                        painter: DottedLinePainter(),
                                        size: const Size(double.infinity, 1),
                                      ),
                                    ),
                                ],
                              );
                                },
                              ),
                            ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Color _getPositionColor(int index) {
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
}

class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
