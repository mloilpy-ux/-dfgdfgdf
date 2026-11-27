import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:furry_content_hub/models/content_source.dart';
import 'package:furry_content_hub/models/content_item.dart';
import 'package:furry_content_hub/services/web_scraper_service.dart';
import 'package:furry_content_hub/services/source_response.dart';

const page =
    '''<section class="tgme_channel_history"><div class="tgme_widget_message" data-post="fixture/42"><div class="tgme_widget_message_text">Test</div><a class="tgme_widget_message_photo_wrap" style="background-image:url('https://cdn.example.org/image.jpg')"></a></div></section>''';
void main() {
  final source = ContentSource.fromUrl('@fixture');
  test(
    'Telegram recovers a media batch after a transient request timeout',
    () async {
      var calls = 0;
      final parser = WebScraperService(
        MockClient((request) async {
          expect(request.url.toString(), 'https://t.me/s/fixture?before=50');
          if (++calls == 1) throw TimeoutException('transient network stall');
          return http.Response(page, 200);
        }),
      );
      final items = await parser.parseTelegram(source, before: '50');
      expect(items.single.mediaUrl, 'https://cdn.example.org/image.jpg');
      expect(items.single.kind, MediaKind.image);
      expect(calls, 2);
    },
  );
  test(
    'Telegram stops after two failed attempts with an actionable failure',
    () async {
      var calls = 0;
      final parser = WebScraperService(
        MockClient((_) async {
          calls++;
          throw TimeoutException('persistent network stall');
        }),
      );
      await expectLater(
        parser.parseTelegram(source),
        throwsA(isA<SourceFailure>()),
      );
      expect(calls, 2);
    },
  );
  test('Telegram does not retry a forbidden page', () async {
    var calls = 0;
    final parser = WebScraperService(
      MockClient((_) async {
        calls++;
        return http.Response('forbidden', 403);
      }),
    );
    await expectLater(
      parser.parseTelegram(source),
      throwsA(isA<SourceFailure>()),
    );
    expect(calls, 1);
  });
}
