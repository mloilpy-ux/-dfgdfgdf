// lib/models/source_type.dart
enum SourceType {
  reddit,
  twitter,
  telegram,
}

extension SourceTypeExtension on SourceType {
  String get displayName {
    switch (this) {
      case SourceType.reddit:
        return 'Reddit';
      case SourceType.twitter:
        return 'Twitter/X';
      case SourceType.telegram:
        return 'Telegram';
    }
  }

  String get icon {
    switch (this) {
      case SourceType.reddit:
        return '🐾';
      case SourceType.twitter:
        return '🐦';
      case SourceType.telegram:
        return '✈️';
    }
  }
}
