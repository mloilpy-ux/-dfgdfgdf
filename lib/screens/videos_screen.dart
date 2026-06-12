  List<ContentItem> _getFilteredItems() {
    final provider = context.read<ContentProvider>();
    final settings = context.read<SettingsProvider>();

    // Видео: MP4/WEBM файлы (не GIF)
    var items = provider.items.where((item) {
      final url = item.mediaUrl.toLowerCase();
      return url.contains('.mp4') || url.contains('.webm');
    }).toList();

    if (!settings.showNsfw) {
      items = items.where((item) => !item.isNsfw).toList();
    }

    items = items.where((item) => !_errorUrls.contains(item.mediaUrl)).toList();

    return items;
  }
