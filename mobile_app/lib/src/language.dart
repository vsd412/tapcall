/*
===============================================================================
TapCall — Language & Localization Service
===============================================================================

Purpose:
- Manages two independent language preferences for elderly users:
  1) UI Language: Controls all interface text (buttons, labels, dialogs)
  2) TTS Language: Controls voice announcements and spoken language
- Enables flexible localization: e.g., Traditional Chinese UI + English voice
- Persists preferences in SharedPreferences across app restarts

Language Support:
- UI Languages: English, Traditional Chinese (繁體中文), Simplified Chinese (简体中文)
- TTS Languages: English (US), Traditional Chinese (Cantonese/HK), Simplified Chinese (Mandarin/CN)

Design Philosophy:
- Separation of concerns: UI text independent from voice language
- Elderly-friendly: Allows choosing UI language that's easiest to read, voice that's easiest to understand
- Persistent: User preferences survive app restart via SharedPreferences
- Consistent: All UI and TTS calls use same language service

Storage Architecture:
- SharedPreferences keys: 'ui_language' and 'tts_language'
- Enum values serialized as strings (never as enum ordinal) for robustness
- Default fallback: English if preference not found (first install)

Localization Strategy:
- All UI text: Call Translations.get(key) - uses UILanguage
- All TTS text: Call Translations.getTTS(key) - uses TTSLanguage
- Display names: getUIDisplayName() / getDisplayName() for settings UI
- Language codes: getLanguageCode() converts to BCP-47 format for native TTS

TTS Language Codes (BCP-47 Standard):
- English: 'en-US' (US English, male voice)
- Traditional Chinese: 'zh-HK' (Hong Kong Cantonese)
- Simplified Chinese: 'zh-CN' (Mainland Mandarin)

Error Handling:
- SharedPreferences failures: Caught and handled gracefully
- Invalid enum values: Default to English
- Missing preferences: Default to English (first install)
- No exceptions propagated: App continues with fallback language

Usage Example:
  // Check current UI language
  final uiLang = await Language.getUILanguage();
  
  // Get translated string (uses current UI language)
  final translated = await Translations.get('emergency_call');
  
  // Get voice announcement (uses current TTS language)
  final voiceText = await Translations.getTTS('call_initiated');
  await tts.speak(voiceText);
  
  // Change languages
  await Language.setUILanguage(UILanguage.traditionalChinese);
  await Language.setLanguage(TTSLanguage.simplifiedChinese);

Dependency:
- shared_preferences: Persistent preference storage
- translations.dart: All localized strings (must be kept in sync)
*/

import 'package:shared_preferences/shared_preferences.dart';

/// Enum for Text-to-Speech (voice) language selection
/// 
/// These represent actual voice languages:
/// - english: US English male voice (en-US)
/// - traditionalChinese: Cantonese voice from Hong Kong (zh-HK)
/// - simplifiedChinese: Mandarin voice from mainland China (zh-CN)
/// 
/// Used for: Voice announcements, TTS output, weather descriptions
enum TTSLanguage {
  english,              // US English voice
  traditionalChinese,   // Cantonese (Hong Kong)
  simplifiedChinese,    // Mandarin (Mainland China)
}

/// Enum for User Interface language selection
/// 
/// These represent written languages:
/// - english: English text for all UI elements
/// - traditionalChinese: Traditional Chinese characters (used in Hong Kong, Taiwan)
/// - simplifiedChinese: Simplified Chinese characters (used in mainland China)
/// 
/// Used for: UI buttons, labels, dialogs, settings screen
enum UILanguage {
  english,              // English UI text
  traditionalChinese,   // Traditional Chinese UI text
  simplifiedChinese,    // Simplified Chinese UI text
}

/// Singleton service for managing language and localization preferences
/// 
/// Separates UI language from TTS language, allowing flexible combinations:
/// - Traditional Chinese UI + English voice
/// - English UI + Mandarin voice
/// - etc.
/// 
/// All language state is stored in SharedPreferences for persistence.
class Language {
  // SharedPreferences storage keys
  /// Key for storing TTS language preference (voice)
  static const String _languageKey = 'tts_language';
  
