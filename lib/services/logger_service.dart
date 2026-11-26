import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class LoggerService {
  static final instance = LoggerService._init();
  LoggerService._init();
  final List<String> _logs = [];
  Future<void> _writes = Future.value();
  File? _file;
  String? get path => _file?.path;
  Future<void> init({bool background = false}) async {
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/reports',
    );
    await dir.create(recursive: true);
    final day = DateTime.now().toIso8601String().substring(0, 10);
    _file = File('${dir.path}/$day-${background ? 'background' : 'app'}.log');
    if (await _file!.exists()) {
      _logs.addAll(
        (await _file!.readAsLines()).reversed.take(500).toList().reversed,
      );
    }
    for (final file in dir.listSync().whereType<File>()) {
      if (DateTime.now().difference(await file.lastModified()).inDays > 7)
        await file.delete();
    }
    log(
      'Запуск: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    );
  }

  void log(String message, {bool isError = false}) {
    // Never persist URL query tokens, cookies or authorization headers.
    final safe = message
        .replaceAll(RegExp(r'https?://[^\s]+'), '[URL]')
        .replaceAll(
          RegExp(
            r'(authorization|cookie|token|password)\s*[:=][^\n]+',
            caseSensitive: false,
          ),
          '[REDACTED]',
        );
    final line =
        '[${DateTime.now().toIso8601String()}] ${isError ? 'ERROR' : 'INFO'} $safe';
    _logs.add(line);
    if (_logs.length > 500) _logs.removeRange(0, _logs.length - 500);
    debugPrint(line);
    final file = _file;
    if (file != null)
      _writes = _writes
          .then((_) async {
            if (await file.exists() && await file.length() > 2 * 1024 * 1024)
              await file.writeAsString('Журнал сокращён: лимит 2 МБ\n');
            await file.writeAsString(
              '$line\n',
              mode: FileMode.append,
              flush: true,
            );
          })
          .catchError((Object e) {
            debugPrint('Log write failed: ${e.runtimeType}');
          });
  }

  Future<void> export() async {
    await flush();
    final file = _file;
    if (file == null) return;
    final files = file.parent
        .listSync()
        .whereType<File>()
        .map((f) => XFile(f.path))
        .toList();
    await Share.shareXFiles(files, text: 'Furry Hub — диагностические отчёты');
  }

  Future<void> flush() => _writes;
  List<String> get logs => List.unmodifiable(_logs);
  void clear() {
    _logs.clear();
    log('Журнал экрана очищен');
  }
}
