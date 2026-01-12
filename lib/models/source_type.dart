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
        return '🐾'; // Reddit icon
      case SourceType.twitter:
        return '🐦'; // Twitter icon
      case SourceType.telegram:
        return '✈️'; // Telegram icon
    }
  }
}
