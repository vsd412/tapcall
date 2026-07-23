/// TapCall ContactBox
///
/// Purpose:
/// - Compact list tile used in Settings to show a slot
/// - Displays photo (if any) or function icon, plus label and type
/// - Supports tap to edit and optional delete action
library;

import 'package:flutter/material.dart';
import 'dart:io';
import '../src/contact_manager.dart';
import '../src/function_type.dart';

/// Compact function box widget for displaying a contact or function slot
class ContactBox extends StatelessWidget {
  final Contact? contact;
  final String? displayInfo;
  final String? emptyInfo;
  final Color slotColor;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ContactBox({
    super.key,
    required this.contact,
    required this.displayInfo,
    required this.emptyInfo,
    required this.slotColor,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasContact = contact != null && contact!.name.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: slotColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasContact ? Colors.white : Colors.white30,
            width: 3,
          ),
        ),
        child: Row(
          children: [
            // Photo/function icon circle
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: contact?.photoPath != null && contact!.photoPath!.isNotEmpty
                  ? ClipOval(
                child: Image.file(
                  File(contact!.photoPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Text(
                        displayInfo ?? "???",
                        style: const TextStyle(
                          fontSize: 28,
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
                    fontSize: 28,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Contact info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasContact ? contact!.name : (emptyInfo ?? "???"),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasContact)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Text(
                            contact!.functionType.icon,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            displayInfo ?? "???",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Edit icon
            const Icon(
              Icons.edit,
              color: Colors.white,
              size: 32,
            ),

            // Delete button (show only if onDelete is provided)
            if (onDelete != null) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
