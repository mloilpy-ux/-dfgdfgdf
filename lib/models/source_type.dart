enum SourceType {
  reddit,
  twitter,
  telegram,
  direct;

  String get displayName => switch (this) {
    reddit => 'Reddit',
    twitter => 'X',
    telegram => 'Telegram',
    direct => 'Медиафайл',
  };

  String get icon => switch (this) {
    reddit => '🔴',
    twitter => '𝕏',
    telegram => '✈️',
    direct => '🔗',
  };

  bool get requiresToken => this == reddit || this == twitter;
}
