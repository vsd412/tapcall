/// Function types available for each button slot
enum FunctionType {
  contact,      // Video call via WhatsApp
  time,         // Announce current date and time
  weather,      // Announce current weather
}

/// Extension for FunctionType display names
extension FunctionTypeExtension on FunctionType {
  String get displayName {
    switch (this) {
      case FunctionType.contact:
        return 'Contact';
      case FunctionType.time:
        return 'Time&Date';
      case FunctionType.weather:
        return 'Weather';
    }
  }

  String get description {
    switch (this) {
      case FunctionType.contact:
        return 'Make a video call';
      case FunctionType.time:
        return 'Hear current date and time';
      case FunctionType.weather:
        return 'Hear weather forecast';
    }
  }

  String get icon {
    switch (this) {
      case FunctionType.contact:
        return '📞';
      case FunctionType.time:
        return '🕐';
      case FunctionType.weather:
        return '🌤️';
    }
  }
}
