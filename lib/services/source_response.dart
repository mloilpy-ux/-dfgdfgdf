import 'dart:async';
import 'package:http/http.dart' as http;
import 'logger_service.dart';

class SourceFailure implements Exception {
  const SourceFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

Future<http.Response> fetchSource(
  http.Client client,
  Uri uri, {
  required String service,
  Map<String, String> headers = const {},
  int maxBytes = 4 * 1024 * 1024,
  Duration timeout = const Duration(seconds: 18),
}) async {
  final request = http.Request('GET', uri)
    ..headers.addAll(headers)
    ..followRedirects = !headers.containsKey('Authorization');
  final clock = Stopwatch()..start();
  var stage = 'ожидание HTTP-заголовков';
  LoggerService.instance.log(
    '$service: запрос к ${uri.host}, лимит ${timeout.inSeconds} с',
  );
  late http.Response response;
  try {
    response = await _read(
      client,
      request,
      maxBytes,
      onHeaders: (status) {
        stage = 'чтение тела ответа';
        LoggerService.instance.log(
          '$service: HTTP $status, заголовки за ${clock.elapsedMilliseconds} мс',
        );
      },
    ).timeout(timeout);
  } on TimeoutException {
    LoggerService.instance.log(
      '$service: тайм-аут, этап: $stage, ${clock.elapsedMilliseconds} мс',
      isError: true,
    );
    rethrow;
  } on http.ClientException catch (error) {
    LoggerService.instance.log(
      '$service: сетевая ошибка, этап: $stage, ${clock.elapsedMilliseconds} мс: $error',
      isError: true,
    );
    rethrow;
  }
  LoggerService.instance.log(
    '$service: получено ${response.bodyBytes.length} байт за ${clock.elapsedMilliseconds} мс',
  );
  if (response.statusCode == 200) return response;
  throw SourceFailure(switch (response.statusCode) {
    401 => '$service требует вход',
    402 => '$service требует платный доступ',
    403 => '$service ограничил доступ к источнику',
    404 => '$service: источник не найден или закрыт',
    429 => '$service ограничил частоту запросов. Попробуйте позже',
    _ => '$service: ошибка HTTP ${response.statusCode}',
  });
}

Future<http.Response> _read(
  http.Client client,
  http.Request request,
  int maxBytes, {
  required void Function(int) onHeaders,
}) async {
  final response = await client.send(request);
  onHeaders(response.statusCode);
  final bytes = <int>[];
  await for (final chunk in response.stream) {
    if (bytes.length + chunk.length > maxBytes)
      throw const SourceFailure('Ответ превышает лимит размера');
    bytes.addAll(chunk);
  }
  return http.Response.bytes(
    bytes,
    response.statusCode,
    headers: response.headers,
  );
}

Uri? mediaUri(String? input, [Uri? base]) {
  if (input == null || input.trim().isEmpty) return null;
  final value = input.trim().replaceAll('&amp;', '&');
  final parsed = Uri.tryParse(value);
  if (parsed == null) return null;
  final uri = base?.resolveUri(parsed) ?? parsed;
  if (uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      !{'https', 'http'}.contains(uri.scheme))
    return null;
  return uri;
}
