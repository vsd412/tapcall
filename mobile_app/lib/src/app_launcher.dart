/*
===============================================================================
TapCall — Application Launcher Service
===============================================================================

Purpose:
- Bridges Flutter app with external calling/messaging apps (WhatsApp, Phone, WeChat)
- Normalizes phone numbers to international E.164 format (+CC + local digits)
- Launches appropriate app using URL schemes or deep links
- Provides unified interface regardless of target app

Supported Apps:
1. WhatsApp: Universal Link via https://wa.me/<digits>
2. Phone: Native dialer via tel:<E.164 format>
3. WeChat: Deep link via weixin:// (followed by coordinate-based automation)

Phone Number Normalization:
- Input: Country code (e.g., "852") + Local number (e.g., "53328609")
- Process:
  1) Strip all non-digits from both inputs
  2) Remove leading zeros from local number (local convention)
  3) Combine: +<countryCode><localNumber>
- Output: "+85253328609" (E.164 format)

URL Schemes:
- WhatsApp: https://wa.me/85253328609 (no +, no spaces)
- Phone: tel:+85253328609 (international format with +)
- WeChat: weixin:// (just opens app, automation handles the rest)

Error Handling:
- URL cannot be launched: Catches exception, logs details, returns false
- App not installed: canLaunchUrl() returns false, tries next method
- Invalid phone number: Still attempts launch (let native app handle validation)
- All failures logged for debugging

Dependencies:
- url_launcher: Cross-platform URL/deep link launching
- contact_manager: AppType enum for call target
- flutter/foundation: debugPrint for structured logging

Logging Strategy:
- Structured ASCII boxes for easy visual parsing
- Every step logged with emojis for quick scanning
- Timing information included
- Success/failure clearly marked
- Useful for customer support debugging

Usage Example:
  // Simple: Use static method
  final success = await AppLauncher.makeCall(
    AppType.whatsapp,
    '53328609',      // local number
    '852',           // country code (Hong Kong)
  );
  
  // Send WhatsApp text message (for SOS)
  await AppLauncher.sendWhatsAppMessage(
    '53328609',
    '852',
    'Emergency! Please help!',
  );
  
  // Advanced: Create instance for multiple calls
  final launcher = AppLauncher();
  await launcher.launchCall('53328609', AppType.phone, countryCode: '852');
*/

import 'package:url_launcher/url_launcher.dart';
import 'contact_manager.dart';
import 'package:flutter/foundation.dart';

/// Service for launching external apps and initiating calls/messages
/// 
/// Handles URL scheme generation, phone number normalization, and app launching.
/// Supports WhatsApp, Phone dialer, and WeChat with unified interface.
class AppLauncher {
  /// Initiates a call using the specified app
  /// 
  /// High-level convenience method that handles:
  /// 1. Phone number normalization
  /// 2. URL scheme generation
  /// 3. App availability check
  /// 4. Launch attempt and error handling
  /// 
  /// Parameters:
  ///   appType: WhatsApp, Phone, or WeChat
  ///   phoneNumber: Local phone number (e.g., "53328609")
  ///   countryCode: Country code (e.g., "852" for Hong Kong)
  /// 
  /// Returns:
  ///   true: App launched successfully
  ///   false: App not available, URL invalid, or launch failed
  /// 
  /// Usage:
  ///   final success = await AppLauncher.makeCall(
  ///     AppType.whatsapp,
  ///     '53328609',
  ///     '852',
  ///   );
  static Future<bool> makeCall(AppType appType, String phoneNumber, String? countryCode) async {
    final launcher = AppLauncher();
    return await launcher.launchCall(phoneNumber, appType, countryCode: countryCode);
  }

