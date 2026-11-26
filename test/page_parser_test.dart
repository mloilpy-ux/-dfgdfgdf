import 'package:flutter_test/flutter_test.dart';
import 'package:furry_content_hub/models/content_source.dart';
import 'package:furry_content_hub/models/content_item.dart';
import 'package:furry_content_hub/services/page_parser.dart';
import 'package:furry_content_hub/services/source_response.dart';

void main() {
  final source = ContentSource.fromUrl('https://example.org/gallery');
  final page = Uri.parse(source.url);
  test('HTML classifies GIF, image, video and preserves next page', () {
    final batch = PageParser.parse(
      '''<title>Night</title><main>
      <img src="/a.gif" width="200"><img src="/a.gif" width="200">
      <img src="/b.jpg" width="200"><video src="/c.mp4"></video>
      <img src="/icon.png" width="20"></main><a rel="next" href="?page=2">Next</a>''',
      source,
      page,
    );
    expect(batch.items.map((i) => i.kind).toSet(), {
      MediaKind.gif,
      MediaKind.image,
      MediaKind.video,
    });
    expect(batch.items, hasLength(3));
    expect(batch.next.toString(), 'https://example.org/gallery?page=2');
  });
  test('Does not follow off-site pagination or import challenge as success', () {
    final batch = PageParser.parse(
      '<main><img src="/x.jpg"></main><a rel="next" href="https://other.org/next">next</a>',
      source,
      page,
    );
    expect(batch.next, isNull);
    expect(
      () => PageParser.parse('<input name="js_challenge">', source, page),
      throwsA(isA<SourceFailure>()),
    );
    expect(
      () => PageParser.parse('<input type="password">', source, page),
      throwsA(isA<SourceFailure>()),
    );
  });
  test('Reddit public card exposes media and adult marker without API', () {
    final reddit = ContentSource.fromUrl('r/furry');
    final batch = PageParser.parse(
      '<shreddit-post content-href="https://i.redd.it/test.png" nsfw="true" post-title="art"></shreddit-post>',
      reddit,
      Uri.parse(reddit.url),
    );
    expect(batch.items.single.isNsfw, isTrue);
  });
}