  /// Key for storing UI language preference (interface text)
  static const String _uiLanguageKey = 'ui_language';

  // ============================================================================
  // TTS LANGUAGE METHODS (Voice/Audio Language)
  // ============================================================================

  /// Fetches current TTS language preference from SharedPreferences
  /// 
  /// What This Does:
  /// - Queries SharedPreferences for stored TTS language
  /// - Converts string back to TTSLanguage enum
  /// - Returns default (English) if not set (first install)
  /// 
  /// Returns:
  ///   TTSLanguage: Current voice language (english/traditionalChinese/simplifiedChinese)
  /// 
  /// Default Behavior:
  /// - First install: Returns TTSLanguage.english
  /// - After user selection: Returns previously saved selection
  /// - After app uninstall/data clear: Returns english again
  /// 
  /// Error Handling:
  /// - SharedPreferences error: Logs error, returns english
  /// - Invalid enum value: Returns english (shouldn't happen)
  /// - Missing preference: Returns english
  /// 
  /// Usage:
  ///   final ttsLang = await Language.getLanguage();
  ///   print('Current voice language: ${Language.getDisplayName(ttsLang)}');
  static Future<TTSLanguage> getLanguage() async {
    try {
      // Get SharedPreferences instance
      final prefs = await SharedPreferences.getInstance();
      
      // Retrieve stored TTS language (default to 'english' if not found)
      // String format: 'english', 'traditional_chinese', 'simplified_chinese'
      final langString = prefs.getString(_languageKey) ?? 'english';
      
      // Convert string back to enum
      switch (langString) {
        case 'traditional_chinese':
          return TTSLanguage.traditionalChinese;
        case 'simplified_chinese':
          return TTSLanguage.simplifiedChinese;
        default:
          return TTSLanguage.english;
      }
    } catch (e) {
      // SharedPreferences read error - default to English
      return TTSLanguage.english;
    }
  }

  /// Saves TTS language preference to SharedPreferences
  /// 
  /// What This Does:
  /// - Converts TTSLanguage enum to string
  /// - Stores in SharedPreferences with key 'tts_language'
  /// - Persists across app restarts
  /// - Immediately triggers language change in TTS engine
  /// 
  /// Parameters:
  ///   language: TTSLanguage enum value to save
  /// 
  /// Storage Format:
  ///   - TTSLanguage.english → 'english'
  ///   - TTSLanguage.traditionalChinese → 'traditional_chinese'
  ///   - TTSLanguage.simplifiedChinese → 'simplified_chinese'
  /// 
  /// Side Effects:
  /// - TTS engine will re-initialize with new language (in TTS.initialize())
  /// - New voice will be used for next speech request
  /// - UI updates via Settings screen state refresh
  /// 
  /// Error Handling:
  /// - SharedPreferences write error: Logs error, continues
  /// - Failures don't crash app (settings may not persist)
  /// 
  /// Usage:
  ///   // User selects Mandarin in settings
  ///   await Language.setLanguage(TTSLanguage.simplifiedChinese);
  ///   // Next speech will use Mandarin voice
  static Future<void> setLanguage(TTSLanguage language) async {
    try {
      // Get SharedPreferences instance
      final prefs = await SharedPreferences.getInstance();
      
      // Convert enum to string for storage
      String langString;
      switch (language) {
        case TTSLanguage.traditionalChinese:
          langString = 'traditional_chinese';
          break;
        case TTSLanguage.simplifiedChinese:
          langString = 'simplified_chinese';
          break;
        case TTSLanguage.english:
          langString = 'english';
          break;
      }
      
      // Store in SharedPreferences
      await prefs.setString(_languageKey, langString);
      
    } catch (e) {
      // SharedPreferences write error - log but continue
    }
  }