  /// Sends a WhatsApp message to a contact
  /// 
  /// Launches WhatsApp with pre-filled message text.
  /// Useful for SOS features or automated alerts.
  /// 
  /// Process:
  /// 1. Normalize phone number to international format
  /// 2. Remove + for WhatsApp URL format
  /// 3. URL-encode message text
  /// 4. Generate wa.me link with ?text parameter
  /// 5. Launch WhatsApp with message ready to send
  /// 
  /// Parameters:
  ///   phoneNumber: Local phone number
  ///   countryCode: Country code
  ///   message: Message text to send (will be pre-filled in WhatsApp)
  /// 
  /// Returns:
  ///   true: WhatsApp launched with message
  ///   false: WhatsApp not installed or launch failed
  /// 
  /// Message Encoding:
  /// - Supports all Unicode characters (Chinese, emoji, etc.)
  /// - Automatically URL-encoded via Uri.encodeComponent()
  /// - Line breaks (\n) preserved in WhatsApp
  /// 
  /// Example:
  ///   await AppLauncher.sendWhatsAppMessage(
  ///     '53328609',
  ///     '852',
  ///     '緊急求救！\n位置：[address]',  // Traditional Chinese with newline
  ///   );
  static Future<bool> sendWhatsAppMessage(String phoneNumber, String? countryCode, String message) async {
    try {
      final launcher = AppLauncher();
      final fullNumber = launcher._buildInternationalNumber(phoneNumber, countryCode);
      
      // Remove + prefix for WhatsApp URL format
      final digitsOnly = fullNumber.replaceAll('+', '');
      
      // URL-encode message to handle special characters, emojis, newlines
      final encodedMessage = Uri.encodeComponent(message);
      
      // Build wa.me link with pre-filled message
      final uri = Uri.parse('https://wa.me/$digitsOnly?text=$encodedMessage');
      
      debugPrint('🔗 WhatsApp message URL: $uri');
      
      // Log check but don't block the launch
      final canLaunch = await canLaunchUrl(uri);
      debugPrint('🔍 canLaunchUrl check: ${canLaunch ? "✅ YES" : "❌ NO (Attempting force launch anyway)"}');
      
      // Try to force launch regardless of the check
      bool success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      
      if (!success) {
        debugPrint('⚠️ Default launch failed, trying fallback mode...');
        success = await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ Error sending WhatsApp message: $e');
      return false;
    }
  }

  /// Normalizes phone number to international E.164 format
  /// 
  /// Input Format: Country code + Local number
  /// Example Input: CC="852", Phone="53328609"
  /// 
  /// Processing Steps:
  /// 1. Strip all non-digits from both inputs
  /// 2. Remove leading zeros from local number (country-specific convention)
  /// 3. Combine into international format
  /// 
  /// Output Format: E.164 standard (+CC + local digits, no + for WhatsApp URLs)
  String _buildInternationalNumber(String phoneNumber, String? countryCode) {
    try {
      // Step 1: Extract digits only from phone number
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      
      // Step 1: Extract digits only from country code
      String cleanCC = (countryCode ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      
      debugPrint('📝 Phone normalization:');
      debugPrint('  Cleaned phone: "$cleanPhone"');
      debugPrint('  Cleaned country code: "$cleanCC"');
      
      // Step 2: If no country code provided, return phone number only
      if (cleanCC.isEmpty) {
        debugPrint('  ℹ️ No country code, using phone only: "$cleanPhone"');
        return cleanPhone;
      }
      
      // Step 3: Remove leading zeros from phone number
      if (cleanPhone.startsWith('0')) {
        String original = cleanPhone;
        cleanPhone = cleanPhone.replaceFirst(RegExp(r'^0+'), '');
        debugPrint('  ✂️ Removed leading zeros: "$original" → "$cleanPhone"');
      }
      
      // Step 4: Combine country code + phone to form E.164 format
      String result = '+$cleanCC$cleanPhone';
      debugPrint('  ✅ Final international format: "$result"');
      return result;
      
    } catch (e) {
      debugPrint('❌ Error normalizing phone number: $e');
      return phoneNumber;
    }
  }

  /// Launches a call with the specified app
  /// 
  /// Main method that orchestrates:
  /// 1. Phone number normalization
  /// 2. URL scheme generation for target app
  /// 3. App availability check
  /// 4. URL launch attempt
  /// 5. Error logging and recovery
  Future<bool> launchCall(String phoneNumber, AppType appType, {String? countryCode}) async {
    try {
      // Log call initiation with structured format
      final timestamp = DateTime.now().toIso8601String();
      debugPrint('\n╔═══════════════════════════════════════════════════════════');
      debugPrint('║ 📞 APP LAUNCHER INITIATED');
      debugPrint('║ Timestamp: $timestamp');
      debugPrint('╠═══════════════════════════════════════════════════════════');
      debugPrint('║ Target App: ${appType.displayName}');
      debugPrint('║ Phone Number (raw): "$phoneNumber"');
      debugPrint('║ Country Code (raw): "${countryCode ?? '(none)'}"');
      debugPrint('╚═══════════════════════════════════════════════════════════');
      
      // Normalize phone number to international format
      final fullNumber = _buildInternationalNumber(phoneNumber, countryCode);
      debugPrint('📋 Normalized number: "$fullNumber"');

      // Generate URL schemes based on target app
      List<Uri> attempts = [];
      
      switch (appType) {
        case AppType.whatsapp:
          final digitsOnly = fullNumber.replaceAll('+', '');
          attempts.add(Uri.parse('https://wa.me/$digitsOnly'));
          debugPrint('🔗 WhatsApp URL: https://wa.me/$digitsOnly');
          break;
          
        case AppType.phone:
          attempts.add(Uri.parse('tel:$fullNumber'));
          debugPrint('📱 Phone URL: tel:$fullNumber');
          break;
          
        case AppType.wechat:
          attempts.add(Uri.parse('weixin://'));
          debugPrint('💚 WeChat URL: weixin:// (automation handles contact lookup)');
          break;
      }

      // Try each URL attempt in order
      for (final uri in attempts) {
        // Log check but do not block execution
        debugPrint('\n🔍 Checking if device can launch: $uri');
        final canLaunch = await canLaunchUrl(uri);
        debugPrint('   App availability check: ${canLaunch ? "✅ YES" : "❌ NO (Attempting force launch anyway)"}');
        
        try {
          debugPrint('🚀 Launching URL...');
          final startTime = DateTime.now();
          
          // Force launch in external application
          bool success = await launchUrl(uri, mode: LaunchMode.externalApplication);
          
          // Fallback if the strict externalApplication fails
          if (!success) {
            debugPrint('⚠️ Default launch failed, trying fallback mode...');
            success = await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
          }
          
          final elapsed = DateTime.now().difference(startTime);
          debugPrint('⏱️ Launch took: ${elapsed.inMilliseconds}ms');
          debugPrint('📊 Launch result: ${success ? "✅ SUCCESS" : "❌ FAILED"}');
          
          if (success) {
            debugPrint('\n✅ Call successfully initiated!');
            debugPrint('═══════════════════════════════════════════════════════════\n');
            return true;
          }
          
        } catch (e) {
          // URL launch threw exception
          debugPrint('❌ Exception during launch: $e');
          continue;  // Try next method
        }
      }
      
      // All attempts failed
      debugPrint('\n❌ All launch attempts failed');
      debugPrint('═══════════════════════════════════════════════════════════\n');
      return false;
      
    } catch (e) {
      // Outer exception handler
      debugPrint('\n❌ Unexpected error in launchCall: $e');
      debugPrint('═══════════════════════════════════════════════════════════\n');
      return false;
    }
  }
}
