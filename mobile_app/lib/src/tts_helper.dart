/// TapCall TTSHelper
///
/// Purpose:
/// - Centralizes Text‑to‑Speech (TTS) configuration and speaking behavior
/// - Adapts voice language to user preference (English/Cantonese/Mandarin)
/// - Tunes speech rate for elderly‑friendly clarity
///
/// Usage:
/// - Call `speak(text)` to queue speech; helper ensures proper initialization
library;

import 'package:flutter_tts/flutter_tts.dart';
import 'language_helper.dart';

class TTSHelper {
  static final TTSHelper _instance = TTSHelper._internal();
  factory TTSHelper() => _instance;
  TTSHelper._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  TTSLanguage? _currentLanguage;

  Future<void> initialize() async {
    final language = await LanguageHelper.getLanguage();
    
    // Re-initialize if language changed
    if (_isInitialized && _currentLanguage == language) return;

    _currentLanguage = language;
    final langCode = LanguageHelper.getLanguageCode(language);
    
    await _tts.setLanguage(langCode);
    await _tts.setSpeechRate(0.5); // Slower for elderly
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    
    // Configure for elderly-friendly speech
    await _tts.awaitSpeakCompletion(true);
    
    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    await initialize();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<bool> get isSpeaking async {
    // FlutterTts doesn't have a reliable isSpeaking method
    // Return false for now
    return false;
  }
}
