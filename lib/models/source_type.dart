enum SourceType {
  reddit,
  twitter,
  telegram,
  direct,
  pinterest,
  web;

  String get displayName => switch (this) {
    reddit => 'Reddit',
    twitter => 'X',
    telegram => 'Telegram',
    direct => 'Медиафайл',
    pinterest => 'Pinterest',
    web => 'Веб-страница',
  };

  String get icon => switch (this) {
    reddit => '🔴',
    twitter => '𝕏',
    telegram => '✈️',
    direct => '🔗',
    pinterest => '📌',
    web => '🌐',
  };

  bool get opensInBrowser => this != telegram && this != direct;
}
