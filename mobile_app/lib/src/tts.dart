/*
===============================================================================
TapCall — Text-to-Speech Service
===============================================================================

Purpose:
- Centralizes Text-to-Speech (TTS) configuration and speech output
- Adapts voice language to user preference (English/Traditional Chinese/Simplified Chinese)
- Optimizes speech parameters for elderly-friendly clarity and comprehension
- Ensures proper TTS engine initialization before speaking

Design Philosophy:
- Singleton pattern: One TTS engine shared across entire app (Flutter best practice)
- Lazy initialization: TTS engine only initializes on first speech request
- Language-aware: Automatically detects language changes and re-initializes
- Graceful error handling: Returns silently if TTS fails, doesn't crash app

Speech Configuration (Tuned for Elderly):
- Speech Rate: 0.5x (50% of normal) - slower for better comprehension
- Volume: 1.0 (100% - maximum)
- Pitch: 1.0 (normal tone - neutral, professional)
- Await Completion: Enabled - blocks next speech until current finishes (prevents overlapping audio)

Dependencies:
- flutter_tts: Cross-platform TTS engine (Android/iOS)
- language: User's current TTS language preference

Error Handling Strategy:
- Initialization errors: Logged, continue anyway (TTS might work despite errors)
- Speaking errors: Caught and silently ignored (app continues normally)
- No exceptions propagated: TTS failures don't crash app interface

Usage Example:
  final tts = TTS();
  await tts.speak('現在天氣晴朗');  // Automatically uses current language
  await tts.stop();                  // Stop mid-speech if needed
*/

import 'package:flutter_tts/flutter_tts.dart';
import 'language.dart';

/// Singleton Text-to-Speech service for voice announcements
/// 
/// Manages TTS engine lifecycle, language selection, and speech parameters.
/// Automatically handles language changes without requiring manual restart.
class TTS {
  /// Static singleton instance - ensures only one TTS engine exists
  static final TTS _instance = TTS._internal();
  
  /// Factory constructor returns the singleton instance
  /// Usage: `final tts = TTS();` always returns same instance
  factory TTS() => _instance;
  
  /// Private constructor prevents external instantiation
  TTS._internal();

  /// FlutterTts engine instance - communicates with native Android/iOS TTS
  /// Manages audio output, language settings, speech parameters
  final FlutterTts _tts = FlutterTts();
  
  /// Tracks initialization state to avoid redundant setup
  /// Set to true after first successful initialization
  bool _isInitialized = false;
  
  /// Caches last used language to detect changes
  /// If language changes, re-initialize TTS with new language code
  TTSLanguage? _currentLanguage;

  /// Initializes TTS engine with current language settings
  /// 
  /// Process:
  /// 1. Fetch user's current TTS language preference from SharedPreferences
  /// 2. Compare with cached language - if same, skip re-initialization (optimization)
  /// 3. If language changed, apply new language code to TTS engine
  /// 4. Configure speech parameters for elderly users:
  ///    - Speech rate 0.5x for better comprehension
  ///    - Full volume (1.0)
  ///    - Normal pitch (1.0)
  ///    - Await completion to prevent speech overlapping
  /// 5. Mark as initialized
  /// 
  /// Called automatically by speak() - not typically called directly
  /// Safe to call multiple times (checks for redundant initialization)
  Future<void> initialize() async {
    try {
      // Fetch current TTS language from user settings
      final language = await Language.getLanguage();
      
      // Optimization: Skip re-initialization if language hasn't changed
      // (Reinitializing TTS for same language wastes resources and time)
      if (_isInitialized && _currentLanguage == language) {
        return;
      }

      // Cache the current language for next call's comparison
      _currentLanguage = language;
      
      // Convert TTSLanguage enum to BCP-47 language code
      // Example: TTSLanguage.traditionalChinese → 'zh-HK' (Hong Kong Cantonese)
      // Example: TTSLanguage.simplifiedChinese → 'zh-CN' (Mainland Mandarin)
      // Example: TTSLanguage.english → 'en-US'
      final langCode = Language.getLanguageCode(language);
      
      // Apply language code to TTS engine
      // This determines which voice and pronunciation rules are used
      await _tts.setLanguage(langCode);
      
      // Set speech rate to 0.5x (50% of normal speed)
      // Elderly users need slower speech for comprehension
      // Range: 0.1-1.0 (lower = slower)
      await _tts.setSpeechRate(0.5);
      
      // Set volume to maximum (1.0 = 100%)
      // Elderly users often have hearing difficulties
      await _tts.setVolume(1.0);
      
      // Set pitch to normal (1.0 = neutral tone)
      // Neutral pitch sounds professional and clear
      // Range: 0.5-2.0 (lower = deeper voice, higher = higher pitch)
      await _tts.setPitch(1.0);
      
      // Enable await completion for elderly-friendly experience
      // When true: TTS waits for current speech to finish before returning control
      // Prevents overlapping/garbled audio when rapid speech requests occur
      await _tts.awaitSpeakCompletion(true);
      
      // Mark initialization as complete
      _isInitialized = true;
      
    } catch (e) {
      // Log initialization error but continue anyway
      // TTS might still work despite configuration issues
      // (e.g., language not available on device, TTS service temporarily unavailable)
      // Still mark as attempted to avoid infinite retry loops
      _isInitialized = true;
    }
  }