  /// Converts TTSLanguage enum to BCP-47 language code for native TTS engine
  /// 
  /// What This Does:
  /// - Maps TTSLanguage enum to standard language code
  /// - Used by Flutter TTS plugin to select correct voice/language on device
  /// - Follows BCP-47 standard: language-COUNTRY format
  /// 
  /// Language Codes:
  ///   - english → 'en-US' (US English - male voice, clear pronunciation)
  ///   - traditionalChinese → 'zh-HK' (Hong Kong Cantonese)
  ///   - simplifiedChinese → 'zh-CN' (Mainland Mandarin)
  /// 
  /// Parameters:
  ///   language: TTSLanguage enum value to convert
  /// 
  /// Returns:
  ///   String: BCP-47 language code (e.g., 'en-US', 'zh-HK', 'zh-CN')
  /// 
  /// Technical Details:
  /// - 'en-US' not 'en': More specific to US English (Android TTS defaults)
  /// - 'zh-HK': Cantonese TTS voice (different tone system from Mandarin)
  /// - 'zh-CN': Mandarin TTS voice (standard for mainland China)
  /// - Device must have voice data installed for language to work
  /// 
  /// Usage in TTS Engine:
  ///   final langCode = Language.getLanguageCode(ttsLang);
  ///   await flutterTts.setLanguage(langCode);  // Sets voice to this language
  /// 
  /// Usage:
  ///   final code = Language.getLanguageCode(TTSLanguage.simplifiedChinese);
  ///   print(code);  // Output: 'zh-CN'
  static String getLanguageCode(TTSLanguage language) {
    switch (language) {
      case TTSLanguage.traditionalChinese:
        return 'zh-HK'; // Hong Kong Cantonese TTS voice
      case TTSLanguage.simplifiedChinese:
        return 'zh-CN'; // Mainland Mandarin TTS voice
      case TTSLanguage.english:
        return 'en-US'; // US English TTS voice
    }
  }

  /// Gets human-readable display name for TTS language selection UI
  /// 
  /// What This Does:
  /// - Converts TTSLanguage enum to display string
  /// - Used in Settings screen language picker
  /// - Shows what the current voice language is
  /// 
  /// Display Names:
  ///   - english → 'English'
  ///   - traditionalChinese → '繁體中文 (廣東話)' (Traditional Chinese - Cantonese)
  ///   - simplifiedChinese → '简体中文 (普通话)' (Simplified Chinese - Mandarin)
  /// 
  /// Why Include Dialect Names:
  /// - Users need to know which accent/voice they'll get
  /// - Helps users select correct voice for their region
  /// - "(廣東話)" and "(普通话)" clarify the voice type
  /// 
  /// Parameters:
  ///   language: TTSLanguage enum to get display name for
  /// 
  /// Returns:
  ///   String: Localized display name suitable for UI labels
  /// 
  /// Usage:
  ///   final displayName = Language.getDisplayName(TTSLanguage.traditionalChinese);
  ///   print(displayName);  // Output: '繁體中文 (廣東話)'
  ///   
  ///   // In Settings Screen:
  ///   DropdownMenuItem(
  ///     value: TTSLanguage.traditionalChinese,
  ///     child: Text(Language.getDisplayName(TTSLanguage.traditionalChinese)),
  ///   )
  static String getDisplayName(TTSLanguage language) {
    switch (language) {
      case TTSLanguage.traditionalChinese:
        return '繁體中文 (廣東話)';  // Traditional Chinese with Cantonese voice indicator
      case TTSLanguage.simplifiedChinese:
        return '简体中文 (普通话)';    // Simplified Chinese with Mandarin voice indicator
      case TTSLanguage.english:
        return 'English';
    }
  }

  // ============================================================================
  // UI LANGUAGE METHODS (Interface Text Language)
  // ============================================================================

