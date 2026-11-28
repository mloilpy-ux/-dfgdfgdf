import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:furry_content_hub/models/content_source.dart';
import 'package:furry_content_hub/services/browser_media.dart';

void main() {
  final source = ContentSource.fromUrl('r/furry');
  final page = Uri.parse(source.url);
  List<dynamic> parse(List<String> urls) => BrowserMedia.fromPage(
    jsonEncode({'page': page.toString(), 'items': urls.map((url) => {
      'url': url, 'kind': 'image', 'title': 'Artwork'
    }).toList()}), source, page);
  const original = 'https://i.redd.it/art.jpg';
  const small = 'https://preview.redd.it/art.jpg?width=108&token=old';
  const large = 'https://preview.redd.it/art.jpg?width=1080&token=large';

  test('Reddit original survives a thumbnail discovered later in the same batch', () {
    final items = parse([original, small]);
    expect(items, hasLength(1));
    expect(items.single.mediaUrl, original);
  });
  test('Largest available Reddit preview wins regardless of discovery order', () {
    expect(parse([large, small]).single.mediaUrl, large);
    expect(parse([small, large]).single.mediaUrl, large);
  });
  test('Equal quality replaces an old signed URL and preserves identity', () {
    const fresh = 'https://preview.redd.it/art.jpg?width=108&token=fresh';
    expect(parse([small, fresh]).single.mediaUrl, fresh);
    expect(parse([original]).single.id, parse([small]).single.id);
  });
}