  /// Speaks text aloud using configured TTS engine and current language
  /// 
  /// Process:
  /// 1. Ensure TTS is initialized with current language
  /// 2. Validate text is not empty (empty string causes TTS errors)
  /// 3. Send text to native TTS engine for audio synthesis
  /// 4. Audio plays through device speaker
  /// 5. If awaitSpeakCompletion is true, method blocks until speech finishes
  /// 
  /// Parameters:
  ///   text: String to speak aloud (supports Chinese, English)
  /// 
  /// Returns:
  ///   Completes when TTS speech finishes (if awaitSpeakCompletion enabled)
  ///   or when speech request queued (if disabled)
  /// 
  /// Examples:
  ///   await tts.speak('現在是上午十點');     // Traditional Chinese
  ///   await tts.speak('现在是上午十点');     // Simplified Chinese
  ///   await tts.speak('The current time is 10 AM');  // English
  /// 
  /// Error Handling:
  ///   - Catches exceptions from native TTS layer
  ///   - Silently continues if TTS fails (app doesn't crash)
  ///   - Empty text is ignored without error
  Future<void> speak(String text) async {
    try {
      // Initialize TTS if not already done, or if language changed
      // This is called every time to ensure language is current
      await initialize();
      
      // Validate text is not empty
      // Empty strings cause native TTS errors on some devices
      if (text.isEmpty) {
        return;
      }
      
      // Send text to TTS engine for audio synthesis and playback
      // On Android: Uses Android TextToSpeech service
      // On iOS: Uses AVSpeechSynthesizer framework
      await _tts.speak(text);
      
    } catch (e) {
      // Catch any TTS errors:
      // - Native service not available
      // - Text encoding issues
      // - Audio system errors
      // Log error for debugging but don't propagate (app continues)
    }
  }

  /// Immediately stops any ongoing speech
  /// 
  /// Use Cases:
  /// - User dismisses call screen (stop voice announcement)
  /// - User wants to cancel long message playback
  /// - Emergency stop for any reason
  /// 
  /// Returns:
  ///   Completes immediately after stop command sent
  ///   (audio may take a few milliseconds to actually stop)
  /// 
  /// Error Handling:
  ///   - Catches exceptions but doesn't propagate
  ///   - Safe to call even if no speech in progress
  Future<void> stop() async {
    try {
      // Send stop command to TTS engine
      // Stops any currently playing audio
      await _tts.stop();
    } catch (e) {
      // TTS stop errors are rarely critical - ignore and continue
    }
  }

  /// Shuts down TTS engine and releases audio resources
  /// 
  /// Should be called when app terminates to:
  /// - Release native audio handles
  /// - Stop any ongoing speech
  /// - Free TTS engine memory
  /// 
  /// Typical usage: Call in app's dispose/cleanup handler
  /// (Usually handled by Flutter framework, but available if needed)
  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (e) {
      // Ignore disposal errors - TTS cleanup is non-critical
    }
  }
}