  /// Fetches current UI language preference from SharedPreferences
  /// 
  /// What This Does:
  /// - Queries SharedPreferences for stored UI language
  /// - Converts string back to UILanguage enum
  /// - Returns default (English) if not set (first install)
  /// - Controls what language all UI buttons, labels, dialogs display
  /// 
  /// Returns:
  ///   UILanguage: Current interface language (english/traditionalChinese/simplifiedChinese)
  /// 
  /// Default Behavior:
  /// - First install: Returns UILanguage.english
  /// - After user selection: Returns previously saved selection
  /// - After app uninstall/data clear: Returns english again
  /// 
  /// Error Handling:
  /// - SharedPreferences error: Logs error, returns english
  /// - Invalid enum value: Returns english
  /// - Missing preference: Returns english
  /// 
  /// Usage:
  ///   final uiLang = await Language.getUILanguage();
  ///   print('UI Language: ${Language.getUIDisplayName(uiLang)}');
  static Future<UILanguage> getUILanguage() async {
    try {
      // Get SharedPreferences instance
      final prefs = await SharedPreferences.getInstance();
      
      // Retrieve stored UI language (default to 'english' if not found)
      // String format: 'english', 'traditionalChinese', 'simplifiedChinese'
      final langString = prefs.getString(_uiLanguageKey) ?? 'english';
      
      // Convert string back to enum
      switch (langString) {
        case 'traditionalChinese':
          return UILanguage.traditionalChinese;
        case 'simplifiedChinese':
          return UILanguage.simplifiedChinese;
        default:
          return UILanguage.english;
      }
    } catch (e) {
      // SharedPreferences read error - default to English
      return UILanguage.english;
    }
  }

  /// Saves UI language preference to SharedPreferences
  /// 
  /// What This Does:
  /// - Converts UILanguage enum to string
  /// - Stores in SharedPreferences with key 'ui_language'
  /// - Persists across app restarts
  /// - Triggers UI rebuild on next frame (settings screen detects change)
  /// 
  /// Parameters:
  ///   language: UILanguage enum value to save
  /// 
  /// Storage Format:
  ///   - UILanguage.english → 'english'
  ///   - UILanguage.traditionalChinese → 'traditionalChinese'
  ///   - UILanguage.simplifiedChinese → 'simplifiedChinese'
  /// 
  /// Side Effects:
  /// - All UI text updates on next rebuild
  /// - Translations.get(key) returns text in new language
  /// - Settings screen reflects new UI language immediately
  /// - No TTS effect (voice independent from UI)
  /// 
  /// Error Handling:
  /// - SharedPreferences write error: Logs error, continues
  /// - Failures don't crash app (settings may not persist)
  /// 
  /// Usage:
  ///   // User selects Traditional Chinese in settings
  ///   await Language.setUILanguage(UILanguage.traditionalChinese);
  ///   // Next widget rebuild displays Traditional Chinese text
  static Future<void> setUILanguage(UILanguage language) async {
    try {
      // Get SharedPreferences instance
      final prefs = await SharedPreferences.getInstance();
      
      // Convert enum to string for storage
      String langString;
      switch (language) {
        case UILanguage.traditionalChinese:
          langString = 'traditionalChinese';
          break;
        case UILanguage.simplifiedChinese:
          langString = 'simplifiedChinese';
          break;
        case UILanguage.english:
          langString = 'english';
          break;
      }
      
      // Store in SharedPreferences
      await prefs.setString(_uiLanguageKey, langString);
      
    } catch (e) {
      // SharedPreferences write error - log but continue
    }
  }

  /// Gets human-readable display name for UI language selection
  /// 
  /// What This Does:
  /// - Converts UILanguage enum to display string
  /// - Used in Settings screen language picker
  /// - Shows what the current interface language is
  /// 
  /// Display Names:
  ///   - english → 'English'
  ///   - traditionalChinese → '繁體中文' (Traditional Chinese)
  ///   - simplifiedChinese → '简体中文' (Simplified Chinese)
  /// 
  /// Parameters:
  ///   language: UILanguage enum to get display name for
  /// 
  /// Returns:
  ///   String: Localized display name suitable for UI labels
  /// 
  /// Usage:
  ///   final displayName = Language.getUIDisplayName(UILanguage.traditionalChinese);
  ///   print(displayName);  // Output: '繁體中文'
  ///   
  ///   // In Settings Screen:
  ///   DropdownMenuItem(
  ///     value: UILanguage.traditionalChinese,
  ///     child: Text(Language.getUIDisplayName(UILanguage.traditionalChinese)),
  ///   )
  static String getUIDisplayName(UILanguage language) {
    switch (language) {
      case UILanguage.traditionalChinese:
        return '繁體中文';  // Traditional Chinese
      case UILanguage.simplifiedChinese:
        return '简体中文';    // Simplified Chinese
      case UILanguage.english:
        return 'English';
    }
  }
}
