/*
TapCall — Translated Text widget

Purpose:
- Display localized UI strings based on the current UI language.
- Resolves translations asynchronously and falls back to the provided key while loading.

Usage:
- T('settings_title')
- T('greeting', params: {'name': 'Alex'})

Notes:
- This widget listens to the future from `Translations.get()`; when the language changes and code requests a new build, text updates accordingly.
*/

import 'package:flutter/material.dart';
import '../translations.dart';

/// Widget that displays translated text and updates when language changes
class T extends StatelessWidget {
  final String translationKey; // Translation lookup identifier
  final Map<String, String>? params; // Template parameters for string replacement
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const T(
    this.translationKey, {
    super.key,
    this.params,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: Translations.get(translationKey, params: params),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text(
            snapshot.data!,
            style: style,
            maxLines: maxLines,
            overflow: overflow,
            textAlign: textAlign,
          );
        }
        // Fallback to translationKey while loading
        return Text(
          translationKey,
          style: style,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
        );
      },
    );
  }
}
