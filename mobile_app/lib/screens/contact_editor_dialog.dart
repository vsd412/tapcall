/// ContactEditorDialog (TapCall)
///
/// Purpose:
/// - Full‑screen dialog to configure one slot (contact or extra function)
/// - Validates required fields for contacts; optional photo for all types
/// - Saves via callback; Settings screen persists changes
///
/// Special behavior:
/// - Extra function slots cannot select `Contact` type
/// - Automatically updates label to function display name when switching types
library;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../src/contact_manager.dart';
import '../src/function_type.dart';

/// Dialog for editing contact and function configurations
class ContactEditorDialog extends StatefulWidget {
  final Contact? contact;
  final int slot;
  final Color slotColor;
  final Function(Contact contact) onSave;
  final VoidCallback onDelete;
  final bool isExtraFunctionSlot; // Indicates if this slot is in Extra Functions section

  const ContactEditorDialog({
    super.key,
    required this.contact,
    required this.slot,
    required this.slotColor,
    required this.onSave,
    required this.onDelete,
    this.isExtraFunctionSlot = false, // Default to contact section
  });

  @override
  State<ContactEditorDialog> createState() => _ContactEditorDialogState();
}

class _ContactEditorDialogState extends State<ContactEditorDialog> {
  late FunctionType _selectedFunction;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _reminderMessageController;
  late AppType _selectedAppType;
  String? _photoPath;
  // TODO: Implement reminder time picker UI
  // ignore: unused_field
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  // TODO: Implement weekly reminder day selection UI
  // ignore: unused_field
  Set<int> _selectedDays = {}; // 1=Mon, 7=Sun
  final ImagePicker _imagePicker = ImagePicker();
  
  // Determine if this is a contact-only slot
  bool get _isContactOnlySlot {
    // If explicitly marked as extra function slot, allow all types except Contact
    // Otherwise, it's a contact-only slot
    return !widget.isExtraFunctionSlot;
  }

  @override
  void initState() {
    super.initState();
    _selectedFunction = widget.contact?.functionType ?? FunctionType.contact;
    _selectedAppType = widget.contact?.appType ?? AppType.whatsapp;
    _nameController = TextEditingController(text: widget.contact?.name ?? '');
    _phoneController = TextEditingController(text: widget.contact?.phoneNumber ?? '');
    _reminderMessageController = TextEditingController(text: widget.contact?.reminderMessage ?? '');
    _photoPath = widget.contact?.photoPath;
    
    // Parse reminder time
    if (widget.contact?.reminderTime != null) {
      final parts = widget.contact!.reminderTime!.split(':');
      if (parts.length == 2) {
        _reminderTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
    
    // Parse reminder days
    if (widget.contact?.reminderDays != null) {
      _selectedDays = widget.contact!.reminderDays!.toSet();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _reminderMessageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() {
        _photoPath = image.path;
      });
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Name required',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Validate based on function type
    if (_selectedFunction == FunctionType.contact) {
      final phone = _phoneController.text.trim();
      if (phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Phone number required for contact',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }
    
    // Build Contact object based on function type
    Contact contact;
    switch (_selectedFunction) {
      case FunctionType.contact:
        contact = Contact(
          functionType: FunctionType.contact,
          name: name,
          phoneNumber: _phoneController.text.trim(),
          appType: _selectedAppType,
          photoPath: _photoPath,
        );
        break;
      case FunctionType.time:
        contact = Contact(
          functionType: FunctionType.time,
          name: name,
          photoPath: _photoPath,
        );
        break;
      case FunctionType.weather:
        contact = Contact(
          functionType: FunctionType.weather,
          name: name,
          photoPath: _photoPath,
        );
        break;
    }
    
    widget.onSave(contact);
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved: $name (${_selectedFunction.displayName})',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _delete() {
    widget.onDelete();
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Function deleted',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2C3E50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: widget.slotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Button ${widget.slot}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Function Type Selector (only for extra function slots)
              if (!_isContactOnlySlot) ...[
                const Text(
                  'FUNCTION TYPE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: FunctionType.values
                      .where((type) => type != FunctionType.contact) // Exclude Contact type for extra function slots
                      .map((type) {
                    final isSelected = _selectedFunction == type;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFunction = type;
                          // Update name field to the new function type's display name if current name is empty or matches old type
                          final currentName = _nameController.text.trim();
                          if (currentName.isEmpty || FunctionType.values.any((t) => t.displayName == currentName)) {
                            _nameController.text = type.displayName;
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? widget.slotColor : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.white30,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              type.icon,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              type.displayName,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 24),
              ],
              
              // Photo display and picker (for all types)
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.slotColor, width: 4),
                    ),
                    child: _photoPath != null && _photoPath!.isNotEmpty
                        ? ClipOval(
                            child: Image.file(
                              File(_photoPath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    _selectedFunction.icon,
                                    style: const TextStyle(
                                      fontSize: 48,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Text(
                              _selectedFunction.icon,
                              style: const TextStyle(
                                fontSize: 48,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              const Center(
                child: Text(
                  'Tap to change photo',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Name input (for all types)
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: InputDecoration(
                  labelText: 'Label',
                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 18),
                  hintText: 'Enter button label',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white54, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white54, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: widget.slotColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                onChanged: (_) => setState(() {}),
              ),
              
              const SizedBox(height: 16),
              
              // Function-specific fields
              ..._buildFunctionSpecificFields(),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  // Delete button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete, size: 24),
                      label: const Text(
                        'Delete',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Save button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save, size: 24),
                      label: const Text(
                        'Save',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFunctionSpecificFields() {
    switch (_selectedFunction) {
      case FunctionType.contact:
        return [
          const Text(
            'MESSAGING APP',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [AppType.whatsapp, AppType.wechat]
                .map((appType) {
              final isSelected = _selectedAppType == appType;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedAppType = appType;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? widget.slotColor : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white30,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    appType.displayName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white, fontSize: 20),
            decoration: InputDecoration(
              labelText: 'Phone Number (Hong Kong)',
              labelStyle: const TextStyle(color: Colors.white70, fontSize: 18),
              hintText: '53328609',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white54, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white54, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: widget.slotColor, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ];
        
      case FunctionType.time:
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: const Text(
              '📢 This button will speak the current date and time when pressed.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ];
        
      case FunctionType.weather:
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange, width: 2),
            ),
            child: const Text(
              '📢 This button will speak the current weather forecast. Location permission required.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ];
    }
  }
}
