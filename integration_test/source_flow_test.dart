import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furry_content_hub/main.dart';
import 'package:furry_content_hub/models/content_item.dart';
import 'package:furry_content_hub/models/content_source.dart';
import 'package:furry_content_hub/providers/content_provider.dart';
import 'package:furry_content_hub/providers/logger_provider.dart';
import 'package:furry_content_hub/providers/settings_provider.dart';
import 'package:furry_content_hub/providers/sources_provider.dart';
import 'package:furry_content_hub/screens/gifs_screen.dart';
import 'package:furry_content_hub/services/database_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:video_player/video_player.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android creates SQLite tables, opens sources and imports a new channel', (
    tester,
  ) async {
    final path = join(await getDatabasesPath(), 'source_flow_test.db');
    await deleteDatabase(path);
    final db = DatabaseService(path: path);
    final sources = SourcesProvider(database: db);
    final imageServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await imageServer.close(force: true);
      await (await db.database).close();
      await deleteDatabase(path);
    });
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAABAAAAAYCAIAAAB8wupbAAAAHUlEQVR4nGMscZvJQApgIkn1qIZRDaMaRjWQrAEAha'
      '8Bg6vGN80AAAAASUVORK5CYII=',
    );
    final gif = base64Decode(
      'R0lGODlhEAAQAIEAAHMUcwAAAAAAAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQADwAAACwAAAAAEAAQAAAIHQABCB'
      'xIsKDBgwgTKlzIsKHDhxAjSpxIsaLFgQEBACH5BAEPAAEALAAAAAAQABAAgSigggAAAAAAAAAAAAgdAAEIHEiwoMGD'
      'CBMqXMiwocOHECNKnEixosWBAQEAOw==',
    );
    final video = base64Decode(
      'AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAORbW9vdgAAAGxtdmhkAAAAAAAAAAAAAAAAAAAD6AAAB9AAAQA'
      'AAQAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAgAAArx0cmFrAAAAXHRraGQAAAADAAAAAAAAAAAAAAABAAAAAAAAB9AAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAA'
      'AAAAAAAAAABAAAAAAAAAAAAAAAAAABAAAAAACAAAAAgAAAAAAAkZWR0cwAAABxlbHN0AAAAAAAAAAEAAAfQAAAgAAABAAAA'
      'AAI0bWRpYQAAACBtZGhkAAAAAAAAAAAAAAAAAABAAAAAgABVxAAAAAAALWhkbHIAAAAAAAAAAHZpZGUAAAAAAAAAAAAAAAB'
      'WaWRlb0hhbmRsZXIAAAAB321pbmYAAAAUdm1oZAAAAAEAAAAAAAAAAAAAACRkaW5mAAAAHGRyZWYAAAAAAAAAAQAAAAx1cm'
      'wgAAAAAQAAAZ9zdGJsAAAAv3N0c2QAAAAAAAAAAQAAAK9hdmMxAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAACAAIABIAAAAS'
      'AAAAAAAAAABFUxhdmM2MS4xOS4xMDEgbGlieDI2NAAAAAAAAAAAAAAAGP//AAAANWF2Y0MBZAAK/+EAGGdkAAqs2UlsBEAA'
      'AAMAQAAAAwIDxIllgAEABmjr48siwP34+AAAAAAQcGFzcAAAAAEAAAABAAAAFGJ0cnQAAAAAAAAMoAAAAAAAAAAYc3R0cwA'
      'AAAAAAAABAAAACAAAEAAAAAAUc3RzcwAAAAAAAAABAAAAAQAAAEhjdHRzAAAAAAAAAAcAAAABAAAgAAAAAAEAAFAAAAAAAQ'
      'AAIAAAAAABAAAAAAAAAAEAABAAAAAAAQAAQAAAAAACAAAQAAAAABxzdHNjAAAAAAAAAAEAAAABAAAACAAAAAEAAAA0c3Rze'
      'gAAAAAAAAAAAAAACAAAAsoAAAANAAAADAAAAAwAAAAMAAAAEwAAAA4AAAAMAAAAFHN0Y28AAAAAAAAAAQAAA8EAAABhdWR0'
      'YQAAAFltZXRhAAAAAAAAACFoZGxyAAAAAAAAAABtZGlyYXBwbAAAAAAAAAAAAAAAACxpbHN0AAAAJKl0b28AAAAcZGF0YQA'
      'AAAEAAAAATGF2ZjYxLjcuMTAzAAAACGZyZWUAAAMwbWRhdAAAAq0GBf//qdxF6b3m2Ui3lizYINkj7u94MjY0IC0gY29yZS'
      'AxNjQgcjMxMDggMzFlMTlmOSAtIEguMjY0L01QRUctNCBBVkMgY29kZWMgLSBDb3B5bGVmdCAyMDAzLTIwMjMgLSBodHRwO'
      'i8vd3d3LnZpZGVvbGFuLm9yZy94MjY0Lmh0bWwgLSBvcHRpb25zOiBjYWJhYz0xIHJlZj0zIGRlYmxvY2s9MTowOjAgYW5h'
      'bHlzZT0weDM6MHgxMTMgbWU9aGV4IHN1Ym1lPTcgcHN5PTEgcHN5X3JkPTEuMDA6MC4wMCBtaXhlZF9yZWY9MSBtZV9yYW5'
      'nZT0xNiBjaHJvbWFfbWU9MSB0cmVsbGlzPTEgOHg4ZGN0PTEgY3FtPTAgZGVhZHpvbmU9MjEsMTEgZmFzdF9wc2tpcD0xIG'
      'Nocm9tYV9xcF9vZmZzZXQ9LTIgdGhyZWFkcz0xIGxvb2thaGVhZF90aHJlYWRzPTEgc2xpY2VkX3RocmVhZHM9MCBucj0wI'
      'GRlY2ltYXRlPTEgaW50ZXJsYWNlZD0wIGJsdXJheV9jb21wYXQ9MCBjb25zdHJhaW5lZF9pbnRyYT0wIGJmcmFtZXM9MyBi'
      'X3B5cmFtaWQ9MiBiX2FkYXB0PTEgYl9iaWFzPTAgZGlyZWN0PTEgd2VpZ2h0Yj0xIG9wZW5fZ29wPTAgd2VpZ2h0cD0yIGt'
      'leWludD0yNTAga2V5aW50X21pbj00IHNjZW5lY3V0PTQwIGludHJhX3JlZnJlc2g9MCByY19sb29rYWhlYWQ9NDAgcmM9Y3'
      'JmIG1idHJlZT0xIGNyZj0yMy4wIHFjb21wPTAuNjAgcXBtaW49MCBxcG1heD02OSBxcHN0ZXA9NCBpcF9yYXRpbz0xLjQwI'
      'GFxPTE6MS4wMACAAAAAFWWIhAAT//73sY+BTctIRZc4kgD/wQAAAAlBmiRsQS/+tcAAAAAIQZ5CeII/L6EAAAAIAZ5hdEEP'
      'NSAAAAAIAZ5jakEPNSEAAAAPQZpnSahBaJlMCCH//quBAAAACkGehUURLBH/L6EAAAAIAZ6makEPNSE=',
    );
    imageServer.listen((request) {
      final (type, bytes) = switch (request.uri.path) {
        '/animation.GIF' => (ContentType('image', 'gif'), gif),
        '/video-clip' => (ContentType('video', 'mp4'), video),
        _ => (ContentType('image', 'png'), png),
      };
      request.response.headers.contentType = type;
      request.response.contentLength = bytes.length;
      request.response.add(bytes);
      request.response.close();
    });

    final mediaBase = 'http://127.0.0.1:${imageServer.port}';
    final content = ContentProvider(
      database: db,
      client: MockClient((request) async {
        if (request.url.path == '/s/furries') {
          return http.Response(
            '<section class="tgme_channel_history"></section>',
            200,
          );
        }
        if (request.url.path != '/s/fixture')
          return http.Response('not found', 404);
        final body =
            '''
        <section class="tgme_channel_history">
          <div class="tgme_widget_message" data-post="fixture/42">
            <div class="tgme_widget_message_text">Тестовые обои</div>
            <a class="tgme_widget_message_photo_wrap" style="background-image: url('$mediaBase/paper.png')"></a>
            <a class="tgme_widget_message_photo_wrap" style='background-image:url("$mediaBase/animation.GIF?size=2")'></a>
            <video><source src="$mediaBase/video-clip" type="video/mp4"></video>
            <a class="tgme_widget_message_date" href="https://t.me/fixture/42"><time datetime="2026-06-01T12:00:00Z"></time></a>
          </div>
        </section>
      ''';
        return http.Response.bytes(utf8.encode(body), 200);
      }),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: sources),
          ChangeNotifierProvider.value(value: content),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => LoggerProvider()),
        ],
        child: const MyApp(),
      ),
    );
    await _waitFor(tester, find.text('Обои'));
    await _waitFor(tester, find.text('Обоев пока нет'));

    await tester.tap(find.byTooltip('Источники'));
    await _waitFor(tester, find.text('@furries'));
    expect(sources.loadError, isNull);

    await tester.tap(find.text('Добавить источник'));
    await _waitFor(tester, find.byType(TextField));
    await tester.enterText(
      find.byType(TextField),
      'https://t.me/s/fixture/42?single',
    );
    await tester.tap(find.text('Добавить'));
    await _waitFor(tester, find.text('Новых материалов: 3 · всего найдено: 3'));
    final source = sources.sources.singleWhere(
      (source) => source.url == 'https://t.me/fixture',
    );

    expect(
      sources.sources.singleWhere((entry) => entry.id == source.id).parsedCount,
      1,
    );
    for (final kind in MediaKind.values) {
      expect(content.itemsFor(kind, showNsfw: false), hasLength(1));
    }
    final wallpaper = content.itemsFor(MediaKind.image, showNsfw: false).single;
    expect(await content.toggleSave(wallpaper), isTrue);
    final duplicate = await sources.addSource('@fixture');
    expect(duplicate.id, source.id);
    await content.importSource(source, sources);
    expect(
      content.resultFor(source.id)?.message,
      'Новых материалов: 0 · всего найдено: 3',
    );
    expect(content.savedItems.single.id, wallpaper.id);

    await tester.binding.handlePopRoute();
    await _waitFor(tester, find.text('Тестовые обои'));
    expect(find.text('Установить обои'), findsOneWidget);
    await tester.tap(find.byTooltip('Другие разделы'));
    await _waitFor(tester, find.text('Фильтр по источнику'));
    await tester.tap(_menuItem('Фильтр по источнику'));
    final sourceOption = find.descendant(
      of: find.byType(SimpleDialog),
      matching: find.text('@fixture'),
    );
    await _waitFor(tester, sourceOption);
    await tester.tap(sourceOption);
    await _waitFor(tester, find.text('Тестовые обои'));
    expect(content.selectedSourceId, source.id);

    final renderedImage = find.byWidgetPredicate(
      (widget) => widget is RawImage && widget.image != null,
    );
    await _waitFor(tester, renderedImage);
    await tester.tap(find.byTooltip('Другие разделы'));
    await _waitFor(tester, find.text('GIF'));
    await tester.tap(_menuItem('GIF'));
    await _waitFor(
      tester,
      find.descendant(of: find.byType(GifsScreen), matching: renderedImage),
    );
    expect(find.text('Нет GIF'), findsNothing);
    await tester.binding.handlePopRoute();
    await _waitFor(tester, find.text('Установить обои'));
    await tester.tap(find.byTooltip('Другие разделы'));
    await _waitFor(tester, find.text('Видео'));
    await tester.tap(_menuItem('Видео'));
    await _waitFor(tester, find.byType(VideoPlayer));
    await tester.binding.handlePopRoute();
    await _waitFor(tester, find.text('Установить обои'));

    final bad = await sources.addSource('@unavailable');
    final failed = await content.importSource(bad, sources);
    expect(failed.failed, isTrue);
    expect(failed.message, contains('источник не найден'));
    expect(
      sources.sources.singleWhere((entry) => entry.id == bad.id).parsedCount,
      0,
    );

    await sources.toggleSource(source);
    await content.sourceChanged(sources.activeSources);
    expect(content.items, isEmpty);
    expect(content.selectedSourceId, isNull);
    expect(content.savedItems.single.id, wallpaper.id);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('SQLite upgrades previous installs and keeps saved media', (
    _,
  ) async {
    final path = join(await getDatabasesPath(), 'source_migration_test.db');
    await deleteDatabase(path);
    final v2 = await openDatabase(path, version: 2);
    await v2.execute('''
      CREATE TABLE sources (
        id TEXT PRIMARY KEY, name TEXT, url TEXT, type TEXT, isActive INTEGER,
        addedAt TEXT, isNsfw INTEGER, lastParsed TEXT, parsedCount INTEGER
      )
    ''');
    await v2.insert('sources', {
      'id': 'older',
      'name': 'Old',
      'url': 'https://t.me/older',
      'type': 'telegram',
      'isActive': 1,
      'addedAt': '2026-01-01T00:00:00Z',
      'isNsfw': 0,
      'parsedCount': 3,
    });
    await v2.execute('''
      CREATE TABLE content (
        id TEXT PRIMARY KEY, sourceId TEXT, title TEXT, author TEXT, mediaUrl TEXT,
        thumbnailUrl TEXT, isGif INTEGER, isNsfw INTEGER, isSaved INTEGER,
        createdAt TEXT, postUrl TEXT
      )
    ''');
    await v2.insert('content', {
      'id': 'old-video',
      'sourceId': 'older',
      'title': 'Old video',
      'mediaUrl': 'https://example.org/old.MP4?size=2',
      'isGif': 1,
      'isNsfw': 0,
      'isSaved': 1,
      'createdAt': '2026-01-01T00:00:00Z',
    });
    await v2.close();

    final db = DatabaseService(path: path);
    final saved = await db.getContent(onlySaved: true);
    expect(saved.single.id, 'old-video');
    expect(saved.single.kind, MediaKind.video);
    final sources = await db.getSources();
    expect(
      sources.singleWhere((source) => source.id == 'older').parsedCount,
      3,
    );
    expect(
      sources.any((source) => source.id == 'default_telegram_furries'),
      isTrue,
    );
    await (await db.database).close();
    await deleteDatabase(path);
  });

  testWidgets('Reddit and X use their APIs and preserve media categories', (
    _,
  ) async {
    final path = join(await getDatabasesPath(), 'oauth_import_test.db');
    await deleteDatabase(path);
    final db = DatabaseService(path: path);
    final sources = SourcesProvider(database: db)
      ..setToken(SourceType.reddit, 'reddit-fixture')
      ..setToken(SourceType.twitter, 'x-fixture');
    final content = ContentProvider(
      database: db,
      client: MockClient((request) async {
        if (request.url.host == 'oauth.reddit.com') {
          expect(request.headers['authorization'], 'Bearer reddit-fixture');
          expect(request.url.path, '/r/furry/hot');
          return http.Response('''
          {"data":{"children":[
            {"data":{"id":"a","title":"A","url":"https://example.org/photo.png"}},
            {"data":{"id":"b","title":"B","url":"https://example.org/anim.gif?size=2"}}
          ]}}
        ''', 200);
        }
        expect(request.headers['authorization'], 'Bearer x-fixture');
        expect(request.url.host, 'api.x.com');
        if (request.url.path.startsWith('/2/users/by/username/')) {
          return http.Response('{"data":{"id":"42"}}', 200);
        }
        expect(request.url.path, '/2/users/42/tweets');
        return http.Response('''
        {"data":[{"id":"7","text":"V","attachments":{"media_keys":["media1"]}}],
         "includes":{"media":[{"media_key":"media1","type":"video","variants":[
           {"content_type":"video/mp4","url":"https://example.org/video.mp4"}
         ]}]}}
      ''', 200);
      }),
    );
    final reddit = await sources.addSource(
      'https://old.reddit.com/r/Furry/comments/id/title',
    );
    final x = await sources.addSource('https://twitter.com/Fixture/media');
    expect((await content.importSource(reddit, sources)).failed, isFalse);
    expect((await content.importSource(x, sources)).failed, isFalse);
    for (final kind in MediaKind.values) {
      expect(content.itemsFor(kind, showNsfw: false), hasLength(1));
    }
    content.dispose();
    sources.dispose();
    await (await db.database).close();
    await deleteDatabase(path);
  });
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  final limit = Stopwatch()..start();
  while (finder.evaluate().isEmpty &&
      limit.elapsed < const Duration(seconds: 20)) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  expect(finder, findsOneWidget);
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _menuItem(String title) => find.ancestor(
  of: find.text(title),
  matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
);
